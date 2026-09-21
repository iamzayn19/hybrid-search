# Contributing

Thanks for considering a contribution to HybridSearch.

## Local setup

Requires Ruby >= 3.3 and a local PostgreSQL >= 14 with the `pgvector` extension available.

```bash
git clone https://github.com/iamzayn19/hybrid-search.git
cd hybrid-search
bundle install
```

### PostgreSQL + pgvector

```bash
brew install postgresql@17 pgvector   # or your platform's equivalent
createdb hybrid_search_test
psql hybrid_search_test -c "CREATE EXTENSION vector;"
```

The test suite connects using `PGHOST`/`PGPORT`/`PGUSER`/`PGDATABASE` environment
variables (defaults: `localhost`/`5432`/current user/`hybrid_search_test`). Schema is
created automatically by `test/support/schema.rb` on each run.

```bash
bundle exec rake test
bundle exec rubocop
bundle exec rake build
```

## Guidelines

- Keep the public API small and Rails-native.
- No network calls in tests — use `HybridSearch::Embeddings::Fake` or a stub.
- Add coverage for security-sensitive and race-sensitive changes, not just the happy path.
- Run `bundle exec rubocop` before opening a PR.

## Reporting issues

Open an issue at https://github.com/iamzayn19/hybrid-search/issues with a minimal
reproduction where possible.
