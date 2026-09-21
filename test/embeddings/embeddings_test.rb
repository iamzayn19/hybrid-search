# frozen_string_literal: true

require "test_helper"

class EmbeddingsTest < RailsFusion::TestCase
  def test_canonical_source_text_is_deterministic_and_order_stable
    product = Product.new(name: "Alpha", description: "Beta")
    definition = Product.rails_fusion_definition

    text_1 = RailsFusion::Embeddings.canonical_source_text(product, definition)
    text_2 = RailsFusion::Embeddings.canonical_source_text(product, definition)

    assert_equal text_1, text_2
    assert_match(/Alpha/, text_1)
    assert_match(/Beta/, text_1)
  end

  def test_nil_fields_become_empty_string
    product = Product.new(name: nil, description: "only")
    definition = Product.rails_fusion_definition
    text = RailsFusion::Embeddings.canonical_source_text(product, definition)
    refute_nil text
  end

  def test_digest_changes_when_source_text_changes
    definition = Product.rails_fusion_definition
    a = Product.new(name: "one", description: "d")
    b = Product.new(name: "two", description: "d")

    refute_equal RailsFusion::Embeddings.source_digest(a, definition),
                 RailsFusion::Embeddings.source_digest(b, definition)
  end

  def test_fake_provider_is_deterministic
    provider = RailsFusion::Embeddings::Fake.new(dimensions: 8)
    assert_equal provider.embed(["same text"]), provider.embed(["same text"])
  end

  def test_fake_provider_normalizes_to_unit_vectors
    provider = RailsFusion::Embeddings::Fake.new(dimensions: 8)
    vector = provider.embed(["hello"]).first
    magnitude = Math.sqrt(vector.sum { |v| v * v })
    assert_in_delta 1.0, magnitude, 1e-6
  end

  def test_callable_provider_wraps_a_block
    provider = RailsFusion::Embeddings::Callable.new(identity: "custom") { |texts| texts.map { |t| [t.length.to_f] } }
    assert_equal [[3.0]], provider.embed(["abc"])
    assert_equal "custom", provider.identity
  end
end
