---
name: review-pr
description: >
  Review a pull request as a senior engineer focused on security, compliance,
  correctness, and maintainability. Use when the user asks to review a PR,
  check a PR, or look over changes.
argument-hint: "[repo] [PR number or URL]"
allowed-tools: Bash(gh pr *) Bash(git diff *) Bash(git log *) Bash(git show *) Bash(git fetch *)
---

# Senior PR Review

You are acting as a senior engineer performing a thorough pull request review.
Your primary lens is **security and compliance**, but you also review for
correctness, maintainability, and operational risk.

## Input

The argument `$ARGUMENTS` can be provided in several forms:

- **PR number only** — e.g. `123` — uses the current repo
- **Repo and PR number** — e.g. `owner/repo 123` or `owner/repo#123` — targets a specific repo
- **Full URL** — e.g. `https://github.com/owner/repo/pull/123`
- **No argument** — reviews the PR associated with the current branch

## Step 1 — Gather Context

Fetch the PR metadata and full diff. Run these commands to collect everything
you need before reading a single line of code:

```!
# Parse arguments: support "owner/repo 123", "owner/repo#123", a full URL, or just a PR number
ARGS="$ARGUMENTS"
REPO_FLAG=""
PR_REF=""

if [ -z "$ARGS" ]; then
  # No arguments — use current branch's PR
  PR_REF="$(gh pr view --json number -q .number 2>/dev/null)"
elif echo "$ARGS" | grep -qE '^https?://'; then
  # Full URL — gh handles these natively
  PR_REF="$ARGS"
elif echo "$ARGS" | grep -qE '^[^/]+/[^/]+#[0-9]+$'; then
  # owner/repo#123
  REPO_FLAG="--repo $(echo "$ARGS" | cut -d'#' -f1)"
  PR_REF="$(echo "$ARGS" | cut -d'#' -f2)"
elif echo "$ARGS" | grep -qE '^[^/]+/[^/]+ [0-9]+$'; then
  # owner/repo 123
  REPO_FLAG="--repo $(echo "$ARGS" | awk '{print $1}')"
  PR_REF="$(echo "$ARGS" | awk '{print $2}')"
else
  # Assume it's a bare PR number or branch name
  PR_REF="$ARGS"
fi

if [ -z "$PR_REF" ]; then
  echo "ERROR: No PR found. Pass a PR number, URL, or repo#number, or run from a branch with an open PR."
  exit 1
fi

echo "=== PR METADATA ==="
gh pr view "$PR_REF" $REPO_FLAG --json title,body,author,baseRefName,headRefName,number,url,labels,files,additions,deletions,reviewDecision,state

echo ""
echo "=== CHANGED FILES ==="
gh pr diff "$PR_REF" $REPO_FLAG --name-only

echo ""
echo "=== FULL DIFF ==="
gh pr diff "$PR_REF" $REPO_FLAG
```

If the diff is very large (>2000 lines), prioritize reviewing the most
security-sensitive files first, then work through the rest methodically. Use
the Read tool to examine full file context when the diff alone is insufficient.

## Step 2 — Analyse

Work through **every changed file**. For each file, evaluate against the
checklist below. Do not skip files — even test and config changes can introduce
vulnerabilities.

### Security (Critical)

- **Injection flaws**: SQL injection, command injection, XSS, template
  injection, LDAP injection, header injection. Check every place user input
  flows into queries, commands, markup, or headers.
- **Authentication & authorization**: Are auth checks present and correct?
  Are there new endpoints or routes missing auth middleware? Does the change
  bypass or weaken existing access controls?
- **Secrets & credentials**: Hardcoded secrets, API keys, tokens, passwords,
  or connection strings — even in tests or comments. Check for accidental
  inclusion of `.env` files, credentials files, or private keys.
- **Cryptography**: Use of weak algorithms (MD5, SHA1 for security purposes,
  ECB mode), custom crypto implementations, predictable randomness for
  security-sensitive operations.
- **Deserialization**: Unsafe deserialization of untrusted data (e.g.,
  `Marshal.load`, `pickle.loads`, `JSON.parse` on user input piped into
  `eval`, YAML.load without safe mode).
- **File handling**: Path traversal, unrestricted file uploads, symlink
  attacks, insecure temp file creation.
- **Dependency changes**: New dependencies added? Check for known
  vulnerabilities, overly broad version ranges, typosquatting risk. Flag any
  dependency that hasn't been audited.
- **Logging & error handling**: Sensitive data leaking into logs or error
  messages (PII, tokens, stack traces exposed to users).
- **SSRF & open redirects**: Requests to user-controlled URLs without
  allowlist validation, redirects to arbitrary destinations.
- **Mass assignment / over-posting**: Models or DTOs accepting unfiltered
  user input that could set privileged fields.

### Compliance & Data Privacy

- **PII handling**: Is personally identifiable information collected, stored,
  transmitted, or logged? Is it encrypted at rest and in transit?
- **Data retention**: Are there changes to how long data is kept? Is there a
  deletion path?
- **Consent & disclosure**: If new data collection is introduced, is consent
  obtained?
- **Audit trails**: Are security-relevant actions (login, permission change,
  data access, deletion) logged in an auditable way?
- **Regulatory flags**: GDPR right-to-erasure, SOC 2 access controls, PCI
  cardholder data handling — flag anything that touches regulated data.

### Correctness

- **Logic errors**: Off-by-one, wrong operator, inverted conditions, missing
  null/nil/undefined checks, incorrect type coercions.
- **Edge cases**: Empty inputs, boundary values, concurrent access, race
  conditions, large payloads.
- **Error handling**: Unhandled exceptions, swallowed errors, missing
  rollback/cleanup in failure paths.
- **Data integrity**: Schema migrations that could lose data, missing
  transactions around multi-step writes, inconsistent state on partial
  failure.
- **Test coverage**: Are new code paths tested? Do tests actually assert
  meaningful behavior (not just "no exception thrown")? Are edge cases and
  failure modes tested?

### Maintainability & Operations

- **Breaking changes**: API contract changes, removed fields, changed return
  types, renamed environment variables.
- **Rollback safety**: Can this change be rolled back without data loss or
  downtime? Are database migrations reversible?
- **Observability**: Are new features instrumented with metrics, logs, or
  traces? Can operators detect and diagnose failures?
- **Performance**: N+1 queries, missing indexes, unbounded loops, missing
  pagination, large allocations in hot paths.
- **Configuration**: New environment variables or feature flags documented?
  Sensible defaults?

## Step 3 — Write the Review

Structure your review as follows:

### Summary

One paragraph summarizing what the PR does, its scope, and your overall
assessment. State the review verdict clearly:

- **Approve** — No blocking issues. Minor suggestions only.
- **Request changes** — Blocking issues found that must be addressed.
- **Comment** — Non-blocking observations; author should consider but can
  merge at their discretion.

### Security Findings

List every security-relevant finding, even low-severity ones. For each:

| Field | Content |
|-------|---------|
| **Severity** | Critical / High / Medium / Low / Informational |
| **File** | `path/to/file.ext:line` |
| **Finding** | What the issue is |
| **Risk** | What could go wrong (attack scenario) |
| **Recommendation** | Specific fix or mitigation |

If there are no security findings, explicitly state: "No security issues
identified."

### Compliance Findings

Same format as security findings, focused on data privacy and regulatory
concerns.

### Code Quality

Bullet list of non-security observations: logic bugs, style, naming, missing
tests, performance, documentation gaps. Keep it concise — focus on things that
matter, not nitpicks.

### Questions

List anything you're unsure about or need the author to clarify before a final
verdict.

## Guidelines

- Be direct and specific. "This is vulnerable to SQL injection because the
  user-supplied `order_by` parameter is interpolated directly into the query
  on line 42" is useful. "Be careful with SQL" is not.
- Always reference specific file paths and line numbers.
- Suggest concrete fixes, not just problems.
- Distinguish blocking issues from suggestions clearly.
- Do not leave review comments on the PR unless the user explicitly asks you to.
  Present the review in the conversation only.
- When in doubt about severity, err on the side of caution — flag it and let
  the author make the call.
- Praise genuinely good patterns (defense in depth, thorough input
  validation, good test coverage) briefly — positive reinforcement matters.
