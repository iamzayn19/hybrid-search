# frozen_string_literal: true

require "test_helper"

class DefinitionTest < HybridSearch::TestCase
  def test_rejects_unknown_text_column
    assert_raises(HybridSearch::ConfigurationError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "fusion_products"
        fusion_search { text :nope }
      end
    end
  end

  def test_rejects_non_positive_dimensions
    assert_raises(HybridSearch::ConfigurationError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "fusion_products"
        fusion_search { embedding :search_embedding, dimensions: 0 }
      end
    end
  end

  def test_rejects_unsupported_distance
    assert_raises(HybridSearch::ConfigurationError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "fusion_products"
        fusion_search { embedding :search_embedding, dimensions: 8, distance: :manhattan }
      end
    end
  end

  def test_auto_embedding_requires_digest_column
    assert_raises(HybridSearch::ConfigurationError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "fusion_docs"
        fusion_search { embedding :search_embedding, dimensions: 8, auto: true }
      end
    end
  end

  def test_rejects_unknown_filter_column
    assert_raises(HybridSearch::ConfigurationError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "fusion_products"
        fusion_search { filter :nonexistent }
      end
    end
  end

  def test_rejects_non_timestamp_like_recency_column
    assert_raises(HybridSearch::ConfigurationError) do
      Class.new(ActiveRecord::Base) do
        self.table_name = "fusion_products"
        fusion_search { recency :published_at, half_life: -5 }
      end
    end
  end

  def test_valid_definition_passes
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "fusion_products"
      fusion_search do
        text :name
        filter :account_id
      end
    end
    assert klass.fusion_searchable?
  end
end
