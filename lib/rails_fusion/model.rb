# frozen_string_literal: true

require "active_support/concern"

module RailsFusion
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
          RailsFusion::Search.new(self, query, **options).call
        end
      end

      def rails_fusion_definition
        return @rails_fusion_definition if defined?(@rails_fusion_definition)

        @rails_fusion_definition = nil
      end

      def fusion_searchable?
        !rails_fusion_definition.nil?
      end

      private

      def define_fusion_search!(&block)
        definition = RailsFusion::Definition.new(self)
        definition.instance_eval(&block)
        definition.validate!
        @rails_fusion_definition = definition

        RailsFusion::Semantic::Neighbor.install!(definition) if definition.embedding_config

        install_rails_fusion_callbacks!(definition)
        definition
      end

      def install_rails_fusion_callbacks!(definition)
        return unless definition.embedding_config&.auto
        return if @rails_fusion_callbacks_installed

        @rails_fusion_callbacks_installed = true
        after_commit :rails_fusion_enqueue_embedding, on: %i[create update]
      end
    end

    # Enqueues an embedding job when configured source fields changed in the
    # just-committed transaction. Never enqueues before commit, and never
    # enqueues when the resulting digest already matches the stored one.
    def rails_fusion_enqueue_embedding
      definition = self.class.rails_fusion_definition
      cfg = definition&.embedding_config
      return unless cfg&.auto

      changed_source = cfg.source.any? { |field| saved_change_to_attribute?(field) }
      return unless changed_source

      digest = RailsFusion::Embeddings.source_digest(self, definition)
      return if read_attribute(cfg.digest_column) == digest

      RailsFusion::Jobs::EmbedRecordJob.perform_later(self.class.name, id.to_s, digest)
    end
  end
end
