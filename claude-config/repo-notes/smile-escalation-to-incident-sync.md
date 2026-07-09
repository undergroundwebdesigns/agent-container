# smile-escalation-to-incident-sync

Repo-scoped carve-out to the global "local dev runs in Docker" rule: run ruby/rspec/rubocop/postgres directly on the host. The repo's `bin/test`/`bin/rubocop` go through `smile-cli dc` (docker-compose), and Docker isn't available in this environment. Keep the docker-compose path intact for other contributors.

NEVER write `$GITHUB_PACKAGES_TOKEN` to `.bundle/config` or any on-disk file; pass it via ENV per command. The user requires no secrets on disk.

The full host test-run procedure (asdf ruby, Postgres/PGDATA setup, required env vars) is in the `incident-sync-host-tests` skill.
