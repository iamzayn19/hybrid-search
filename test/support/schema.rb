# frozen_string_literal: true

ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector")
ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  drop_table :fusion_products, if_exists: true
  create_table :fusion_products do |t|
    t.string :name
    t.text :description
    t.string :status
    t.bigint :account_id
    t.integer :category_id
    t.datetime :published_at
    t.vector :search_embedding, limit: 8
    t.string :search_embedding_digest
    t.timestamps
  end
  add_index :fusion_products, :search_embedding, using: :hnsw, opclass: :vector_cosine_ops

  drop_table :fusion_articles, if_exists: true
  create_table :fusion_articles do |t|
    t.string :title
    t.text :body
    t.bigint :account_id
    t.vector :embedding, limit: 4
    t.string :embedding_digest
    t.timestamps
  end
  add_index :fusion_articles, :embedding, using: :hnsw, opclass: :vector_cosine_ops

  drop_table :fusion_docs, if_exists: true
  create_table :fusion_docs, id: :uuid, default: "gen_random_uuid()" do |t|
    t.string :name
    t.text :description
    t.vector :search_embedding, limit: 8
    t.string :search_embedding_digest
    t.timestamps
  end
end
