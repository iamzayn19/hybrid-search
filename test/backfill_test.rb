# frozen_string_literal: true

require "test_helper"

class BackfillTest < HybridSearch::TestCase
  def test_backfill_embeds_missing_records
    3.times { |i| Product.create!(name: "item #{i}", description: "d", account_id: 1, status: "published") }
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    summary = HybridSearch::Backfill.new(Product, mode: :sync).call

    assert_equal 3, summary.processed
    assert_equal 3, summary.embedded
    assert Product.where(search_embedding: nil).none?
  end

  def test_backfill_skips_current_records_unless_forced
    Product.create!(name: "item", description: "d", account_id: 1, status: "published")
    HybridSearch::Backfill.new(Product, mode: :sync).call

    summary = HybridSearch::Backfill.new(Product, mode: :sync).call
    assert_equal 1, summary.skipped
    assert_equal 0, summary.embedded
  end

  def test_backfill_force_redoes_current_records
    Product.create!(name: "item", description: "d", account_id: 1, status: "published")
    HybridSearch::Backfill.new(Product, mode: :sync).call

    summary = HybridSearch::Backfill.new(Product, mode: :sync, force: true).call
    assert_equal 1, summary.embedded
  end

  def test_backfill_failure_does_not_abort_whole_run_unless_fail_fast
    Product.create!(name: "ok", description: "d", account_id: 1, status: "published")
    broken = Product.create!(name: "broken", description: "d", account_id: 1, status: "published")

    definition = Product.hybrid_search_definition
    original_provider = definition.embedding_config.provider
    failing = Object.new
    call_count = 0
    failing.define_singleton_method(:embed) do |texts|
      call_count += 1
      raise "provider down" if texts.first.include?("broken")

      original_provider.embed(texts)
    end
    failing.define_singleton_method(:identity) { "flaky" }
    definition.embedding_config.provider = failing

    summary = HybridSearch::Backfill.new(Product, mode: :sync).call

    assert_equal 1, summary.failed
    assert_equal 1, summary.embedded
    refute broken.reload.search_embedding
  ensure
    definition.embedding_config.provider = original_provider
  end

  def test_backfill_async_mode_enqueues_jobs
    Product.create!(name: "item", description: "d", account_id: 1, status: "published")
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    HybridSearch::Backfill.new(Product, mode: :async).call

    assert_equal 1, ActiveJob::Base.queue_adapter.enqueued_jobs.size
  end
end
