# frozen_string_literal: true

require "test_helper"

class EmbeddingLifecycleTest < HybridSearch::TestCase
  def test_create_enqueues_embedding_job
    Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    assert_equal 1, enqueued_embed_jobs.size
  end

  def test_unrelated_update_does_not_enqueue
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    product.update!(status: "archived")
    assert_equal 0, enqueued_embed_jobs.size
  end

  def test_relevant_update_enqueues
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    product.update!(name: "new name")
    assert_equal 1, enqueued_embed_jobs.size
  end

  def test_job_persists_embedding_and_digest
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    definition = Product.hybrid_search_definition
    digest = HybridSearch::Embeddings.source_digest(product, definition)

    HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", product.id.to_s, digest)
    product.reload

    refute_nil product.search_embedding
    assert_equal digest, product.search_embedding_digest
  end

  def test_job_does_not_recurse_into_another_enqueue
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    definition = Product.hybrid_search_definition
    digest = HybridSearch::Embeddings.source_digest(product, definition)
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear

    HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", product.id.to_s, digest)

    assert_equal 0, enqueued_embed_jobs.size
  end

  def test_stale_job_cannot_overwrite_newer_embedding
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    definition = Product.hybrid_search_definition
    stale_digest = HybridSearch::Embeddings.source_digest(product, definition)

    # Content changes again before the stale job runs.
    product.update!(name: "changed after enqueue")
    current_digest = HybridSearch::Embeddings.source_digest(product, definition)
    HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", product.id.to_s, current_digest)
    product.reload
    current_vector = product.search_embedding

    HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", product.id.to_s, stale_digest)
    product.reload

    assert_equal current_digest, product.search_embedding_digest
    assert_equal current_vector, product.search_embedding
  end

  def test_duplicate_jobs_are_idempotent
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    definition = Product.hybrid_search_definition
    digest = HybridSearch::Embeddings.source_digest(product, definition)

    2.times { HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", product.id.to_s, digest) }
    product.reload

    assert_equal digest, product.search_embedding_digest
  end

  def test_deleted_record_job_is_harmless
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    id = product.id.to_s
    definition = Product.hybrid_search_definition
    digest = HybridSearch::Embeddings.source_digest(product, definition)
    product.destroy!

    HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", id, digest)
  end

  def test_provider_error_propagates
    failing_provider = Object.new
    def failing_provider.embed(_texts) = raise("boom")
    def failing_provider.identity = "failing"

    HybridSearch.configure { |c| c.embedding_provider = failing_provider }
    product = Product.new(name: "a", description: "b", account_id: 1, status: "published")
    product.save!

    definition = Product.hybrid_search_definition
    original_provider = definition.embedding_config.provider
    definition.embedding_config.provider = nil # force fallback to global config
    digest = HybridSearch::Embeddings.source_digest(product, definition)

    assert_raises(RuntimeError) { HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", product.id.to_s, digest) }
  ensure
    definition.embedding_config.provider = original_provider if defined?(original_provider)
  end

  def test_provider_returning_wrong_dimensions_raises
    definition = Product.hybrid_search_definition
    original_provider = definition.embedding_config.provider
    definition.embedding_config.provider = HybridSearch::Embeddings::Fake.new(dimensions: 3)

    product = Product.new(name: "a", description: "b", account_id: 1, status: "published")
    product.save!
    digest = HybridSearch::Embeddings.source_digest(product, definition)

    assert_raises(HybridSearch::EmbeddingDimensionError) do
      HybridSearch::Jobs::EmbedRecordJob.perform_now("Product", product.id.to_s, digest)
    end
  ensure
    definition.embedding_config.provider = original_provider
  end

  def test_digest_changes_when_model_config_changes
    product = Product.create!(name: "a", description: "b", account_id: 1, status: "published")
    definition = Product.hybrid_search_definition

    digest_1 = HybridSearch::Embeddings.source_digest(product, definition)
    original_provider = definition.embedding_config.provider
    definition.embedding_config.provider = HybridSearch::Embeddings::Fake.new(model: "different-model", dimensions: 8)
    digest_2 = HybridSearch::Embeddings.source_digest(product, definition)

    refute_equal digest_1, digest_2
  ensure
    definition.embedding_config.provider = original_provider
  end

  def test_transaction_rollback_prevents_enqueue
    ActiveRecord::Base.transaction do
      Product.create!(name: "rolled back", description: "d", account_id: 1, status: "published")
      raise ActiveRecord::Rollback
    end

    assert_equal 0, enqueued_embed_jobs.size
    assert_equal 0, Product.where(name: "rolled back").count
  end

  private

  def enqueued_embed_jobs
    ActiveJob::Base.queue_adapter.enqueued_jobs.select { |j| j[:job] == HybridSearch::Jobs::EmbedRecordJob }
  end
end
