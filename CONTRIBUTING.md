# Contributing

Thanks for considering a contribution to RailsFusion.

## Local setup

Requires Ruby >= 3.3 and a local PostgreSQL >= 14 with the `pgvector` extension available.

```bash
git clone https://github.com/iamzayn19/rails-fusion.git
cd rails-fusion
bundle install
```

### PostgreSQL + pgvector

```bash
brew install postgresql@17 pgvector   # or your platform's equivalent
createdb rails_fusion_test
psql rails_fusion_test -c "CREATE EXTENSION vector;"
```

The test suite connects using `PGHOST`/`PGPORT`/`PGUSER`/`PGDATABASE` environment
variables (defaults: `localhost`/`5432`/current user/`rails_fusion_test`). Schema is
created automatically by `test/support/schema.rb` on each run.

```bash
bundle exec rake test
bundle exec rubocop
bundle exec rake build
```

## Guidelines

- Keep the public API small and Rails-native.
- No network calls in tests — use `RailsFusion::Embeddings::Fake` or a stub.
- Add coverage for security-sensitive and race-sensitive changes, not just the happy path.
- Run `bundle exec rubocop` before opening a PR.

## Reporting issues

Open an issue at https://github.com/iamzayn19/rails-fusion/issues with a minimal
reproduction where possible.
