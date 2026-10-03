# Posting the review — mechanics

Read this once the user has said yes to posting. Everything here is mechanical; the
judgment about *what* to post lives in `posting_triage.md` and Step 10.

## Inline review comments (the default)

File **one** review carrying all the inline threads, so they arrive as a single
notification rather than a burst.

### 1. Anchor each finding to a changed line

A review comment can only attach to a line that appears in the PR diff. For each
finding, pick the `path` and the head-side line number where the problem lives *and*
which shows up in a diff hunk (the `+` side).

- New file: the whole file is in the diff, so any line works.
- Edited file: confirm the line is inside a hunk before you rely on it.

```bash
# hunk ranges on the head side for a given file
git diff origin/<base>..pr-<N> -- <path> | grep -nE '^@@'
```

Read `@@ -old,n +new,m @@` as: head-side lines `new` through `new + m - 1` are
anchorable. If the exact line you want isn't in a hunk, anchor to the nearest changed
line in the same construct and say so in the comment body.

Verify your anchors point at the code you think they do before posting — line numbers
drift between commits, and a comment attached to the wrong line reads as carelessness:

```bash
git show <head-sha>:<path> | sed -n '<line>p'
```

Use `side: "RIGHT"` for the head version. Use `"LEFT"` only to point at a line the PR
deletes.

### 2. Build the payload

JSON with a top-level `body`, an `event`, and a `comments` array of
`{path, line, side, body}`. Write it to a file — multi-line bodies in shell arguments
are a reliable source of escaping pain.

```bash
python3 -c "import json; json.load(open('/tmp/pr<N>_review.json')); print('valid')"
gh api -X POST repos/<owner>/<repo>/pulls/<N>/reviews --input /tmp/pr<N>_review.json
```

Validate the JSON before posting; a malformed payload wastes a round trip and can
partially apply.

**Choosing `event`:**
- `"COMMENT"` — the default for a courtesy or second-opinion review.
- `"REQUEST_CHANGES"` — only when the user explicitly wants the review to block merge.
- `"APPROVE"` — never. Approving someone else's PR on their behalf isn't yours to
  give; if the user wants it approved, tell them it's their click and why.

An empty `comments` array with `event: "COMMENT"` is just a summary review, which is
the right shape when every finding was architectural or repo-wide.

### 3. Verify and report

```bash
gh api "repos/<owner>/<repo>/pulls/<N>/comments?per_page=100" \
  --jq '.[] | select(.pull_request_review_id==<REVIEW_ID>) | .path + ":" + (.line|tostring)'
```

Confirm the count matches what you intended and report the review URL. If the API
rejects a comment with `line must be part of the diff`, the anchor wasn't in a hunk —
re-anchor to a changed line and resubmit rather than dropping the finding.

## Fallback: plain PR comment

Only when a finding attaches to no changed line at all (a repo-wide convention, a
missing file), or the user explicitly asked for one summary comment:

```bash
gh pr comment <N> --repo <owner>/<repo> --body-file <file>
```

Report the resulting URL. If the user says no, or doesn't respond, don't post — that's
a fine outcome, not a failure state.

## Checking whether comments were addressed later

When asked to check on a review you filed:

```bash
# new commits since the reviewed SHA
git log <reviewed-sha>..pr-<N> --oneline

# replies in your threads
gh api "repos/<owner>/<repo>/pulls/<N>/comments?per_page=100" \
  --jq '.[] | select(.in_reply_to_id != null) | .user.login + " | " + .path + " | " + (.body[0:200]|gsub("\n";" "))'
```

Beware two traps. First, if the branch was rebased, the commit SHAs the author cites
in replies won't exist any more — match on commit *message* instead of hash. Second,
a reply saying "Fixed in abc123" is a claim, not evidence; verify it per
`finding_verification.md`'s closing section before reporting anything as resolved.
