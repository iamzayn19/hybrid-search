# frozen_string_literal: true

require "active_support/concern"

module HybridSearch
  # Mixed into ActiveRecord::Base (see Engine). Provides the `fusion_search`
  # class-level DSL and search entry point, plus the after_commit embedding
  # lifecycle hook.
  module Model
    extend ActiveSupport::Concern

    class_methods do
      # Two forms:
      #   fusion_search { ... }                 # declare configuration (once, at class body)
      #   fusion_search("query", where: {...})   # perform a search
      def fusion_search(query = nil, **options, &block)
        if block_given?
          define_fusion_search!(&block)
        else
          HybridSearch::Search.new(self, query, **options).call
        end
      end

      def hybrid_search_definition
        return @hybrid_search_definition if defined?(@hybrid_search_definition)

        @hybrid_search_definition = nil
      end

      def fusion_searchable?
        !hybrid_search_definition.nil?
      end

      private

      def define_fusion_search!(&block)
        definition = HybridSearch::Definition.new(self)
        definition.instance_eval(&block)
        definition.validate!
        @hybrid_search_definition = definition

        HybridSearch::Semantic::Neighbor.install!(definition) if definition.embedding_config

        install_hybrid_search_callbacks!(definition)
        definition
      end

      def install_hybrid_search_callbacks!(definition)
        return unless definition.embedding_config&.auto
        return if @hybrid_search_callbacks_installed

        @hybrid_search_callbacks_installed = true
        after_commit :hybrid_search_enqueue_embedding, on: %i[create update]
      end
    end

    # Enqueues an embedding job when configured source fields changed in the
    # just-committed transaction. Never enqueues before commit, and never
    # enqueues when the resulting digest already matches the stored one.
    def hybrid_search_enqueue_embedding
      definition = self.class.hybrid_search_definition
      cfg = definition&.embedding_config
      return unless cfg&.auto

      changed_source = cfg.source.any? { |field| saved_change_to_attribute?(field) }
      return unless changed_source

      digest = HybridSearch::Embeddings.source_digest(self, definition)
      return if read_attribute(cfg.digest_column) == digest

      HybridSearch::Jobs::EmbedRecordJob.perform_later(self.class.name, id.to_s, digest)
    end
  end
end
