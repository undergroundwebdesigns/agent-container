# smile-agents

## No docker-compose (K8s-only)
This repo does NOT use docker-compose. Local dev/test target Docker Desktop's bundled Kubernetes via the Helm charts in `deploy/helm/` with overrides in `deploy/local/` (runbook: the "Full stack on Docker Desktop Kubernetes" section of `README.md`). Do not propose or add `docker-compose.yml`/`compose.yaml` or any `docker compose` invocations.
- Single-container tests (broker, mcp-base): `docker build` + `docker run` against the locally-built image.
- Control-plane work (specs, db:prepare, db:migrate, console): run in-cluster via `kubectl exec` or the chart Job templates through `control-plane/bin/init-db` and `control-plane/bin/migrate`.

The global "every Smile app needs a docker-compose" rule is overridden here; its intent (no language tooling on the host) still holds, satisfied by K8s pods.

## Git / gh auth uses GITHUB_TOKEN_EXTRAS
Git (clone/fetch/push) and the `gh` CLI/API for this repo must use `GITHUB_TOKEN_EXTRAS`, NOT `GITHUB_TOKEN` (which lacks access and 404s). Run gh as `GH_TOKEN="$GITHUB_TOKEN_EXTRAS" gh ...`. Do not conclude "no API access" from a default-token failure; switch tokens first. Never use `GITHUB_PACKAGES_TOKEN` for git. Configure via a credential helper that reads the env var at runtime; do not persist tokens in `.git/config`.

## Control-plane must NEVER call an LLM directly
The Rails control-plane never calls an LLM (not via LiteLLM, not any SDK). It only manages/kicks off agent Runs and may orchestrate multi-agent flows. All LLM work happens in sandboxed agent-runtime pods. Model any "use an LLM to do X" feature as an AgentVersion (system prompt + Skill) that the control-plane schedules a Run for; reject designs that add an LLM client to the control-plane.

Two sanctioned agent-run output paths (compose as needed; the agent does the LLM work, the control-plane only holds the credential/endpoint):
- Write-once structured result to `runs.result` (ENG-880): declare `output_schema` on the AgentVersion -> runtime injects a `submit-result` MCP tool -> result persisted via broker; the run fails unless a valid result is persisted.
- External systems via MCP through the broker (e.g. Datadog MCP).

Agent/Skill/prompt/`output_schema` definitions are authored and versioned IN the app, never seeded from repo code.

## LiteLLM hardened deploys
For LiteLLM on K8s with `runAsNonRoot` + `readOnlyRootFilesystem`, use `image.repository: ghcr.io/berriai/litellm-non_root` (built from `docker/Dockerfile.non_root`), NOT `ghcr.io/berriai/litellm`. The default image bakes the Prisma engine under root-owned `/root/.cache/...` and no env var redirects the runtime prisma client's lookup. The hardened-compose env wiring maps 1:1 only on the non_root image.

## Sandbox constraint
Git and the test/migrate loop cannot run in this authoring sandbox (Docker can't bind-mount the repo path; no kubectl/cluster). Write code and syntax-check with `ruby -c` only; `bin/update-deps`, `bin/migrate`, `bin/rspec` are the user's to run. Local dev/test loop steps: see the `smile-agents-local-dev` skill.
