# frozen_string_literal: true

require "active_job"

module HybridSearch
  module Jobs
    # Generates and persists a record's embedding. Race-safe: the job carries
    # the digest expected at enqueue time and re-checks it both before and
    # after generating the vector, so an out-of-order or duplicate job can
    # never overwrite a newer embedding with stale output. Uses
    # `update_columns` to persist, which skips callbacks entirely and cannot
    # recurse into the enqueue hook.
    class EmbedRecordJob < ActiveJob::Base
      queue_as :default

      def perform(model_name, id, expected_digest)
        model = resolve_model(model_name)
        return unless model

        record = model.find_by(model.primary_key => id)
        return unless record # deleted before the job ran: harmless no-op

        definition = model.hybrid_search_definition
        cfg = definition&.embedding_config
        return unless cfg

        return unless digest_still_matches?(record, definition, expected_digest)

        Instrumentation.instrument("embedding", model: model.name, id: id.to_s) do |payload|
          vector = generate_vector(record, definition)
          payload[:dimensions] = vector&.size

          persist_if_still_current(record, definition, cfg, expected_digest, vector)
        end
      end

      private

      def resolve_model(model_name)
        klass = model_name.to_s.safe_constantize
        return nil unless klass.is_a?(Class) && klass < ActiveRecord::Base
        return nil unless klass.respond_to?(:fusion_searchable?) && klass.fusion_searchable?

        klass
      end

      def digest_still_matches?(record, definition, expected_digest)
        HybridSearch::Embeddings.source_digest(record, definition) == expected_digest
      end

      def generate_vector(record, definition)
        provider = HybridSearch::Embeddings.resolve_provider(definition)
        unless provider
          raise MissingEmbeddingProviderError,
                "No embedding provider configured for #{definition.model_class}."
        end

        text = HybridSearch::Embeddings.canonical_source_text(record, definition)
        vector = provider.embed([text]).first

        cfg = definition.embedding_config
        if vector.nil? || vector.size != cfg.dimensions
          raise EmbeddingDimensionError,
                "Provider returned #{vector&.size.inspect} dimensions, expected #{cfg.dimensions} " \
                "for #{definition.model_class}##{cfg.column}."
        end

        vector
      end

      # Re-check immediately before writing: another job may have already
      # persisted a newer embedding for content that changed again while this
      # job was generating its vector.
      def persist_if_still_current(record, definition, cfg, expected_digest, vector)
        record.reload
        return unless digest_still_matches?(record, definition, expected_digest)

        record.update_columns(cfg.column => vector, cfg.digest_column => expected_digest)
      end
    end
  end
end
