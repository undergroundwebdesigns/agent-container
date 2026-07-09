# smile-shopify-reviews-handler

Repo-scoped exception (ENG-797) to the global "local dev runs in Docker" rule: you are authorized to run language tooling (ruby, bundler, rails, rspec, rubocop, pnpm, etc.) directly on the host, bypassing docker compose. The host `/workspace` path isn't on the Docker daemon's file-sharing allow-list, so `docker compose run` can't bind-mount the repo.

- Prefer asdf-managed Ruby on the host: `bundle install`, `bin/rails db:migrate`, `bin/rspec`, `bin/rubocop -A`, etc.
- The repo MUST still ship a Dockerfile + docker-compose.yaml for other contributors, and document `docker compose run --rm runner ...` in the repo README as the canonical contributor workflow.

This exception is repo-scoped and does not change the docker-only default for other Smile repos.
