# frozen_string_literal: true

module HybridSearch
  # A single result from HybridSearch.search across multiple models.
  GlobalResult = Struct.new(:record, :model, :score, :model_rank, :explain, keyword_init: true) do
    def as_json(*)
      { model: model.name, id: record.id, score: score, model_rank: model_rank }
    end
  end

  # Multi-model / global search. Each model performs its own independent
  # hybrid candidate ranking (never comparing raw vector similarity across
  # models, which may use different providers/dimensions), then a second
  # rank-fusion layer combines the per-model result lists.
  class GlobalSearch
    MAX_MODELS = 20

    def initialize(query, models:, where: {}, limit: nil, fail_fast: false, clock: nil, **per_model_options)
      @query = query
      @models = models
      @where = where
      @limit = limit || HybridSearch.configuration.default_limit
      @fail_fast = fail_fast
      @clock = clock
      @per_model_options = per_model_options
    end

    def call
      raise ArgumentError, "models must not be empty" if @models.empty?
      raise ArgumentError, "too many models requested (max #{MAX_MODELS})" if @models.size > MAX_MODELS

      per_model = {}
      errors = {}

      @models.each do |model|
        per_model[model] = model.fusion_search(
          @query, where: @where[model] || {}, limit: @limit, clock: @clock, **@per_model_options
        )
      rescue StandardError => e
        raise if @fail_fast

        errors[model] = e
        Instrumentation.instrument("global_search_model_failure", model: model.name, error_class: e.class.name)
      end

      results = fuse(per_model)
      GlobalResultSet.new(results.first(@limit), errors: errors)
    end

    private

    def fuse(per_model)
      rrf_k = HybridSearch.configuration.rrf_k

      per_model.flat_map do |model, result_set|
        result_set.each_with_index.map do |result, index|
          model_rank = index + 1
          GlobalResult.new(
            record: result.record,
            model: model,
            score: result.score + (1.0 / (rrf_k + model_rank)),
            model_rank: model_rank,
            explain: result.explain
          )
        end
      end.sort_by { |r| [-r.score, r.model.name, r.record.id.to_s] }
    end
  end

  # Result collection returned by HybridSearch.search.
  class GlobalResultSet
    include Enumerable

    attr_reader :results, :errors

    def initialize(results, errors: {})
      @results = results
      @errors = errors
    end

    def each(&)
      return enum_for(:each) unless block_given?

      results.each(&)
    end

    def records
      results.map(&:record)
    end

    def empty?
      results.empty?
    end

    def degraded?
      errors.any?
    end

    def as_json(*)
      results.map(&:as_json)
    end
  end
end
