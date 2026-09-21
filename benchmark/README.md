# Benchmarking

This is a local, non-CI benchmark. It seeds a deterministic corpus of fake products
(fake text, fake embeddings) and times keyword, semantic, and hybrid search stages plus
a no-op backfill pass. Numbers are local-machine only and not published as marketing
claims — run it yourself to get numbers for your hardware and corpus size.

```bash
createdb rails_fusion_benchmark
psql rails_fusion_benchmark -c "CREATE EXTENSION vector;"
PGDATABASE=rails_fusion_benchmark RECORDS=20000 bundle exec ruby benchmark/benchmark.rb
```
