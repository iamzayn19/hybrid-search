# frozen_string_literal: true

require "test_helper"

class AdversarialTest < HybridSearch::TestCase
  def test_sql_injection_via_query_text_is_inert
    Product.create!(name: "safe", description: "d", account_id: 1, status: "published")
    payloads = [
      "'; DROP TABLE fusion_products; --",
      "\" OR \"1\"=\"1",
      "%'; SELECT pg_sleep(0); --",
      "\u0000nullbyteattempt",
      "héllo wörld \u{1F600}"
    ]

    payloads.each do |payload|
      Product.fusion_search(payload, where: { account_id: 1 })
    rescue ArgumentError
      # blank-after-normalization payloads are allowed to raise ArgumentError
    end

    assert Product.table_exists?
    assert_equal 1, Product.count
  end

  def test_sql_injection_via_filter_value_is_parameterized
    Product.create!(name: "n", description: "d", account_id: 1, status: "published")
    injected = "'; DROP TABLE fusion_products; --"

    results = Product.fusion_search("n", where: { account_id: injected })
    assert results.empty?
    assert Product.table_exists?
  end

  def test_undeclared_filter_key_raises
    assert_raises(HybridSearch::InvalidFilterError) do
      Product.fusion_search("n", where: { "id > 0 OR 1=1" => 1 })
    end
  end

  def test_task_support_rejects_arbitrary_class_names
    assert_raises(HybridSearch::ConfigurationError) do
      HybridSearch::TaskSupport.require_model!("Kernel")
    end
  end

  def test_task_support_rejects_unconfigured_model
    klass_name = "FusionDoc" # exists, is an AR model, but has no auto-callbacks needed; still configured
    assert HybridSearch::TaskSupport.resolve_model(klass_name)

    assert_raises(HybridSearch::ConfigurationError) do
      HybridSearch::TaskSupport.require_model!("NoSuchModelXYZ")
    end
  end

  def test_column_names_are_validated_at_configuration_time
    error = assert_raises(HybridSearch::ConfigurationError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "fusion_products"
        fusion_search { text :"name; DROP TABLE fusion_products" }
      end
    end
    assert_match(/does not match a column/, error.message)
  end
end
