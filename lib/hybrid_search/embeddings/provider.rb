# frozen_string_literal: true

module HybridSearch
  module Embeddings
    # Base class / interface for embedding providers. Implementations must
    # provide #embed(texts) => Array<Array<Float>> and #identity, a short
    # stable string used to build the staleness digest.
    class Provider
      def embed(texts)
        raise NotImplementedError, "#{self.class} must implement #embed(texts)"
      end

      def identity
        self.class.name
      end
    end

    # Registered adapter classes, resolved from the `provider:` symbol used
    # in a model's `embedding` declaration.
    REGISTRY = {} # rubocop:disable Style/MutableConstant

    class << self
      def register(name, klass)
        REGISTRY[name.to_sym] = klass
      end

      # Resolves the effective provider instance for a given model
      # Definition: a per-index override, an already-instantiated provider
      # object, a registered adapter symbol, or the global default.
      def provider_for(definition)
        configured = definition.embedding_config&.provider

        case configured
        when nil
          HybridSearch.configuration.embedding_provider
        when Symbol
          build_from_symbol(configured, definition)
        else
          configured # caller passed an already-built provider instance
        end
      end

      private

      def build_from_symbol(name, definition)
        klass = REGISTRY[name]
        unless klass
          raise HybridSearch::MissingEmbeddingProviderError, "Unknown embedding provider `#{name.inspect}`. " \
                                                             "Known providers: #{REGISTRY.keys.inspect}"
        end

        klass.new(model: definition.embedding_config.model, dimensions: definition.embedding_config.dimensions)
      end
    end
  end
end
