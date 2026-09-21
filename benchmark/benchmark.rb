# frozen_string_literal: true

# Non-CI benchmark. Seeds a deterministic corpus of fake products with fake
# embeddings and times each stage of a hybrid search. Not run in CI; run
# locally against a real PostgreSQL + pgvector database. See benchmark/README.md.
#
#   PGDATABASE=hybrid_search_benchmark RECORDS=20000 ruby benchmark/benchmark.rb

require "bundler/setup"
require "active_record"
require "benchmark"
require_relative "../lib/hybrid_search"

ActiveRecord::Base.establish_connection(
  adapter: "postgresql",
  host: ENV.fetch("PGHOST", "localhost"),
  port: ENV.fetch("PGPORT", "5433").to_i,
  username: ENV.fetch("PGUSER", ENV.fetch("USER", nil)),
  database: ENV.fetch("PGDATABASE", "hybrid_search_benchmark")
)

ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS vector")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  drop_table :bench_products, if_exists: true
  create_table :bench_products do |t|
    t.string :name
    t.text :description
    t.bigint :account_id
    t.vector :search_embedding, limit: 16
    t.string :search_embedding_digest
    t.timestamps
  end
  add_index :bench_products, :search_embedding, using: :hnsw, opclass: :vector_cosine_ops
end

class BenchProduct < ActiveRecord::Base
  self.table_name = "bench_products"

  fusion_search do
    text :name, weight: :a
    text :description, weight: :b
    embedding :search_embedding, dimensions: 16,
                                 provider: HybridSearch::Embeddings::Fake.new(dimensions: 16),
                                 model: "bench-fake"
    filter :account_id
  end
end

record_count = ENV.fetch("RECORDS", "10000").to_i
provider = BenchProduct.hybrid_search_definition.embedding_config.provider

puts "Seeding #{record_count} records..."
Benchmark.bm(30) do |x|
  x.report("seed") do
    record_count.times.each_slice(1000) do |batch|
      rows = batch.map do |i|
        text = "product #{i} widget gadget device number #{i}"
        {
          name: "Product #{i}",
          description: text,
          account_id: i % 50,
          search_embedding: provider.embed([text]).first.to_s,
          created_at: Time.now, updated_at: Time.now
        }
      end
      BenchProduct.insert_all(rows)
    end
  end
end

Benchmark.bm(30) do |x|
  x.report("keyword candidates") { BenchProduct.fusion_search("widget gadget", where: { account_id: 1 }) }
  x.report("full hybrid search") { BenchProduct.fusion_search("widget gadget device", where: { account_id: 1 }) }
  x.report("backfill (no-op)") { HybridSearch::Backfill.new(BenchProduct, mode: :sync).call }
end

puts "Done. Results above are local-machine timings only; do not treat as portable benchmarks."
