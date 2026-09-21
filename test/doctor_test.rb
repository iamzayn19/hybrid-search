# frozen_string_literal: true

require "test_helper"

class DoctorTest < RailsFusion::TestCase
  def test_reports_postgres_and_pgvector_ok
    checks = RailsFusion::Doctor.new.call
    assert(checks.any? { |c| c.name == "database_adapter" && c.status == :ok })
    assert(checks.any? { |c| c.name == "pgvector_extension" && c.status == :ok })
  end

  def test_model_checks_report_missing_embeddings
    Product.create!(name: "unembedded", description: "d", account_id: 1, status: "published")
    checks = RailsFusion::Doctor.new(Product).call
    status_check = checks.find { |c| c.name == "embedding_status" }
    refute_nil status_check
    assert_match(/missing/, status_check.message)
  end

  def test_unconfigured_model_reports_error
    klass = Class.new(ActiveRecord::Base) { self.table_name = "fusion_products" }
    checks = RailsFusion::Doctor.new(klass).call
    assert(checks.any? { |c| c.status == :error })
  end
end
