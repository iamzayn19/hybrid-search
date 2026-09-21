# frozen_string_literal: true

require "test_helper"

class SearchTest < RailsFusion::TestCase
  def test_exact_keyword_identifier_favors_lexical_result
    a = Product.create!(name: "Error 503 from Stripe", description: "checkout outage", account_id: 1,
                        status: "published")
    Product.create!(name: "Error 404 from Stripe", description: "webhook issue", account_id: 1, status: "published")

    results = Product.fusion_search("Error 503 Stripe", where: { account_id: 1 })

    assert_equal a.id, results.first.record.id
    assert_includes results.first.matched_by, :keyword
  end

  def test_weighted_title_outranks_body_only_match
    title_match = Product.create!(name: "wireless headphones", description: "great for flights", account_id: 1,
                                  status: "published")
    body_match = Product.create!(name: "travel pillow", description: "wireless headphones mentioned here too",
                                 account_id: 1, status: "published")

    results = Product.fusion_search("wireless headphones", where: { account_id: 1 })
    ids = results.records.map(&:id)

    assert_operator ids.index(title_match.id), :<, ids.index(body_match.id)
  end

  def test_null_text_fields_do_not_raise
    Product.create!(name: nil, description: nil, account_id: 1, status: "published")
    assert_silent_search { Product.fusion_search("anything", where: { account_id: 1 }) }
  end

  def test_query_cannot_inject_sql
    Product.create!(name: "safe row", description: "d", account_id: 1, status: "published")
    malicious = "x'; DROP TABLE fusion_products; --"

    assert_silent_search { Product.fusion_search(malicious, where: { account_id: 1 }) }
    assert Product.table_exists?
  end

  def test_semantic_only_result_appears_without_keyword_overlap
    provider = RailsFusion::Embeddings::Fake.new(dimensions: 8)
    vector = provider.embed(["quiet cabin for long haul travel"]).first

    match = Product.create!(name: "Zephyr Comfort Set", description: "totally unrelated words", account_id: 1,
                            status: "published")
    match.update_columns(search_embedding: vector)
    Product.create!(name: "unrelated product", description: "nothing shared", account_id: 1, status: "published")

    results = Product.fusion_search("quiet cabin for long haul travel", where: { account_id: 1 })

    assert_includes results.records.map(&:id), match.id
    result = results.find { |r| r.record.id == match.id }
    assert_includes result.matched_by, :semantic
    refute_includes result.matched_by, :keyword
  end

  def test_nil_embeddings_excluded_from_semantic_candidates
    Product.create!(name: "banana bread", description: "recipe", account_id: 1, status: "published")
    results = Product.fusion_search("banana bread", where: { account_id: 1 })
    assert results.size >= 1
  end

  def test_dimension_mismatch_raises_clean_error
    definition = Product.rails_fusion_definition
    original_provider = definition.embedding_config.provider
    definition.embedding_config.provider = RailsFusion::Embeddings::Fake.new(dimensions: 3)

    Product.create!(name: "x", description: "y", account_id: 1, status: "published")

    error = assert_raises(RailsFusion::EmbeddingDimensionError) do
      Product.fusion_search("x", where: { account_id: 1 })
    end
    assert_match(/dimensions/, error.message)
  ensure
    definition.embedding_config.provider = original_provider
  end

  def test_rrf_fusion_and_weight_overrides
    both = Product.create!(name: "stripe error 503", description: "checkout", account_id: 1, status: "published")
    provider = Product.rails_fusion_definition.embedding_config.provider
    both.update_columns(search_embedding: provider.embed(["stripe error 503"]).first)

    default_results = Product.fusion_search("stripe error 503", where: { account_id: 1 })
    boosted = Product.fusion_search("stripe error 503", where: { account_id: 1 }, keyword_weight: 5.0)

    assert_operator boosted.first.score, :>, default_results.first.score
  end

  def test_deterministic_tie_break
    Product.create!(name: "same", description: "same", account_id: 1, status: "published")
    Product.create!(name: "same", description: "same", account_id: 1, status: "published")

    first_run = Product.fusion_search("same", where: { account_id: 1 }).records.map(&:id)
    second_run = Product.fusion_search("same", where: { account_id: 1 }).records.map(&:id)

    assert_equal first_run, second_run
  end

  def test_tenant_isolation_across_both_channels
    tenant_a = Product.create!(name: "tenant a widget", description: "d", account_id: 1, status: "published")
    tenant_b = Product.create!(name: "tenant a widget", description: "d", account_id: 2, status: "published")
    provider = Product.rails_fusion_definition.embedding_config.provider
    shared_vector = provider.embed(["shared meaning vector"]).first
    tenant_a.update_columns(search_embedding: shared_vector)
    tenant_b.update_columns(search_embedding: shared_vector)

    results = Product.fusion_search("shared meaning vector", where: { account_id: 1 })

    assert_includes results.records.map(&:id), tenant_a.id
    refute_includes results.records.map(&:id), tenant_b.id
  end

  def test_undeclared_filter_raises
    assert_raises(RailsFusion::InvalidFilterError) do
      Product.fusion_search("x", where: { not_a_real_filter: 1 })
    end
  end

  def test_nil_filter_value_is_honored
    Product.create!(name: "no account", description: "d", account_id: nil, status: "published")
    results = Product.fusion_search("no account", where: { account_id: nil })
    assert_equal 1, results.size
  end

  def test_array_filter_values
    Product.create!(name: "cat widget", description: "d", account_id: 1, category_id: 10, status: "published")
    Product.create!(name: "cat widget", description: "d", account_id: 1, category_id: 20, status: "published")

    results = Product.fusion_search("cat widget", where: { account_id: 1, category_id: [10, 20] })
    assert_equal 2, results.size
  end

  def test_blank_query_raises_argument_error
    assert_raises(ArgumentError) { Product.fusion_search("") }
    assert_raises(ArgumentError) { Product.fusion_search("   ") }
    assert_raises(ArgumentError) { Product.fusion_search(nil) }
  end

  def test_no_records_returns_empty_result_set
    results = Product.fusion_search("anything", where: { account_id: 999 })
    assert results.empty?
  end

  def test_configuration_error_when_model_not_configured
    klass = Class.new(ActiveRecord::Base) { self.table_name = "fusion_products" }
    assert_raises(RailsFusion::ConfigurationError) { klass.fusion_search("x") }
  end

  private

  def assert_silent_search
    yield
  end
end
