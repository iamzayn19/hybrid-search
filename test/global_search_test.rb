# frozen_string_literal: true

require "test_helper"

class GlobalSearchTest < HybridSearch::TestCase
  def test_fuses_results_from_two_models
    Product.create!(name: "AI conference", description: "London event", account_id: 1, status: "published")
    Article.create!(title: "AI conference recap", body: "London", account_id: 1)

    results = HybridSearch.search("AI conference London", models: [Product, Article])

    models_seen = results.map(&:model).uniq
    assert_includes models_seen, Product
    assert_includes models_seen, Article
  end

  def test_different_embedding_dimensions_do_not_break_global_search
    Product.create!(name: "widget", description: "d", account_id: 1, status: "published")
    Article.create!(title: "widget article", body: "b", account_id: 1)

    assert_kind_of HybridSearch::GlobalResultSet, HybridSearch.search("widget", models: [Product, Article])
  end

  def test_model_level_filters_respected
    Product.create!(name: "scoped", description: "d", account_id: 1, status: "published")
    Product.create!(name: "scoped", description: "d", account_id: 2, status: "published")

    results = HybridSearch.search(
      "scoped", models: [Product], where: { Product => { account_id: 1 } }
    )
    assert(results.all? { |r| r.record.account_id == 1 })
  end

  def test_one_model_empty_does_not_break_search
    Article.create!(title: "solo result", body: "b", account_id: 1)
    results = HybridSearch.search("solo result", models: [Product, Article])
    refute results.empty?
  end

  def test_partial_failure_mode_represents_failure_honestly
    Product.create!(name: "ok", description: "d", account_id: 1, status: "published")

    broken = Class.new(ActiveRecord::Base) do
      self.table_name = "fusion_articles"
      fusion_search { text :title }
    end
    def broken.fusion_search(*)
      raise "boom"
    end

    results = HybridSearch.search("ok", models: [Product, broken])
    assert results.degraded?
    assert results.errors.key?(broken)
  end

  def test_fail_fast_mode_raises
    Product.create!(name: "ok", description: "d", account_id: 1, status: "published")
    broken = Class.new(ActiveRecord::Base) do
      self.table_name = "fusion_articles"
      fusion_search { text :title }
    end
    def broken.fusion_search(*)
      raise "boom"
    end

    assert_raises(RuntimeError) do
      HybridSearch.search("ok", models: [Product, broken], fail_fast: true)
    end
  end

  def test_too_many_models_raises
    models = Array.new(25) { Product }
    assert_raises(ArgumentError) { HybridSearch.search("x", models: models) }
  end
end
