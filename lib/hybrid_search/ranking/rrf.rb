# frozen_string_literal: true

module HybridSearch
  module Ranking
    # Reciprocal Rank Fusion: combines independent keyword and semantic
    # rankings into one comparable score without treating raw ts_rank and
    # cosine distance as though they share a scale.
    #
    #   score = keyword_weight / (rrf_k + keyword_rank) + semantic_weight / (rrf_k + semantic_rank)
    #
    # A candidate missing from a channel contributes zero for that channel,
    # but remains eligible if it appears in the other channel.
    module RRF
      Contribution = Struct.new(
        :score, :keyword_rank, :semantic_rank, :keyword_contribution, :semantic_contribution,
        keyword_init: true
      )

      module_function

      def fuse(keyword_ranks:, semantic_ranks:, keyword_weight:, semantic_weight:, rrf_k:)
        ids = keyword_ranks.keys | semantic_ranks.keys

        ids.each_with_object({}) do |id, acc|
          keyword_rank = keyword_ranks[id]
          semantic_rank = semantic_ranks[id]

          keyword_contribution = keyword_rank ? keyword_weight / (rrf_k + keyword_rank).to_f : 0.0
          semantic_contribution = semantic_rank ? semantic_weight / (rrf_k + semantic_rank).to_f : 0.0

          acc[id] = Contribution.new(
            score: keyword_contribution + semantic_contribution,
            keyword_rank: keyword_rank,
            semantic_rank: semantic_rank,
            keyword_contribution: keyword_contribution,
            semantic_contribution: semantic_contribution
          )
        end
      end
    end
  end
end
