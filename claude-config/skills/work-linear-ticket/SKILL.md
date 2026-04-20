---
name: work-linear-ticket
description: >
  Work on a Linear ticket: fetch details, research and plan, post the plan to
  the ticket for owner approval (with @mention), poll with exponential backoff
  for approval, then implement once approved. Use when you want Claude to
  autonomously work a Linear ticket end-to-end.
argument-hint: "<TICKET-ID e.g. ENG-645>"
allowed-tools: Bash(sleep *) Bash(git *) Bash(gh *) Bash(asdf *) Bash(pnpm *) Bash(pnpx *) Bash(ls *) Bash(mkdir *) Bash(cd *) Read Write Edit Glob Grep Task
---

# Work on a Linear Ticket

You are working on a Linear ticket end-to-end. Follow these steps in order.
Do not skip steps. Do not proceed to implementation without explicit approval
from the ticket owner.

The ticket identifier is: `$ARGUMENTS`

> **Linear MCP Server**: All Linear operations (fetching issues, posting
> comments, updating issues) MUST use the Linear MCP server tools — never raw
> curl or GraphQL calls. The Linear MCP server handles authentication
> automatically. If the Linear MCP tools are not available, stop and ask the
> user to configure the Linear MCP server (`claude mcp add --transport http
> linear https://mcp.linear.app/mcp`).

---

## Step 1 — Validate Linear MCP Availability

Before doing anything, confirm the Linear MCP server is available by
attempting to use it. Call the Linear MCP `search_issues` tool (or equivalent)
with a query for `$ARGUMENTS`. If the call fails with a tool-not-found error,
stop immediately and tell the user:

> The Linear MCP server is not configured. Run:
> `claude mcp add --transport http linear https://mcp.linear.app/mcp`
> Then run `/mcp` to authenticate.

---

## Step 2 — Fetch Ticket Details

Use the Linear MCP `get_issue` tool to retrieve the ticket by its identifier
(e.g., `ENG-645`). If `get_issue` does not accept identifiers directly, use
`search_issues` with the ticket identifier as the query and filter to an exact
match.

From the response, extract and remember these values — you will need them for
the rest of the workflow:

| Field | Description |
|-------|-------------|
| **Issue ID** | The internal UUID of the issue |
| **Title** | The issue title |
| **Description** | The full issue description |
| **Assignee name** | Display name of the ticket owner |
| **Assignee ID** | The user ID of the assignee |
| **Status** | Current workflow state |
| **Comments** | Any existing comments on the issue |

If the ticket is not found, stop and inform the user.

If the ticket has **no assignee**, stop and inform the user.

---

## Step 3 — Research and Create a Plan

Now that you have the ticket details, do a thorough investigation:

1. **Understand the ticket**: Read the title, description, and all existing
   comments carefully. Identify what is being asked for, any constraints
   mentioned, and acceptance criteria (explicit or implied).

2. **Identify the relevant repo(s)**: Based on the ticket content, determine
   which repository or repositories are involved. Clone them if needed (into
   `/workspace/`), or navigate to them if already present. Make sure you are on
   an up-to-date `main` branch before exploring.

3. **Explore the codebase**: Use Glob, Grep, Read, and the Explore agent to
   understand:
   - Current architecture and patterns relevant to the ticket
   - Specific files and modules that will need to change
   - Test patterns and frameworks in use
   - Related recent changes (check git log)
   - Dependencies and integrations that may be affected

4. **Draft the plan**: Create a detailed, actionable implementation plan with
   these sections:

   ```
   # Implementation Plan: [TICKET-ID] — [Ticket Title]

   ## Goal
   [What the ticket is asking for, in your own words]

   ## Approach
   [High-level strategy — 2-3 sentences]

   ## Implementation Steps
   1. [Concrete step with file paths and descriptions of changes]
   2. ...

   ## Files to Change
   | File | Change |
   |------|--------|
   | `path/to/file.ext` | Description of changes |

   ## Testing Strategy
   - [How changes will be tested — unit, integration, etc.]
   - [Specific test cases to add]

   ## Risks & Open Questions
   - [Anything uncertain or potentially problematic]
   ```

5. **Save the plan locally**: Write the plan to a file at
   `/home/claude/.claude/plans/[ticket-id]-plan.md`.

6. **Run the plan reviewer**: Use the Task tool with `subagent_type: "plan-reviewer"`
   to review the plan. Incorporate any feedback from the reviewer into the plan
   before posting.

---

## Step 4 — Post Plan to Linear for Approval

Use the Linear MCP `create_comment` tool to post the plan as a comment on the
ticket. The tool expects:

- **issueId**: The issue UUID from Step 2
- **body**: The comment body in markdown

Construct the comment body as follows — note the `@mention` of the assignee at
the top. Send the content directly with real newlines (do NOT use `\n` escape
sequences — the Linear MCP server requires actual newline characters):

```markdown
@ASSIGNEE_NAME — I've drafted an implementation plan for this ticket. Please review below and reply to this comment:

- Reply **"approved"** to proceed with implementation
- Reply with feedback to request changes to the plan

---

[FULL PLAN CONTENT HERE]

---

*Awaiting your approval before proceeding with implementation. I will check back periodically.*
```

Replace `ASSIGNEE_NAME` with the actual assignee display name, and paste the
full plan content in place of the placeholder.

After posting, note the **timestamp** of when you posted the comment. You will
use this to identify which comments are newer than your plan.

---

## Step 5 — Poll for Approval with Exponential Backoff

Poll the ticket's comments for an approval response from the ticket owner.
Use **exponential backoff** starting at 1 minute, doubling each iteration,
and capping at 60 minutes (1 hour).

**Backoff schedule**: 60s, 120s, 240s, 480s, 960s, 1920s, 3600s, 3600s, ...

**Hard timeout**: Stop polling after **24 hours** of total elapsed time. If no
response is received within 24 hours, inform the user and stop.

### 5a. Sleep for the current backoff interval

Execute each sleep as a **separate** bash invocation so the user can see
progress and intervene. Print the iteration number and wait time.

```!
WAIT_SECONDS=60  # 1st iteration; double each time, cap at 3600
ITERATION=1

echo "[Iteration $ITERATION] Sleeping ${WAIT_SECONDS}s before checking for approval..."
sleep $WAIT_SECONDS
echo "Done sleeping. Checking for new comments..."
```

### 5b. Fetch the issue to check for new comments

Use the Linear MCP `get_issue` tool to fetch the issue by its UUID. The
response will include the issue's comments. Compare the comments against the
timestamp from Step 4 to identify any that were posted **after** your plan
comment.

### 5c. Evaluate the response

Check each new comment (posted after the plan comment):

**Approval keywords** (case-insensitive match anywhere in the comment body):
`approved`, `approve`, `lgtm`, `looks good`, `go ahead`, `ship it`, `proceed`,
`good to go`, `let's do it`, `sounds good`

**Decision logic**:

| Scenario | Action |
|----------|--------|
| New comment from the assignee contains an approval keyword | **Proceed to Step 6** |
| New comment from the assignee does NOT contain an approval keyword | Treat as **feedback**. Revise the plan, post the updated plan as a new comment using `create_comment` (repeat Step 4), **reset the backoff to 60s**, and resume polling. |
| New comment from someone other than the assignee | Log it but do NOT treat as approval. Continue polling. |
| No new comments | **Double the backoff** (up to 3600s cap) and loop back to 5a. |

### 5d. Print status each iteration

After each check, print a status line:

```
[Poll #N] Waited Xs | Next check in Ys | Total elapsed: Zm | No new comments.
```

or

```
[Poll #N] Waited Xs | APPROVAL RECEIVED from <name>. Proceeding to implementation.
```

or

```
[Poll #N] Waited Xs | FEEDBACK RECEIVED from <name>. Revising plan...
```

---

## Step 6 — Implement the Approved Plan

Once approval is received, proceed with implementation:

1. **Create a feature branch** from an up-to-date `main`:
   ```
   git checkout main && git pull origin main
   git checkout -b <TICKET-ID>-short-description
   ```
   The branch name must start with the ticket identifier (e.g.,
   `ENG-645-remove-datadog-overrides`). Keep the description under 100 chars
   total.

2. **Implement using TDD**:
   - Write failing tests first for the expected behavior
   - Implement the changes to make the tests pass
   - Refactor if needed while keeping tests green
   - Commit logical units of work with clear commit messages

3. **Run the full test suite** to verify nothing is broken.

4. **Push and open a draft PR**:
   ```
   git push -u origin <branch-name>
   gh pr create --draft --title "<TICKET-ID>: Short description" --assignee <github-username>
   ```
   Assign the PR to the ticket owner's GitHub username.

---

## Error Handling

- **Linear MCP tool errors**: If any Linear MCP tool call fails, retry once.
  If it fails again, stop and inform the user with the error details.
- **Git conflicts**: If you encounter merge conflicts, stop and inform the user
  rather than attempting to resolve them silently.
- **Test failures**: If tests fail after implementation, investigate and fix.
  If you cannot fix them, stop and inform the user with details about the
  failures.
- **Missing assignee**: If the ticket has no assignee, notify the user and stop.

## Important Notes

- **All Linear operations go through the MCP server** — never use curl,
  the GraphQL API, or any other direct API access.
- **Never force push** or rebase. Ever.
- **Always open draft PRs** unless explicitly told otherwise.
- **Use pnpm** instead of npm/npx for any Node.js operations.
- **Use asdf** to install language versions if needed.
- **Clean up dead code** — don't leave unused modules or commented-out code.
- **Do not leave comments on PRs or Linear** beyond what this workflow requires.
