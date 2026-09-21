# frozen_string_literal: true

require "digest"

module HybridSearch
  # Deterministic source-text canonicalization and digest computation for the
  # embedding lifecycle. See Definition#embedding for configuration.
  module Embeddings
    module_function

    # Builds a deterministic text payload from a record's configured source
    # fields. Field order is configuration order; nil becomes an empty
    # string; values are stringified with #to_s; a stable separator is used.
    def canonical_source_text(record, definition)
      fields = definition.embedding_config.source
      fields
        .map { |field| record.public_send(field).to_s }
        .join("␞") # SYMBOL FOR RECORD SEPARATOR, an unlikely-to-collide separator
        .scrub("")
        .encode("UTF-8")
    end

    # The digest identifies "what content, embedded by which provider/model/
    # config, produced this vector". Changing any of these makes previously
    # embedded records stale.
    def source_digest(record, definition)
      cfg = definition.embedding_config
      provider = resolve_provider(definition)
      identity = [
        canonical_source_text(record, definition),
        provider&.identity,
        cfg.model,
        cfg.dimensions,
        cfg.distance
      ].join("␟")
      Digest::SHA256.hexdigest(identity)
    end

    def resolve_provider(definition)
      definition.embedding_config&.provider || HybridSearch.configuration.embedding_provider
    end
  end
end
