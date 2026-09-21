# frozen_string_literal: true

module RailsFusion
  # Batched, resumable, idempotent embedding backfill. Never loads the whole
  # table into memory; never aborts the whole run because one record fails to
  # embed unless `fail_fast: true` is requested.
  class Backfill
    Summary = Struct.new(:processed, :embedded, :skipped, :failed, :errors, keyword_init: true)

    def initialize(model, batch_size: 500, mode: :sync, force: false, fail_fast: false, progress: nil)
      @model = model
      @batch_size = batch_size
      @mode = mode
      @force = force
      @fail_fast = fail_fast
      @progress = progress
    end

    def call
      definition = @model.rails_fusion_definition
      cfg = definition&.embedding_config
      raise ConfigurationError, "#{@model} has no `embedding` configured for backfill." unless cfg

      summary = Summary.new(processed: 0, embedded: 0, skipped: 0, failed: 0, errors: [])

      Instrumentation.instrument("backfill", model: @model.name, mode: @mode) do |payload|
        @model.find_each(batch_size: @batch_size) do |record|
          process_record(record, definition, cfg, summary)
          @progress&.call(summary)
        end

        payload[:processed] = summary.processed
        payload[:embedded] = summary.embedded
        payload[:skipped] = summary.skipped
        payload[:failed] = summary.failed
      end

      summary
    end

    private

    def process_record(record, definition, cfg, summary)
      summary.processed += 1
      digest = Embeddings.source_digest(record, definition)

      if !@force && record.read_attribute(cfg.digest_column) == digest
        summary.skipped += 1
        return
      end

      run_job(record, digest, summary)
    end

    def run_job(record, digest, summary)
      if @mode == :async
        Jobs::EmbedRecordJob.perform_later(@model.name, record.id.to_s, digest)
      else
        Jobs::EmbedRecordJob.perform_now(@model.name, record.id.to_s, digest)
      end
      summary.embedded += 1
    rescue StandardError => e
      summary.failed += 1
      summary.errors << "id=#{record.id} #{e.class}: #{e.message}"
      raise if @fail_fast
    end
  end
end
