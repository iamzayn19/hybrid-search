# frozen_string_literal: true

begin
  require "ruby_llm"
rescue LoadError
  # ruby_llm is an optional dependency; this adapter is only registered when
  # it is available in the host application's bundle.
end

if defined?(RubyLLM)
  module HybridSearch
    module Embeddings
      # Embedding provider backed by the `ruby_llm` gem. Only loaded/registered
      # when `ruby_llm` is present in the host application's Gemfile.
      class RubyLLMProvider < Provider
        attr_reader :model, :dimensions

        def initialize(model:, dimensions: nil, **)
          super()
          @model = model
          @dimensions = dimensions
        end

        def embed(texts)
          texts.map do |text|
            response = ::RubyLLM.embed(text, model: model)
            vector = response.respond_to?(:vectors) ? response.vectors.first : response.vector
            vector
          end
        end

        def identity
          "ruby_llm:#{model}"
        end
      end

      register(:ruby_llm, RubyLLMProvider)
    end
  end
end
