# frozen_string_literal: true

module HybridSearch
  # Global, application-wide configuration. Set once in an initializer.
  #
  #   HybridSearch.configure do |config|
  #     config.embedding_provider = HybridSearch::Embeddings::RubyLLM.new(model: "text-embedding-3-small")
  #     config.candidate_k = 50
  #     config.rrf_k = 60
  #   end
  class Configuration
    attr_accessor :embedding_provider, :candidate_k, :rrf_k, :keyword_weight,
                  :semantic_weight, :default_limit, :max_limit, :max_candidate_k,
                  :semantic_failure

    def initialize
      @embedding_provider = nil
      @candidate_k = 50
      @rrf_k = 60
      @keyword_weight = 1.0
      @semantic_weight = 1.0
      @default_limit = 20
      @max_limit = 200
      @max_candidate_k = 500
      @semantic_failure = :raise
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
