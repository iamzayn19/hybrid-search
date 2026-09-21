# frozen_string_literal: true

module HybridSearch
  # Base class for all errors raised by HybridSearch.
  class Error < StandardError; end

  # Raised when a model's `fusion_search` block is misconfigured.
  class ConfigurationError < Error; end

  # Raised when the connected database is not PostgreSQL.
  class UnsupportedDatabaseError < Error; end

  # Raised when the `vector` extension is not installed/available.
  class MissingVectorExtensionError < Error; end

  # Raised when semantic search is attempted without a configured embedding provider.
  class MissingEmbeddingProviderError < Error; end

  # Raised when a caller passes a `where:` key that was not declared with `filter`.
  class InvalidFilterError < Error; end

  # Raised when an embedding provider returns a vector of the wrong size.
  class EmbeddingDimensionError < Error; end

  # Raised for generic query-execution failures inside HybridSearch.
  class SearchError < Error; end
end
