# frozen_string_literal: true

require "test_helper"
require "rails/generators"
require "rails/generators/test_case"
require_relative "../../lib/generators/rails_fusion/install/install_generator"
require_relative "../../lib/generators/rails_fusion/index/index_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests RailsFusion::Generators::InstallGenerator
  destination File.expand_path("../../tmp/generators/install", __dir__)
  setup :prepare_destination

  def test_creates_initializer
    run_generator
    assert_file "config/initializers/rails_fusion.rb" do |content|
      assert_match(/RailsFusion.configure/, content)
    end
  end
end

class IndexGeneratorTest < Rails::Generators::TestCase
  tests RailsFusion::Generators::IndexGenerator
  destination File.expand_path("../../tmp/generators/index", __dir__)
  setup :prepare_destination

  def test_generates_migration_with_expected_statements
    run_generator %w[Product name description --embedding-column=search_embedding --dimensions=8 --distance=cosine]

    migration_files = Dir[File.join(destination_root, "db/migrate/*add_rails_fusion_to_products.rb")]
    assert_equal 1, migration_files.size

    content = File.read(migration_files.first)
    assert_match(/enable_extension "vector"/, content)
    assert_match(/add_column :products, :search_embedding, :vector, limit: 8/, content)
    assert_match(/add_column :products, :search_embedding_digest, :string/, content)
    assert_match(/using: :hnsw, opclass: :vector_cosine_ops/, content)
    assert_match(/USING gin/, content)
  end

  def test_generated_index_names_stay_under_identifier_limit
    run_generator %w[
      ProductWithAVeryLongModelNameThatWouldExceedPostgresIdentifierLimits name description
    ]

    migration_file = Dir[File.join(destination_root, "db/migrate/*.rb")].first
    content = File.read(migration_file)
    content.scan(/name:\s*"([^"]+)"/).flatten.each do |name|
      assert_operator name.bytesize, :<=, 63
    end
  end
end
