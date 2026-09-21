# frozen_string_literal: true

module RailsFusion
  # Diagnoses common configuration problems: database adapter, pgvector
  # availability, per-model column/index/provider setup, and embedding
  # staleness. Used by `rails_fusion:doctor`.
  class Doctor
    Check = Struct.new(:name, :status, :message, keyword_init: true)

    def initialize(model = nil)
      @model = model
    end

    def call
      checks = [check_adapter]
      checks << check_pgvector if postgres?
      checks.concat(model_checks) if @model
      checks
    end

    def ok?(checks)
      checks.none? { |c| c.status == :error }
    end

    private

    def postgres?
      ActiveRecord::Base.connection.adapter_name =~ /postg/i
    end

    def check_adapter
      if postgres?
        Check.new(name: "database_adapter", status: :ok,
                  message: "PostgreSQL adapter detected (#{ActiveRecord::Base.connection.adapter_name}).")
      else
        Check.new(name: "database_adapter", status: :error,
                  message: "RailsFusion requires PostgreSQL. Detected: #{ActiveRecord::Base.connection.adapter_name}.")
      end
    end

    def check_pgvector
      row = ActiveRecord::Base.connection.select_one(
        "SELECT extversion FROM pg_extension WHERE extname = 'vector'"
      )
      if row
        Check.new(name: "pgvector_extension", status: :ok, message: "pgvector #{row["extversion"]} installed.")
      else
        Check.new(name: "pgvector_extension", status: :warning,
                  message: "pgvector extension not installed. Semantic search is unavailable until " \
                           "`CREATE EXTENSION vector;` is run (see the rails_fusion:index generator).")
      end
    end

    def model_checks
      definition = @model.rails_fusion_definition
      unless definition
        return [Check.new(name: "model_configuration", status: :error,
                          message: "#{@model} has no `fusion_search do ... end` block.")]
      end

      [
        check_columns(definition),
        check_provider(definition),
        check_embedding_status(definition)
      ].flatten
    end

    def check_columns(definition)
      missing = (definition.text_fields.map(&:name) + Array(definition.embedding_config&.column) +
        definition.filters).reject { |c| @model.columns_hash.key?(c.to_s) }
      if missing.empty?
        Check.new(name: "model_columns", status: :ok, message: "All configured columns exist.")
      else
        Check.new(name: "model_columns", status: :error, message: "Missing columns: #{missing.join(", ")}.")
      end
    end

    def check_provider(definition)
      unless definition.embedding_config
        return Check.new(name: "embedding_provider", status: :ok,
                         message: "No embedding configured (keyword-only).")
      end

      provider = Embeddings.resolve_provider(definition)
      if provider
        Check.new(name: "embedding_provider", status: :ok, message: "Provider: #{provider.identity}.")
      else
        Check.new(name: "embedding_provider", status: :error,
                  message: "No embedding provider configured for #{@model}.")
      end
    end

    def check_embedding_status(definition)
      cfg = definition.embedding_config
      return [] unless cfg

      total = @model.count
      missing = @model.where(cfg.column => nil).count
      Check.new(
        name: "embedding_status", status: missing.positive? ? :warning : :ok,
        message: "#{total - missing}/#{total} records embedded, #{missing} missing."
      )
    end
  end
end
