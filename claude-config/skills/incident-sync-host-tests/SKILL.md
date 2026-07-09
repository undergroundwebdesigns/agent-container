---
name: incident-sync-host-tests
description: >
  Run the smile-escalation-to-incident-sync test suite on the host (Docker
  unavailable), including asdf Ruby, Postgres/PGDATA setup, private-gem auth, and
  the required env vars. Use when running rspec/rubocop for
  smile-escalation-to-incident-sync.
---

# smile-escalation-to-incident-sync host test run

The repo's `bin/test`/`bin/rubocop` go through `smile-cli dc` (docker-compose), which isn't available here. Run on the host instead. Keep the docker-compose path intact for other contributors.

## Ruby + private gems
- `asdf install ruby 4.0.5` (pinned in `.ruby-version`/Gemfile; downloads from cache.ruby-lang.org, which has been intermittently allowlisted).
- Private gems need an SSO-authorized `$GITHUB_PACKAGES_TOKEN` for the smile-io org. NEVER write it to `.bundle/config` or any on-disk file; pass via ENV per command: `BUNDLE_PATH=vendor/bundle` and `BUNDLE_RUBYGEMS__PKG__GITHUB__COM="undergroundwebdesigns:$GITHUB_PACKAGES_TOKEN"`. Never commit `vendor/bundle`.

## Postgres
- Postgres 16 binaries at `/usr/lib/postgresql/16/bin`.
- Put `PGDATA` in `$HOME` (e.g. `$HOME/pgdata`), NOT `/tmp` — /tmp is wiped between turns and the cluster vanishes.
- `initdb -U postgres --auth=trust`, start with `pg_ctl`, `createdb incident_sync_test`.

## Run
```
RAILS_ENV=test DISABLE_DATADOG=true DD_TRACE_ENABLED=false \
SMILE_CONFIG__DATABASE__HOST=127.0.0.1 \
SMILE_CONFIG__DATABASE__USERNAME=postgres \
SMILE_CONFIG__DATABASE__PASSWORD=postgres \
SMILE_CONFIG__DATABASE__NAME=incident_sync_test \
bundle exec rails db:test:prepare && bundle exec rspec
```
`DISABLE_DATADOG=true` is required or boot fails on `tracing.rack.web_service_name` nil.
