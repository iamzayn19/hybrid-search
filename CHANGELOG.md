# Changelog

## 0.1.0 - 2026-09-22

Initial release.

- Rails-native `fusion_search do ... end` model DSL.
- PostgreSQL full-text keyword search with weighted columns and safe,
  bind-parameterized `websearch_to_tsquery`/`ts_rank_cd` retrieval.
- pgvector-backed semantic search via `neighbor`, with cosine/L2/inner-product
  distance and HNSW index generation.
- Reciprocal Rank Fusion combining keyword and semantic rankings, with
  per-search weight/candidate_k/rrf_k overrides and deterministic tie-breaking.
- Automatic, race-safe embedding lifecycle: digest-based staleness detection,
  after_commit enqueue, and a job that refuses to overwrite a newer embedding
  with stale output.
- Safe declared filters with adversarial tenant-isolation coverage across both
  keyword and semantic channels.
- Optional recency boost with a bounded, deterministic decay function.
- Machine-readable `result.explain` score breakdown.
- Multi-model global search (`RailsFusion.search`) with a second rank-fusion
  layer across independently ranked models.
- Graceful keyword-only degradation (`semantic_failure: :keyword_only`) with
  honest result metadata, or `:raise` (default).
- `rails_fusion:install` and `rails_fusion:index` generators, including a
  migration generator for pgvector/GIN indexes.
- `rails_fusion:doctor`, `rails_fusion:status`, and `rails_fusion:backfill`
  operational tasks.
- `ActiveSupport::Notifications` instrumentation with no telemetry.
