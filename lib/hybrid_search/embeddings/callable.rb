# frozen_string_literal: true

module HybridSearch
  module Embeddings
    # Wraps any object responding to #call(Array<String>) => Array<Array<Float>>
    # (a lambda, proc, or custom adapter) as a HybridSearch embedding provider.
    #
    #   HybridSearch.configure do |config|
    #     config.embedding_provider = HybridSearch::Embeddings::Callable.new(
    #       identity: "acme-embedder-v1"
    #     ) { |texts| AcmeClient.embed(texts) }
    #   end
    class Callable < Provider
      def initialize(identity: "callable", **, &block)
        super()
        @callable_identity = identity
        @block = block
      end

      def embed(texts)
        @block.call(texts)
      end

      def identity
        @callable_identity
      end
    end

    register(:callable, Callable)
  end
end
