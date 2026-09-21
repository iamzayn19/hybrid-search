# RailsFusion

**Hybrid keyword + semantic search for Rails, powered by Postgres. No Elasticsearch, no separate vector database.**

[![CI](https://github.com/iamzayn19/rails-fusion/actions/workflows/ci.yml/badge.svg)](https://github.com/iamzayn19/rails-fusion/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/rails_fusion)](https://rubygems.org/gems/rails_fusion)
![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.3-red)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

## 30-second explanation

RailsFusion gives an ActiveRecord model hybrid search in a few lines: PostgreSQL full-text
search for exact words and identifiers, pgvector semantic similarity for meaning, and
Reciprocal Rank Fusion (RRF) to combine the two into one ranked, explainable result list —
all on the Postgres database your Rails app already runs.

```ruby
class Product < ApplicationRecord
  fusion_search do
    text :name, weight: :a
    text :description, weight: :b

    embedding :search_embedding, dimensions: 1536, provider: :ruby_llm,
              model: "text-embedding-3-small", auto: true

    filter :account_id
    filter :status
  end
end

Product.fusion_search("wireless headphones for long flights", where: { account_id: current_account.id })
```

## Why hybrid search

Keyword search alone misses meaning ("noise cancelling" vs. "quiet cabin"). Semantic
search alone can miss exact identifiers, error codes, and SKUs a user typed verbatim.
RailsFusion runs both independently over the same filtered scope and fuses the rankings
with RRF, so an exact identifier match and a meaning-only match can both surface, ranked
sensibly relative to each other.

## Installation

Add to your Gemfile:

```ruby
gem "rails_fusion"
```

Then:

```bash
bundle install
bin/rails generate rails_fusion:install
```

## PostgreSQL / pgvector requirement

RailsFusion requires **PostgreSQL >= 14** with the [pgvector](https://github.com/pgvector/pgvector)
extension available. It does not support MySQL or SQLite; keyword-only search on those
databases is not implemented or claimed. Run `bin/rails rails_fusion:doctor` to confirm
your setup, including whether pgvector is installed.

## Quick start

```bash
bin/rails generate rails_fusion:index Product name description \
  --embedding-column=search_embedding --dimensions=1536 --distance=cosine
bin/rails db:migrate
```

```ruby
class Product < ApplicationRecord
  fusion_search do
    text :name, weight: :a
    text :description, weight: :b

    embedding :search_embedding,
      dimensions: 1536,
      provider: :ruby_llm,
      model: "text-embedding-3-small",
      auto: true

    filter :account_id
    filter :status
  end
end
```

```ruby
RailsFusion.configure do |config|
  config.embedding_provider = RailsFusion::Embeddings::RubyLLMProvider.new(model: "text-embedding-3-small")
end
```

```bash
bin/rails rails_fusion:backfill MODEL=Product
```

```ruby
results = Product.fusion_search("wireless headphones for long flights", where: { account_id: 1 }, limit: 20)
results.each { |r| puts "#{r.record.name} (score=#{r.score.round(4)})" }
```

## Model configuration

```ruby
fusion_search do
  text :name, weight: :a            # weight: :a, :b, :c, or :d (PostgreSQL FTS weights)
  text :description, weight: :b

  embedding :search_embedding,      # a pgvector column added by the index generator
    dimensions: 1536,
    provider: :ruby_llm,            # :ruby_llm, :fake, :callable, or any provider instance
    model: "text-embedding-3-small",
    distance: :cosine,              # :cosine, :l2, :inner_product
    source: %i[name description],   # defaults to declared `text` fields, in order
    auto: true                      # keep the embedding current via after_commit + Active Job

  filter :account_id                # only declared filters are accepted by `where:`
  filter :status

  recency :published_at, half_life: 30.days
end
```

Configuration is validated against the model's actual columns at definition time, raising
`RailsFusion::ConfigurationError` immediately with an actionable message — not silently at
search time.

## Searching

```ruby
results = Product.fusion_search(
  "wireless headphones for long flights",
  where: { account_id: current_account.id, status: "published" },
  limit: 20
)

results.records          # => [#<Product>, ...]
results.first
results.empty?
results.each { |r| ... }

result = results.first
result.record
result.score
result.keyword_rank
result.semantic_rank
result.keyword_score
result.semantic_score
result.recency_score
result.matched_by         # => [:keyword, :semantic]
result.explain            # machine-readable score breakdown
```

`fusion_search` returns a `RailsFusion::ResultSet`, not an `ActiveRecord::Relation` —
results are already materialized and fused from two independent candidate queries, so
further AR chaining would be misleading. Ordering is deterministic: ties are broken by
primary key.

## Filters / multi-tenancy

Only columns declared with `filter` are accepted. An undeclared key raises
`RailsFusion::InvalidFilterError`. Both the keyword and semantic candidate queries run
against the exact same filtered scope, so a record from another tenant can never surface
as a "close" semantic match — this is covered by adversarial tests (see
`test/search/search_test.rb` and `test/security/adversarial_test.rb`).

```ruby
Product.fusion_search("query", where: { account_id: 42, status: "published" })
Product.fusion_search("query", where: { category_id: [10, 20] })  # array equality
Product.fusion_search("query", where: { account_id: nil })        # explicit nil
```

## Embedding providers

```ruby
RailsFusion.configure do |config|
  config.embedding_provider = RailsFusion::Embeddings::RubyLLMProvider.new(model: "text-embedding-3-small")
end
```

Built-in adapters:

- `RailsFusion::Embeddings::RubyLLMProvider` — backed by the [`ruby_llm`](https://github.com/crmne/ruby_llm)
  gem, only registered when it is present in your bundle.
- `RailsFusion::Embeddings::Callable` — wrap any lambda/client: `Callable.new { |texts| MyClient.embed(texts) }`.
- `RailsFusion::Embeddings::Fake` — deterministic, local, no network. Good for development
  and tests; **not** a real embedding model.

A provider can be set globally or per index (`embedding ..., provider: my_provider`).
**Using a remote provider sends your configured searchable text to that provider.** Use
`Fake` or a local/self-hosted embedding model if you need to avoid external data transfer.

## Automatic embedding lifecycle

With `auto: true`, RailsFusion enqueues an `EmbedRecordJob` (Active Job) after a committed
create/update, but only when the configured source fields actually changed. The job:

1. re-checks the record's current content digest before generating a vector;
2. generates the embedding;
3. re-checks the digest again immediately before persisting;
4. refuses to overwrite a newer embedding with stale output if the record changed again
   while the job was running.

It persists with `update_columns`, which skips callbacks entirely, so it cannot recurse
into another enqueue. Deleted records and duplicate jobs are harmless no-ops.

## Backfill / status / doctor

```bash
bin/rails rails_fusion:doctor
bin/rails rails_fusion:status MODEL=Product
bin/rails rails_fusion:backfill MODEL=Product BATCH_SIZE=500
bin/rails rails_fusion:backfill MODEL=Product FORCE=true ASYNC=true
```

`doctor` checks the database adapter, pgvector availability, model column/index
configuration, and provider setup, exiting non-zero on genuine misconfiguration.
`backfill` batches with `find_each`, is resumable and idempotent (records whose digest is
already current are skipped unless `FORCE=true`), and one record failing to embed does not
abort the run unless `FAIL_FAST=true`.

## Ranking & RRF

```text
score = keyword_weight / (rrf_k + keyword_rank) + semantic_weight / (rrf_k + semantic_rank) + recency
```

Defaults: `candidate_k: 50`, `rrf_k: 60`, `keyword_weight: 1.0`, `semantic_weight: 1.0`,
`limit: 20`. A result missing from one channel contributes zero for that channel but
remains eligible via the other. Raw `ts_rank_cd` and cosine distance are never compared
directly — RRF always fuses on rank position.

```ruby
Product.fusion_search(query, keyword_weight: 1.3, semantic_weight: 0.8, candidate_k: 100, rrf_k: 60)
```

## Explainability

```ruby
result.explain
# => {
#   final_score: 0.0317,
#   keyword: { matched: true, rank: 2, raw_score: 0.41, rrf_contribution: 0.0161 },
#   semantic: { matched: true, rank: 4, distance: 0.182, rrf_contribution: 0.0156, degraded: nil },
#   recency: { applied: false, contribution: 0.0 }
# }
```

## Global / multi-model search

```ruby
RailsFusion.search(
  "AI events in London",
  models: [Event, Community, Article],
  where: {
    Event => { account_id: 42 },
    Community => { account_id: 42 },
    Article => { account_id: 42 }
  },
  limit: 20
)
```

Each model runs its own independent hybrid ranking — raw vector similarity is never
compared across models with different dimensions/providers. A second rank-fusion layer
combines the per-model result lists. By default, one model/provider failing does not abort
the whole search (`result_set.degraded?` / `.errors`); pass `fail_fast: true` to raise
instead.

## Failure / fallback behavior

```ruby
RailsFusion.configure { |config| config.semantic_failure = :keyword_only } # or :raise (default)
```

When semantic search is degraded (no provider configured, or the provider raised), results
are still returned from keyword search, but `result.explain[:semantic][:degraded]` records
why, and a `semantic_search_failure.rails_fusion` instrumentation event fires. RailsFusion
never silently presents keyword-only results as full hybrid search.

## Instrumentation

`ActiveSupport::Notifications` events: `search.rails_fusion`, `embedding.rails_fusion`,
`backfill.rails_fusion`, `semantic_search_failure.rails_fusion`,
`global_search_model_failure.rails_fusion`. Payloads never include secrets, full embedding
vectors, or raw query text by default. No telemetry is ever sent externally.

## Performance / index guidance

The index generator creates an HNSW index matching your configured distance metric and a
GIN index over a weighted `tsvector` expression. See `benchmark/README.md` for a
reproducible local benchmark script — this gem does not publish unverified performance
claims.

## Privacy / security

- All user query text is bind-parameterized; no SQL interpolation.
- Configured column/filter names are validated against the model schema before use.
- Only declared filters are accepted; everything else raises.
- Remote embedding providers receive your configured searchable text — see "Embedding
  providers" above.
- No telemetry, no hosted control plane, no account, no license key.

## Comparison / scope

### Why not just Neighbor?

[`neighbor`](https://github.com/ankane/neighbor) is an excellent nearest-neighbor building
block, and its docs even show how to assemble a hybrid-search recipe by hand. RailsFusion
uses `neighbor` under the hood and focuses on the layer above it: declarative model
configuration, full-text search setup, the embedding lifecycle (digest/staleness,
race-safe jobs, backfill), safe multi-tenant filtering, rank fusion, explainability, global
search, and operational tooling — the integration work teams currently assemble themselves.

### Why not Elasticsearch / OpenSearch / Algolia?

Those are excellent systems when a product needs their scale or feature set. RailsFusion
targets teams that want strong hybrid search while keeping data and search in the Postgres
database they already operate. It does not claim to replace a dedicated search engine at
every scale.

### Why not pg_search?

[`pg_search`](https://github.com/Casecommons/pg_search) is lexical full-text search.
RailsFusion combines lexical and semantic ranking, plus the embedding lifecycle and
operational tooling pg_search does not address.

## Limitations

- PostgreSQL only; MySQL/SQLite are not supported.
- pgvector is required for semantic search; without it, only keyword search runs, and
  `doctor` says so explicitly.
- Embedding quality depends entirely on the chosen provider/model.
- HNSW/ANN tuning depends on your corpus size and recall requirements.
- Hybrid ranking weights are reasonable defaults, not a universal optimum — tune for your
  domain.
- Remote embedding providers receive configured source/query text.
- Not a replacement for Elasticsearch/OpenSearch/Algolia at every scale or use case.
- Not a full RAG framework — it returns ranked records, not generated answers.
- Composite primary keys are not supported in v0.1.

## Development

```bash
git clone https://github.com/iamzayn19/rails-fusion.git
cd rails-fusion
bundle install
createdb rails_fusion_test
psql rails_fusion_test -c "CREATE EXTENSION vector;"
PGDATABASE=rails_fusion_test bundle exec rake test
bundle exec rubocop
```

See `CONTRIBUTING.md` for the full local PostgreSQL + pgvector test setup.

## Contributing

Bug reports and pull requests are welcome at
https://github.com/iamzayn19/rails-fusion. See `CONTRIBUTING.md`.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
