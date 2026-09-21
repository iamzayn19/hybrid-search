# frozen_string_literal: true

module RailsFusion
  # A single hybrid search result: the record, its fused score, and a
  # machine-readable explanation of how that score was produced.
  class Result
    attr_reader :record, :score, :keyword_rank, :semantic_rank, :keyword_score,
                :semantic_score, :recency_score, :matched_by, :explain

    def initialize(record:, score:, keyword_rank:, semantic_rank:, keyword_score:,
                   semantic_score:, recency_score:, matched_by:, explain:)
      @record = record
      @score = score
      @keyword_rank = keyword_rank
      @semantic_rank = semantic_rank
      @keyword_score = keyword_score
      @semantic_score = semantic_score
      @recency_score = recency_score
      @matched_by = matched_by
      @explain = explain
    end

    def as_json(*)
      {
        model: record.class.name,
        id: record.id,
        score: score,
        keyword_rank: keyword_rank,
        semantic_rank: semantic_rank,
        matched_by: matched_by
      }
    end
  end
end
