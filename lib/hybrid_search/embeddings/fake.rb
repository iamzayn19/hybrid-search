# frozen_string_literal: true

require "digest"

module HybridSearch
  module Embeddings
    # Deterministic embedding provider used by tests, examples, and local
    # development. It performs no network calls and produces a stable
    # pseudo-random unit vector for any given text, so semantically similar
    # fixtures can be crafted deliberately in tests by controlling input text.
    #
    # This is NOT a real embedding model. Do not use it in production.
    class Fake < Provider
      attr_reader :model, :dimensions

      def initialize(model: "fake-deterministic", dimensions: 16)
        super()
        @model = model
        @dimensions = dimensions
      end

      def embed(texts)
        texts.map { |text| vector_for(text) }
      end

      def identity
        "fake:#{model}:#{dimensions}"
      end

      private

      def vector_for(text)
        seed = Digest::SHA256.digest(text.to_s)
        raw = Array.new(dimensions) do |i|
          byte = seed.getbyte(i % seed.bytesize)
          ((byte / 255.0) * 2) - 1
        end
        normalize(raw)
      end

      def normalize(vector)
        magnitude = Math.sqrt(vector.sum { |v| v * v })
        return vector.map { 0.0 } if magnitude.zero?

        vector.map { |v| v / magnitude }
      end
    end
  end
end

HybridSearch::Embeddings.register(:fake, HybridSearch::Embeddings::Fake)
