# frozen_string_literal: true

module RailsFusion
  module Keyword
    # PostgreSQL full-text-search candidate retrieval. Builds a weighted
    # tsvector expression from the model's declared `text` fields and ranks
    # matches with ts_rank_cd against a websearch_to_tsquery. All user query
    # text is bind-parameterized; column names are only ever ones already
    # validated against the model's schema in Definition#validate!.
    class Postgres
      CandidateSet = Struct.new(:ranks, :raw_scores, keyword_init: true)

      def initialize(definition)
        @definition = definition
      end

      # Returns a CandidateSet: `ranks` maps stringified primary key => 1-based
      # rank (1 = best match); `raw_scores` maps the same keys to the raw
      # ts_rank_cd value (useful for explain output).
      def candidates(scope:, query:, candidate_k:)
        return CandidateSet.new(ranks: {}, raw_scores: {}) if @definition.text_fields.empty?
        return CandidateSet.new(ranks: {}, raw_scores: {}) if query.nil? || query.strip.empty?

        model = @definition.model_class
        connection = model.connection
        tsvector = tsvector_sql(connection)
        pk = connection.quote_column_name(model.primary_key)

        rank_expr = model.sanitize_sql_array(
          ["ts_rank_cd(#{tsvector}, websearch_to_tsquery(?, ?))", text_search_config, query]
        )
        where_expr = model.sanitize_sql_array(
          ["#{tsvector} @@ websearch_to_tsquery(?, ?)", text_search_config, query]
        )

        rows = scope
               .where(where_expr)
               .select(Arel.sql("#{model.quoted_table_name}.#{pk} AS rf_id, (#{rank_expr}) AS rf_rank"))
               .order(Arel.sql("rf_rank DESC, #{model.quoted_table_name}.#{pk} ASC"))
               .limit(candidate_k)

        ranks = {}
        raw_scores = {}
        rows.each_with_index do |row, index|
          id = row.attributes["rf_id"].to_s
          ranks[id] = index + 1
          raw_scores[id] = row.attributes["rf_rank"]
        end

        CandidateSet.new(ranks: ranks, raw_scores: raw_scores)
      end

      # SQL fragment usable in migrations/generators for a GIN index.
      def self.tsvector_index_expression(definition, connection)
        new(definition).send(:tsvector_sql, connection)
      end

      private

      def text_search_config
        @definition.text_search_config
      end

      def tsvector_sql(connection)
        quoted_config = connection.quote(text_search_config)
        table = @definition.model_class.quoted_table_name

        @definition.text_fields.map do |field|
          column = connection.quote_column_name(field.name)
          weight = field.weight.to_s.upcase
          "setweight(to_tsvector(#{quoted_config}, coalesce(#{table}.#{column}, '')), '#{weight}')"
        end.join(" || ")
      end
    end
  end
end
