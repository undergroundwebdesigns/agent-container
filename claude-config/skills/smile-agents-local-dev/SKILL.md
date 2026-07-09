---
name: smile-agents-local-dev
description: >
  The smile-agents control-plane local build/migrate/test loop on Docker Desktop
  Kubernetes, and which bin/ scripts build an image vs run inside one. Use when
  running or handing off the smile-agents local dev/test loop after any
  Ruby/Gemfile/config/migration change.
---

# smile-agents local dev/test loop

smile-agents runs on Docker Desktop Kubernetes (no compose, no source bind-mount for gems). After any Ruby/Gemfile/config/migration change, use the repo's own `control-plane/bin/` scripts in this order:

1. **`bin/update-deps`** — regenerates `Gemfile.lock` in a ruby container. Needs `BUNDLE_RUBYGEMS__PKG__GITHUB__COM="x-access-token:<packages PAT>"`. Run after any Gemfile change.
2. **Rebuild the `:dev` image** — `docker build --secret id=BUNDLE_RUBYGEMS__PKG__GITHUB__COM,env=BUNDLE_RUBYGEMS__PKG__GITHUB__COM -t smile-agents/control-plane:dev control-plane/`. Required after any in-image change (code, gems, config).
3. **`bin/migrate`** — runs `db:migrate db:schema:dump` as an in-cluster Job and dumps the refreshed `db/schema.rb` to the hostPath-mounted checkout. It does NOT build an image; it boots the existing `:dev` image, so step 2 must precede it or the app fails to boot (e.g. a new gem isn't present).
4. **`bin/rspec`** — builds its own `:test` image each run (Dockerfile `test` stage), then runs `db:test:prepare` (loads `db/schema.rb`, so step 3 must have refreshed it) + rspec as an in-cluster Job. No manual rebuild needed for this step.

Key nuance: `bin/migrate` uses the deployed image; `bin/rspec` builds fresh. So a deps/code change needs a manual `:dev` rebuild before `bin/migrate` but not before `bin/rspec`.

These steps cannot run in the authoring sandbox (Docker can't bind-mount the repo path; no kubectl/cluster). Write code and syntax-check with `ruby -c`; the numbered steps are the user's to run.
