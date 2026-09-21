# frozen_string_literal: true

HybridSearch.configure do |config|
  # Embedding provider used for semantic search. Uncomment one adapter, or
  # assign any object that responds to #embed(Array<String>) => Array<Array<Float>>.
  #
  # Requires the `ruby_llm` gem and its own provider credentials/config:
  # config.embedding_provider = HybridSearch::Embeddings::RubyLLMProvider.new(
  #   model: "text-embedding-3-small"
  # )
  #
  # Deterministic, local, no-network provider — good for development/tests:
  # config.embedding_provider = HybridSearch::Embeddings::Fake.new(dimensions: 1536)

  # Ranking defaults. Override per-search with keyword_weight:/semantic_weight:/
  # candidate_k:/rrf_k: options on `fusion_search`.
  # config.candidate_k = 50
  # config.rrf_k = 60
  # config.keyword_weight = 1.0
  # config.semantic_weight = 1.0

  # Result limits.
  # config.default_limit = 20
  # config.max_limit = 200
  # config.max_candidate_k = 500

  # What happens when the embedding provider fails or is unavailable:
  # :raise (default) surfaces the error; :keyword_only degrades gracefully
  # and marks results as semantic-degraded in `result.explain`.
  # config.semantic_failure = :raise
end
