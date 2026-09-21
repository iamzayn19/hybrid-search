# frozen_string_literal: true

require "neighbor"

module HybridSearch
  module Semantic
    # pgvector-backed nearest-neighbor candidate retrieval, built on the
    # `neighbor` gem. Converts vector distance ordering into a `semantic_rank`
    # (1 = closest); RRF fuses on rank, not raw distance. Records with a nil
    # embedding are always excluded from semantic candidates.
    class Neighbor
      CandidateSet = Struct.new(:ranks, :raw_distances, keyword_init: true)

      DISTANCE_MAP = { cosine: "cosine", l2: "euclidean", inner_product: "inner_product" }.freeze

      def self.install!(definition)
        cfg = definition.embedding_config
        return unless cfg

        model = definition.model_class
        model.has_neighbors cfg.column, dimensions: cfg.dimensions
      end

      def initialize(definition)
        @definition = definition
      end

      def candidates(scope:, query_vector:, candidate_k:)
        return CandidateSet.new(ranks: {}, raw_distances: {}) if query_vector.nil?

        cfg = @definition.embedding_config
        if query_vector.size != cfg.dimensions
          raise HybridSearch::EmbeddingDimensionError,
                "Query embedding has #{query_vector.size} dimensions, expected #{cfg.dimensions} " \
                "for #{@definition.model_class}##{cfg.column}."
        end

        model = @definition.model_class
        distance = DISTANCE_MAP.fetch(cfg.distance)

        relation = scope
                   .where.not(cfg.column => nil)
                   .nearest_neighbors(cfg.column, query_vector, distance: distance)
                   .limit(candidate_k)

        pk = model.primary_key
        ranks = {}
        raw_distances = {}
        relation.each_with_index do |record, index|
          id = record.public_send(pk).to_s
          ranks[id] = index + 1
          raw_distances[id] = record.respond_to?(:neighbor_distance) ? record.neighbor_distance : nil
        end

        CandidateSet.new(ranks: ranks, raw_distances: raw_distances)
      end
    end
  end
end
