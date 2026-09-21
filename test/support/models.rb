# frozen_string_literal: true

class Product < ActiveRecord::Base
  self.table_name = "fusion_products"

  fusion_search do
    text :name, weight: :a
    text :description, weight: :b

    embedding :search_embedding,
              dimensions: 8,
              provider: HybridSearch::Embeddings::Fake.new(dimensions: 8),
              model: "fake-test-model",
              distance: :cosine,
              auto: true

    filter :account_id
    filter :status
    filter :category_id

    recency :published_at, half_life: 30 * 24 * 60 * 60
  end
end

class Article < ActiveRecord::Base
  self.table_name = "fusion_articles"

  fusion_search do
    text :title, weight: :a
    text :body, weight: :b

    embedding :embedding,
              dimensions: 4,
              provider: HybridSearch::Embeddings::Fake.new(dimensions: 4),
              model: "fake-article-model",
              distance: :cosine,
              auto: true

    filter :account_id
  end
end

class FusionDoc < ActiveRecord::Base
  self.table_name = "fusion_docs"

  fusion_search do
    text :name, weight: :a
    text :description, weight: :b

    embedding :search_embedding,
              dimensions: 8,
              provider: HybridSearch::Embeddings::Fake.new(dimensions: 8),
              model: "fake-doc-model",
              distance: :cosine
  end
end
