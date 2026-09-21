# frozen_string_literal: true

module HybridSearch
  # Orchestrates one hybrid search call for a single configured model:
  # validates input, retrieves keyword and semantic candidates over the same
  # filtered scope, fuses them with RRF, applies optional recency, and
  # returns a deterministically ordered ResultSet.
  class Search
    def initialize(model_class, query, where: {}, limit: nil, keyword_weight: nil,
                   semantic_weight: nil, candidate_k: nil, rrf_k: nil, scope: nil, clock: nil)
      @model_class = model_class
      @query = query
      @where = where
      @limit = limit
      @keyword_weight = keyword_weight
      @semantic_weight = semantic_weight
      @candidate_k = candidate_k
      @rrf_k = rrf_k
      @scope = scope
      @clock = clock || Time.now
    end

    def call
      definition = fetch_definition!
      validate_query!
      options = resolve_options
      base_scope = build_scope(definition)

      fallback = nil

      Instrumentation.instrument("search", model: @model_class.name) do |payload|
        keyword_set = Keyword::Postgres.new(definition).candidates(
          scope: base_scope, query: @query, candidate_k: options[:candidate_k]
        )

        semantic_set = Semantic::Neighbor::CandidateSet.new(ranks: {}, raw_distances: {})
        if definition.embedding_config
          semantic_set, fallback = fetch_semantic_candidates(definition, base_scope, options)
        end

        fused = Ranking::RRF.fuse(
          keyword_ranks: keyword_set.ranks,
          semantic_ranks: semantic_set.ranks,
          keyword_weight: options[:keyword_weight],
          semantic_weight: options[:semantic_weight],
          rrf_k: options[:rrf_k]
        )

        records_by_id = load_records(base_scope, fused.keys)

        results = build_results(
          fused.keys, records_by_id, fused, keyword_set, semantic_set, definition, options, fallback
        ).first(options[:limit])

        payload[:candidate_keyword_count] = keyword_set.ranks.size
        payload[:candidate_semantic_count] = semantic_set.ranks.size
        payload[:result_count] = results.size
        payload[:fallback] = fallback

        ResultSet.new(results, fallback: fallback)
      end
    end

    private

    def fetch_definition!
      definition = @model_class.hybrid_search_definition
      unless definition
        raise ConfigurationError,
              "#{@model_class} has no `fusion_search do ... end` block. Configure it before searching."
      end
      definition
    end

    def validate_query!
      raise ArgumentError, "query must not be blank" if @query.nil? || @query.to_s.strip.empty?
    end

    def resolve_options
      config = HybridSearch.configuration
      limit = @limit || config.default_limit
      candidate_k = @candidate_k || config.candidate_k

      raise ArgumentError, "limit must be a positive integer" unless limit.is_a?(Integer) && limit.positive?
      raise ArgumentError, "limit exceeds configured maximum (#{config.max_limit})" if limit > config.max_limit
      unless candidate_k.is_a?(Integer) && candidate_k.positive?
        raise ArgumentError, "candidate_k must be a positive integer"
      end
      if candidate_k > config.max_candidate_k
        raise ArgumentError, "candidate_k exceeds configured maximum (#{config.max_candidate_k})"
      end

      rrf_k = @rrf_k || config.rrf_k
      raise ArgumentError, "rrf_k must be positive" unless rrf_k.to_f.positive?

      keyword_weight = @keyword_weight || config.keyword_weight
      semantic_weight = @semantic_weight || config.semantic_weight
      raise ArgumentError, "keyword_weight must be >= 0" if keyword_weight.to_f.negative?
      raise ArgumentError, "semantic_weight must be >= 0" if semantic_weight.to_f.negative?

      {
        limit: limit, candidate_k: candidate_k, rrf_k: rrf_k.to_f,
        keyword_weight: keyword_weight.to_f, semantic_weight: semantic_weight.to_f
      }
    end

    def build_scope(definition)
      relation = @scope || @model_class.all
      @where.each do |key, value|
        unless definition.filter?(key)
          raise InvalidFilterError,
                "`#{key}` is not a declared filter on #{@model_class}. Declare it with `filter :#{key}`."
        end

        relation = relation.where(key => value)
      end
      relation
    end

    def fetch_semantic_candidates(definition, base_scope, options)
      provider = Embeddings.resolve_provider(definition)
      if provider.nil?
        message = "No embedding provider configured for #{@model_class}. " \
                  "Set `HybridSearch.configure { |c| c.embedding_provider = ... }`."
        return semantic_degraded(definition, :provider_missing, MissingEmbeddingProviderError.new(message))
      end

      begin
        vector = provider.embed([@query]).first
        set = Semantic::Neighbor.new(definition).candidates(
          scope: base_scope, query_vector: vector, candidate_k: options[:candidate_k]
        )
        [set, nil]
      rescue EmbeddingDimensionError
        raise
      rescue StandardError => e
        semantic_degraded(definition, :provider_error, e)
      end
    end

    def semantic_degraded(_definition, reason, error)
      failure_mode = HybridSearch.configuration.semantic_failure

      Instrumentation.instrument("semantic_search_failure", model: @model_class.name, reason: reason,
                                                            error_class: error.class.name)

      raise error if failure_mode == :raise

      empty = Semantic::Neighbor::CandidateSet.new(ranks: {}, raw_distances: {})
      [empty, reason]
    end

    def sortable_id(id)
      pk_type = @model_class.columns_hash[@model_class.primary_key]&.type
      return id.to_i if %i[integer bigint].include?(pk_type)

      id
    end

    def load_records(base_scope, ids)
      return {} if ids.empty?

      base_scope.where(@model_class.primary_key => ids).index_by do |record|
        record.public_send(@model_class.primary_key).to_s
      end
    end

    def build_results(ids, records_by_id, fused, keyword_set, semantic_set, definition, options, fallback)
      ids.filter_map do |id|
        record = records_by_id[id]
        next unless record

        contribution = fused[id]
        recency_score = recency_score_for(record, definition, options)
        final_score = contribution.score + recency_score

        matched_by = []
        matched_by << :keyword if contribution.keyword_rank
        matched_by << :semantic if contribution.semantic_rank

        Result.new(
          record: record,
          score: final_score,
          keyword_rank: contribution.keyword_rank,
          semantic_rank: contribution.semantic_rank,
          keyword_score: keyword_set.raw_scores[id],
          semantic_score: semantic_set.raw_distances[id],
          recency_score: recency_score,
          matched_by: matched_by,
          explain: explain_for(contribution, keyword_set, semantic_set, id, recency_score, final_score, fallback)
        )
      end.sort_by { |r| [-r.score, sortable_id(r.record.public_send(@model_class.primary_key).to_s)] }
    end

    def recency_score_for(record, definition, options)
      return 0.0 unless definition.recency_config

      timestamp = record.public_send(definition.recency_config.column)
      Ranking::Recency.contribution(
        timestamp, half_life: definition.recency_config.half_life, rrf_k: options[:rrf_k], clock: @clock
      )
    end

    def explain_for(contribution, keyword_set, semantic_set, id, recency_score, final_score, fallback)
      {
        final_score: final_score,
        keyword: {
          matched: !contribution.keyword_rank.nil?,
          rank: contribution.keyword_rank,
          raw_score: keyword_set.raw_scores[id],
          rrf_contribution: contribution.keyword_contribution
        },
        semantic: {
          matched: !contribution.semantic_rank.nil?,
          rank: contribution.semantic_rank,
          distance: semantic_set.raw_distances[id],
          rrf_contribution: contribution.semantic_contribution,
          degraded: fallback
        },
        recency: {
          applied: recency_score.positive?,
          contribution: recency_score
        }
      }
    end
  end
end
