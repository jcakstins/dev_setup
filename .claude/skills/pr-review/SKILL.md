---
name: pr-review
description: Run a comprehensive, multi-reviewer code review of a GitHub pull request, then empirically verify every proposed comment before it is offered — running the repo's tests, writing throwaway reproductions, and dropping anything that cannot be shown to be a real problem, so the review never ships confident-sounding findings that turn out to be wrong. Grounded in concrete data-handling failure modes (races, blind writes, unscoped reads, stranded effects, PII in logs), the target repo's own conventions (migrations, layering, test tiers), and a security scan that blocks on any newly-introduced suppression of a fixable CVE. Asks two questions upfront, every run: a maturity lens (PoC / MVP / Scale-ready) that decides how much hardening the product warrants right now and whether a concern is a fix request or an observation, and separately how strictly to apply HTTP/API design standards (lenient by default) — they are different axes and usually get different answers. Calibrates against current scale rather than hypothetical load, so it distinguishes "this breaks today" from "this breaks at a thousand tenants" instead of presenting both as urgent. Every finding must pass two independent gates before it is offered: proven by executing a code path (unprovable-by-nature claims are labelled as inference, anything else that cannot be executed is dropped), and material — a named "does this actually matter, or can we let it slide" verdict, because a true finding nobody would care about costs more attention than it is worth. Reviewers read outside the repo to settle questions themselves (installed dependency source, lockfiles, sibling checkouts, remote code search) rather than hedging a finding on a contract they did not look at, and only ask about things code cannot answer: runtime config, third-party behaviour, another team's intent. Posted comments are kept to three to five sentences each; evidence and methodology go to the requester, not into the PR thread. Use this whenever the user gives you a GitHub PR URL or number and asks for a review, a second opinion, a "PoC review" or "go easy on this" style review, wants a PR checked before merge, or asks whether earlier review comments were actually addressed — not just when they say "use pr-review" by name. Works on any repo with git + gh access; reads the repo's own conventions fresh each run rather than assuming any layout, and never switches the user's checkout (uses throwaway git worktrees). Ends by presenting verified findings as inline review comments anchored to the file:line each concerns, alongside what it credited as correct and what it retracted, and asking whether to post; never posts automatically.
---

# PR Review

## What this is for

A thorough PR review that goes beyond "does the diff look reasonable": it grounds
findings in concrete failure modes (races, blind writes, unscoped reads, silent
duplicate effects, credentials in logs) rather than style opinions, checks
migrations and test placement against the repo's own documented conventions, and
treats an existing automated bot review as something to independently verify
rather than either trust or ignore. It runs several reviewers in parallel and
synthesizes their findings into one report with no reviewer attribution — the user
only cares about the issues, not who found them.

**The thing that makes this skill worth its cost is Step 7: nothing gets offered
to the user until it has been verified by execution.** A deep-reading reviewer
produces findings that *sound* right — plausible races, plausible leaks, plausible
missing tests — at a rate far higher than it produces findings that *are* right.
Posting those unverified is worse than not reviewing at all: it burns the author's
time on non-issues and, once they discover one confident claim was wrong, it
poisons their trust in the findings that were correct. So every proposed comment
gets attacked before it ships, and a review that drops half its own findings is
doing its job, not failing.

The other half of that is stance. This review has no authority behind it and
should never borrow any. It is one engineer's read, offered to another engineer who
knows the codebase better, and it earns agreement by showing evidence rather than
by asserting standards — see Step 4, rule 1.

It handles PoC, MVP and scale-ready work with the same rigor and the same reviewers
— see Step 2. The maturity lens never changes what counts as a bug; it changes how a
real-but-not-urgent finding gets handled once found: fixed now, deferred behind a
tracked marker comment, raised as an observation with its trigger named, or dropped.
The lens matters most for hardening that cannot be *sized* without usage data, which
is premature to demand of a product still learning how it behaves in the wild.

This is expensive and slow: three deep-reading subagents that run tests and write
reproductions, then a scoped adversarial pass over what they found. Expect tens of
minutes on a substantial PR. Only run it when the user actually wants this depth — if
they want a quick read, say so and offer the shallower option instead.

**Where the time goes, and what may be cut.** The four things that make a run drag are
all avoidable: every agent independently re-running the repo's gates and full test suite
(fixed by Step 5 — run them once centrally and hand over the output), agents sharing one
worktree and corrupting each other's experiments (fixed by Step 0 — one worktree each,
created and installed up front, in parallel), two or three reviewers each independently
proving the *same* already-known bug from scratch because the existing bot/human review
wasn't split between them (fixed by Step 1 — tag each pre-flagged item to exactly one
reviewer's lane before dispatch), and the verification pass re-proving claims that were
already contested, unproven, or environment-mismatched (fixed by Step 7 — a claim's
proof needs a *nameable* weakness to earn a re-check; heading for a blocking comment is
not by itself that weakness).

**What must never be cut for speed is the empirical grounding.** The scratch scripts under
`/tmp`, the deliberate source mutations to show a test suite stays green, the real database
engine when a claim depends on it — that is the entire reason this skill produces findings
an author can trust instead of plausible narration. Speed comes from not duplicating work
and not proving things twice, never from believing a finding because it sounds right. The
cleanup afterwards is part of the same discipline: revert every mutation, delete every
scratch file and worktree, and confirm it.

This skill is portable across repos and must not assume any repo-specific setup —
every convention it checks against (layering, migrations, test tiers) is read
fresh from whatever the target repo documents about itself, not hardcoded from any
one codebase this skill has been run against before.

## Step 0 — Resolve the target and protect the user's checkout

Parse whatever the user gave you into `owner/repo` and PR number `N`. Accept a full
URL, `owner/repo#123`, or a bare number (infer owner/repo from the current
directory's `git remote` / `gh repo view --json nameWithOwner`).

Confirm the local checkout is the right repo (`git remote -v` or `gh repo view`).
If it's a different repo than the PR belongs to, tell the user rather than
guessing.

**Never switch the user's working tree to the PR branch.** They are mid-task on
their own branch, quite possibly with uncommitted work, and a review is a read-only
errand that has no business changing what they have checked out. Use a throwaway
worktree instead, which gives you the PR's files at a separate path and leaves
their checkout untouched:

```bash
git fetch origin pull/<N>/head:pr-<N>          # local ref, doesn't touch remote
git worktree add /tmp/pr<N>-wt pr-<N> --detach # PR files, isolated from the user's tree
# ... review ...
git worktree remove /tmp/pr<N>-wt --force      # always clean up, even on failure
```

Record `git branch --show-current` and `git status --porcelain` at the start anyway,
so you can state plainly at the end that the checkout is untouched — that
reassurance is worth one line, because handing someone's repo back is exactly the
kind of thing they shouldn't have to verify themselves.

**Give every agent its own worktree, and create them all up front.** Reviewers and
verifiers mutate source to prove things (deleting a guard and re-running the suite is the
core technique), so a shared tree means they corrupt each other's experiments. On the run
this guidance came from, one reviewer reported seeing uncommitted edits and untracked test
files it had not made, which makes every result from that point suspect and forces re-runs.
Budget one worktree per parallel agent plus one for yourself:

```bash
for i in 1 2 3 4; do git worktree add /tmp/pr<N>-wt$i pr-<N> --detach; done
```

Then **install dependencies in all of them concurrently, in the background, before you
need them.** This is pure dead time if you leave it until dispatch, and it is minutes per
tree. Discover the working install command once first (Step 5) so you are not debugging it
four times in parallel.

Clean up every worktree at the end, including on failure:

```bash
for i in 1 2 3 4; do git worktree remove /tmp/pr<N>-wt$i --force; done
git worktree prune
```

## Step 1 — Gather PR context

```bash
gh pr view <N> --repo <owner>/<repo> --json title,body,baseRefName,headRefName,url,commits
git fetch origin <base>                      # update the base ref locally
git fetch origin pull/<N>/head:pr-<N>         # fetch the PR as a local ref, doesn't touch remote
git log origin/<base>..pr-<N> --oneline       # sanity-check: should be just this PR's own commits
git diff --stat origin/<base>..pr-<N>
git diff origin/<base>..pr-<N> > /tmp/pr<N>.diff
```

If `git log origin/<base>..pr-<N>` shows commits that look like they belong to
*other*, already-merged PRs (this happens when your local `origin/<base>` is
stale), re-run `git fetch origin <base>` and recheck — don't hand reviewers a diff
that's polluted with unrelated already-merged history.

Write a `/tmp/pr<N>_context.md` with the title, body, base/head SHAs, and the repo
path — this is what you hand to every reviewer agent so they don't each have to
re-derive it.

**Fetch existing review signal on the PR** — this matters because the synthesis
step must independently verify it, not just repeat it:

```bash
gh pr view <N> --repo <owner>/<repo> --json comments --jq '.comments[] | .author.login + "\n" + .body + "\n=====\n"'
gh pr view <N> --repo <owner>/<repo> --json reviews --jq '.reviews[] | .author.login + "|" + .state'
gh api repos/<owner>/<repo>/pulls/<N>/comments --jq '.[] | .user.login + "|" + .path + "|" + (.line|tostring) + "|" + .body'
```

If there's an automated review bot comment (e.g. an "AI Review Signal" style
comment, or any other bot/CI review), save its blockers and suggestions verbatim
to `/tmp/pr<N>_bot_review.md` with a note: *"independently verify each of these
against the actual code — agree, disagree, or refine with your own reasoning;
don't just repeat them, and the final output must not say 'the bot said X' — state
it as your own finding."*

**Assign each pre-flagged item to exactly one reviewer's lane before dispatch.**
Read each bot/human item and tag it A (data-handling/correctness), B
(adversarial/security/design), or C (API standards/conventions/tests) by what it's
actually about — a lost-update claim is A, a PII-in-logs claim is B, a missing-test
claim is C. Write the tags into `/tmp/pr<N>_bot_review.md` next to each item. This
exists because handing the full list to all three reviewers with "go verify these"
makes every reviewer treat every item as fair game: on one run, two reviewers each
built a full execution harness and independently proved the *same two*
already-named bugs from scratch, paying the proof cost twice for zero new
information. One reviewer per pre-flagged item, full stop — the other two get the
file for situational awareness only, not as a worklist.

## Step 2 — Choose the maturity lens and the API-standards axis

Ask the user **both** questions together, before grounding or dispatching reviewers.
Never infer either from how the request was phrased, and ask fresh every run — a prior
run's answers don't carry forward. **Ask question 2 every time, even when the PR looks
like it touches no HTTP surface.** An earlier version of this skill skipped it whenever
it judged the diff to be HTTP-free, and the result was that users who expected to be
asked simply never were, and had no way to tell whether the axis had been considered or
silently dropped. If the PR genuinely touches no endpoint, that is a one-line finding in
the output, not a reason to withhold the question.

These are two axes rather than one because the answers usually differ, and collapsing
them forces a compromise that misrepresents what the user wants. Maturity is about how
much hardening the product warrants *right now*. API standards are about the external
shape of HTTP endpoints, where a repo has usually already settled its own conventions and
demanding conformance means asking this PR to be inconsistent with every endpoint around
it. Blending them reliably produces the wrong behaviour on one axis: either nagging about
response envelopes, or waving through a blind write.

### Question 1 — Maturity lens

This sets how hard to press on data-handling conformance (compare-and-swap vs. blind
write, one-transaction units of work, effect ordering, idempotency, tenant scoping,
bounded reads, stable pagination, typed errors, leak-free logging) **and** how liberally a
real-but-deferrable finding gets deferred instead of fixed now. If the repo documents
these principles itself (commonly a docs or engineering-standards directory, see Step 3),
that document is the bar.

- **PoC / spike (very lenient)** — explicitly interim, throwaway or demo work. Only
  correctness, security and data-integrity bugs are raised at full strength. Real-but-
  deferrable concerns become a tracked in-code marker rather than a fix, so the deferral
  survives in the place that gets read again instead of in a PR thread that scrolls away.
- **MVP (pragmatic — often the right answer)** — the product is heading for a pilot or
  early release, and the goal is to get it in front of users and learn how it actually
  behaves. Hardening that cannot be *sized* without usage data is premature here: you
  cannot pick a retry budget, a cache TTL, or a dedup window sensibly before you know the
  failure rate. Raise what breaks today at today's volume; note what will break at scale
  without demanding it now. Do not ask for hyper-optimisation.
- **Scale-ready (strict)** — this is expected to carry real load or many tenants. Flag
  conformance gaps against the principles even where the repo already has precedent for
  doing it the other way, and expect them addressed.

**The lens never changes what reviewers look for or how hard they look.** Every reviewer
in Step 6 runs identically at all three settings, and a genuine correctness, security or
data-integrity bug is never softened by picking PoC or MVP. What changes is only what
happens to a finding *after* it has been found and verified — see
`references/posting_triage.md`, which has a bucket table per lens.

### Question 2 — API-standards adherence

How hard to press on the external HTTP contract shape: URL structure, verbs, status
codes, response envelopes, error format, pagination, versioning. The target shape is in
`references/api_design_standards.md`, a generic distillation of common REST API design
conventions — swap it for your own org's standard if one exists.

- **Lenient (recommended, and the usual answer)** — do not expect strict conformance. The
  repo very likely already diverges, and forcing this PR to conform would make the new
  endpoints inconsistent with every sibling endpoint, which is a worse outcome than the
  divergence. Raise only **quick wins**: small, local changes that reduce future tech debt
  *and* do not create inconsistency with the surrounding code. A missing `traceId` on a
  new error path is a quick win. Renaming an existing resource route to match the target
  URL shape is not.
- **Strict** — flag conformance gaps against the target shape regardless of existing repo
  patterns, and expect them addressed.

### What both answers do and do not govern

Both answers govern **conformance gaps only, never bugs**. A race condition, data-
corruption risk, duplicate un-undoable side effect, PII leak or other correctness or
safety finding is reported at full strength at every setting. If the user picks the most
lenient option on both axes, that does not buy silence on a real defect — it buys silence
on style, and it buys patience on hardening that cannot yet be sized.

Carry both answers verbatim into every reviewer prompt in Step 6, and restate them in the
final output so the user can see the review was calibrated to what they actually asked
for.

## Step 3 — Ground the review

Reference files that ship with this skill:

- `references/data_handling_principles.md` — concrete failure modes for code that
  mutates state or reads/serves data (blind writes vs. compare-and-swap, split
  transactions, missing idempotency, ownership/tenant scoping, unbounded/unscoped
  reads, unstable pagination, silent staleness, PII in logs). Use this to judge
  write-path and read-path correctness in plain, concrete terms.
- `references/api_design_standards.md` — the target shape for HTTP APIs (URL
  structure, verbs, response envelopes, error format, pagination, versioning).
  This describes a *direction*, not the current state of any particular target
  repo.
- `references/coupling_and_responsibility_growth.md` — how to triage coupling and
  responsibility-growth findings without treating all coupling as a problem.
- `references/illegal_states_check.md` — the standalone check for over-defensive
  code that should instead make illegal states structurally impossible. Read this
  before Step 6; it's dispatched to Reviewer B as required reading, not optional
  background.
- `references/posting_triage.md` — the primary grounding for Step 9: how a
  finding's severity plus the Step 2 maturity lens decide whether it's fixed now, deferred
  behind a marker, or dropped. Read this fully before Step 9, not just skimmed
  here.
- `references/security_review_policy.md` — how to run and interpret the security
  scan in Step 5.

- `references/comment_style.md` — how to actually write anything that gets posted:
  attaching a consequence to every fact, collaborative rather than authoritative
  register, what to leave out, length, and the layer rule that config must never be
  asked to hold an invariant. Read this before drafting comments in Step 10; a correct
  finding written badly gets dismissed, and a dismissed finding costs more than none.

- `references/finding_verification.md` — how to run Step 7, the stage that decides
  which findings actually survive. Read this before Step 7; it is the most
  load-bearing reference in the skill.

Reference files carrying a refresh note at the top can be re-fetched from their
source if missing or stale, per the note; otherwise the cached copy is fine.

**Read the target repo's own conventions and principles docs, and prefer them over
this skill's cached copies.** Look for a docs/standards directory, `CLAUDE.md`,
`AGENTS.md`, `CONTRIBUTING.md`, or similar. Read them fresh every run, never
cached — they're the source of the repo's actual layering, testing, and migration
rules, and they differ meaningfully between repos.

Where a repo ships its own data-handling principles doc (whatever it's called —
e.g. a `data-handling-principles.md` in a docs/standards directory), **that file is
the bar, not `references/data_handling_principles.md`.** The bundled copy is a
portable fallback for repos that document nothing; the repo's own version is what
its engineers agreed to and will recognise, it may be more specific or have diverged,
and reviewing against a stale external copy while the repo has its own is how a
review starts sounding like it's importing rules from somewhere else. If both exist,
read both and let the repo's win on any conflict.

If no such file exists anywhere, proceed without one — don't block on it or ask the
user to supply one; this skill must work on repos with no documented conventions at
all, using the bundled references purely as a way to sharpen judgment about what
breaks.

## Step 4 — Ground rules (read these before writing any reviewer prompt)

These are the constraints that keep the review useful and keep it from turning
into either a compliance checklist or an uncritical bot echo:

1. **Argue from consequences, not from authority.** This is the rule that most
   determines whether the review lands, so it gets the most space.

   The reference files and principles docs exist to sharpen judgment about what
   actually breaks — they are not authorities to invoke. Never write "this violates
   the Data Handling Principles", "per the API Design Standards", or any internal
   doc, page, or standard name, in output shown to the user or posted to the PR.
   Two reasons, and the second matters more than the first. The first is that a
   reader who doesn't accept that document as binding now has to argue about the
   document instead of the code. The second is what citing it implies socially: it
   frames the comment as *"change this because I have decided this source governs
   you"*, which puts the author in the position of either submitting or
   relitigating org policy in a PR thread. Neither is a good use of their day, and
   both make an otherwise correct finding easy to resent.

   State instead: what the code does, the specific condition under which that
   produces a wrong outcome, what the wrong outcome is, and the cheapest fix. A
   finding phrased that way needs no authority — it either reproduces or it
   doesn't, and the author can check. If you find yourself reaching for a document
   name to justify a comment, that is a strong signal you don't actually have a
   consequence to point at, which means the finding belongs in the DROP bucket.

   The same applies to the *voice* of the review. Concretely:
   - Prefer "this returns X when Y, which means Z" over "this is wrong."
   - Prefer "I couldn't determine how this is consumed — if it's inlined, this is
     moot" over asserting the failure mode as fact.
   - Ask rather than instruct where the answer is genuinely the author's call
     (product decisions, deliberate deferrals, anything they've already documented
     as intentional). "Is this meant to apply to non-MIS agents?" respects that
     they may have a reason; "this should be gated" presumes they don't.
   - Say what would change your mind. A finding that names its own falsifier reads
     as an engineer thinking, not a checklist asserting.
   - Where the author already documented a decision you're questioning, acknowledge
     that first and explain what new information you're adding. If you have none,
     don't raise it.
   - Credit what's genuinely good, specifically and with the same evidence
     standard. This is not politeness padding — it's the thing that makes the
     critical findings credible, because it demonstrates you actually read the code
     rather than pattern-matched it for faults.

2. **Apply the two Step 2 axes independently.** The maturity lens and the
   API-standards answer are separate; don't let one bleed into the other. A user on
   MVP who answered Strict on API standards means exactly that, and so does the
   reverse. For API standards, only raise a finding if this PR actually adds or
   changes an HTTP endpoint, route, or request/response shape — if it touches no
   HTTP surface (common for background-worker, internal-service, or pure-schema
   PRs), say that plainly in one line and don't force a finding. Note that saying
   so is *required*: the user was asked the question, so they're owed the answer.
   Under **Lenient**, raise only quick wins that reduce future tech debt without
   creating inconsistency with how the rest of the repo already does the same kind
   of thing; where the standard and the local convention conflict, the local
   convention wins. Under **Strict**, raise every conformance gap against the target
   shape regardless of existing repo patterns.

2a. **Separate "breaks now" from "breaks at scale", and say which.** This is the
   single most common way a correct finding gets dismissed. A concurrency,
   throughput or unbounded-growth finding must state whether it fires at the
   product's *current* volume and concurrency, or only at anticipated scale. Both
   are legitimate, but they are different claims and get posted differently: "this
   happens today" is a fix request, "this breaks at N tenants" is an observation
   with the trigger named. Conflating them invites a completely fair "that's
   premature optimisation" reply that also buries the findings which do fire today.
   Under the **MVP** lens, be especially honest here — hardening that can't be sized
   without usage data is not yet actionable, and saying so earns credibility for the
   findings that are.

3. **Check the repo's own migration conventions in detail, if it has any** —
   Liquibase or similar. Filename numbering strictly increasing and never
   reordered/edited after merge, preconditions that define failure behavior for
   drift safety, a rollback provided, and — the one people usually skip — whether
   a destructive migration's rollback quietly implies data restoration it can't
   actually deliver. If the destructiveness and its irreversibility aren't
   documented anywhere, that's a real, easy-to-fix finding. If the repo has no
   migration tooling at all, say so and skip this category — don't force it.

4. **Check test-tier coverage against what this repo actually has**, not against
   an abstract ideal. First establish which test tiers exist (unit, acceptance/
   real-HTTP, integration/db_integration against the real engine) from Step 3's
   repo-conventions read and the test directory layout; never ask a repo without
   an acceptance or integration tier to add one from scratch.
   - **Locking/concurrency code** is the flagship case: if the repo has a heavier
     integration tier for the real DB engine specifically because a lighter
     dialect used in unit tests makes a locking clause a no-op, check whether
     *this* PR's new locking-sensitive code got equivalent coverage there, not
     just a same-dialect-as-before unit test.
   - **Other db_integration-worthy behavior** — constraint enforcement, cascade
     behavior, a migration-driven schema assumption — gets the same reasoning
     under a different trigger.
   - **Acceptance/HTTP-contract behavior** — if the repo's own conventions require
     a real-HTTP acceptance test per endpoint, check the new/changed endpoint got
     one exercising its actual contract.
   - **The composition seam itself** — when a PR wires several new pieces
     together (a client, a settings object, a connection-context builder), check
     whether anything actually exercises the *assembled* path end to end, not just
     each new function in isolation. A future change that silently drops one
     argument from the wiring can leave every existing per-function unit test
     green while the assembled behavior breaks.
   Naming the exact missing scenario (seed state/request, expected outcome) is far
   more useful than "add more tests."

5. **Every test-coverage suggestion must target a genuine gap in observable
   behavior, never implementation mechanics.** A test protects behavior that
   something outside the unit depends on — a public API response, a documented
   contract, a persisted side effect, an emitted event — not the internal steps
   the code happens to take to get there. Never request a test for a private
   helper or an internal call sequence, and never suggest one just to raise a
   coverage number. Name the concrete scenario and the realistic regression it
   would catch, or don't report it (see `references/posting_triage.md` — this
   category is DROP by default in both modes).

6. **Look hard for design-quality smells, not just bugs**: duplicate validation or
   business logic spread across layers that should live in one place;
   one-caller abstractions invented to solve a purely local problem; code that
   reasons correctly for the one call site being changed while silently assuming
   something about global or caller state that isn't actually guaranteed anywhere;
   unnecessary coupling and responsibility growth (full policy in
   `references/coupling_and_responsibility_growth.md` — raise it only when a
   component takes on unrelated responsibilities, crosses a layer boundary with
   implementation details, or an existing class becomes a general-purpose
   coordinator, never on size or dependency count alone).

7. **Over-defensive code and illegal states get a dedicated pass, every review,
   in both modes** — this is important enough to call out on its own rather than
   as one bullet among design smells. Full reasoning and examples in
   `references/illegal_states_check.md`; the short version: for every re-checked
   condition, re-derived boolean, or `None`/empty-string standing in for more than
   one meaning, explicitly judge whether it's protecting a state that's actually
   reachable (keep it) or guarding against something already unreachable given
   earlier guarantees (name the concrete structural fix — a closed union, a
   non-optional field, a decision computed once and threaded through — not just
   "add a comment"). Feed the verdict into Step 9 like any other finding: a live
   reachable bad state is FIX NOW; an inert-but-reasonable pattern is DROP or
   DEFER-WITH-MARKER, never FIX NOW.

8. **Verify the existing bot review, don't parrot it — and only the items tagged
   to your lane.** Each pre-flagged item was tagged A/B/C in Step 1 to the one
   reviewer who owns that kind of claim; verify only yours by reading the actual
   code and reaching your own verdict — confirm it, refine it with detail the bot
   couldn't see, or explain concretely why it's actually a non-issue. Never write
   "the bot flagged..." in final output — fold the verdict in as your own finding.
   If you notice an item tagged to someone else and have a strong independent
   reaction, say so in one line rather than building a second full proof — the
   owning reviewer's verdict is what synthesis uses.

9. **Never let a PR introduce a new, silent way to hide a fixable CVE.** Full
   policy in `references/security_review_policy.md`. In short: pre-existing
   suppressions are accepted debt and out of scope; any suppression this PR newly
   adds is in scope, and if the suppressed CVE has an available fix, that's always
   a FIX NOW finding naming the exact fixed version, never resolved by keeping the
   suppression.

10. **Every finding must separate what was observed from what was inferred, and
    say which.** Require each reviewer to mark each finding as either *traced*
    (they read the actual code path end to end and can name the lines) or
    *inferred* (it follows from what they read but a step is assumed). This is not
    bureaucratic bookkeeping — it's the input Step 7 needs to know what to attack
    first, and inferred findings are where the wrong ones concentrate. A reviewer
    that marks everything "traced" is not being careful; push back on that.

    Related, and worth stating explicitly because reviewers get this wrong in a
    predictable direction: **reachability is part of the finding, not a footnote.**
    A bad code path that nothing can currently reach is a different (and usually
    much smaller) claim than one a user can trigger. Require each reviewer to say
    how the condition is reached, and to flag when it can't be.

11. **When a finding depends on code outside the repo, go and read that code. Only
    ask the user when you genuinely cannot.** This rule exists because it is the
    largest single source of wrong findings in practice, and it is almost entirely
    avoidable.

    Modern services get much of their behaviour from things that are not in the repo
    being reviewed: tool schemas served by an MCP server, a downstream API contract,
    a shared library, a sibling repo in the same stack. A reviewer that only reads
    the repo in front of it will find a "missing" contract that is in fact declared
    somewhere it cannot see, and will write that up with total confidence.

    **Reviewers are expected to go and look, not to hedge.** Almost everything that
    feels external is actually readable from where you are sitting:

    - **The installed dependency itself.** `.venv/lib/python*/site-packages/<pkg>/`,
      `node_modules/<pkg>/`, or whatever the language's equivalent is. This is the
      exact code that runs, which makes it better evidence than any doc. Read the
      class, grep the package for the symbol, and import it in a scratch script to
      see what it actually does.
    - **The pinned version, and whether a newer one exists.** `uv.lock`,
      `package-lock.json`, `go.sum`. A finding of the form "this field does not
      exist" is much stronger when you can also say the latest release does not have
      it either.
    - **A sibling repo checked out locally.** Look for it next to the repo under
      review (`~/github/<org>.<name>`, `../`, a monorepo sibling directory). Grep it.
    - **The remote, via the host CLI.** `gh api`, `gh search code`, `gh release list`
      against the org. A code search returning zero hits across the default branch
      is real evidence.

    Doing this changes findings qualitatively, not marginally. In one run the claim
    "this JWT claim never arrives" started as an inference about the repo under
    review. Reading the installed library turned it into something much sharper: the
    payload model does carry the claim, and a projection function drops it, so the
    upstream team shipping the claim is *not sufficient* and a dependency release is
    a prerequisite nobody had tracked. Same suspicion, completely different comment,
    and the difference was five minutes of grep.

    So: **never write "this should be verified against service X's contract", "the
    schema may declare this", or "assuming the downstream doesn't handle it".** A
    finding hedged that way is not a finding, it's a research task handed to the
    author.

    What is left after looking is usually not code at all — it is a runtime fact, a
    third-party behaviour, or someone's intent: whether at-rest encryption is enabled
    on a particular cluster, whether an identity provider invalidates a token on
    rotation, whether another team will emit an empty string or omit a field, what a
    deploy pipeline actually runs. Those go in an explicit **CONTEXT NEEDED** list
    naming what is needed and what the answer would change. Collect them, put them to
    the user in one batch, and resolve them before anything is posted. An empty list
    is a good outcome and should be stated as such.

    Where the answer stays unknown, do not drop the finding and do not post it with a
    caveat — state the dependency inside it as a condition ("if rotation invalidates
    the predecessor, this also leaves a dead credential"), so the author can resolve
    it in one step from knowledge they already have.

12. **Verification is part of the review, not a stage after it. A finding that has
    not been proven by executing a code path does not exist.** Detail in
    `references/finding_verification.md`. Finding and proving are two different jobs
    and reviewers routinely stop after the first, because a plausible narrative feels
    finished. It is not finished.

    Every reviewer proves each of its own findings before reporting it — runs the
    repo's tests, writes a throwaway reproduction under `/tmp`, mutates the source and
    shows the suite still passes, imports the real class and calls it, prints the
    assembled artefact. It reports the command and the real output. **Anything it
    could not substantiate by execution, it drops.** Not softens, not flags as
    low-confidence: drops.

    Two carve-outs, and they are narrow:

    - **Genuinely unexecutable claims.** Some real risks cannot be driven from a dev
      machine: a runtime configuration, a third-party provider's behaviour, a
      multi-instance deploy, a browser. These may be reported, but must be labelled
      as inference with the reason, and must say what *was* established by execution.
      "I could not run this" is an acceptable sentence; presenting reasoning in the
      register of evidence is not.
    - **Things settled by reading, where reading is conclusive.** A missing
      attribute, a version pin, a case-sensitive comparison, whether a function has
      callers (grep is proof). Do not build a harness for these. The test is whether
      a skeptic could disagree with your reading; if they could, execute it.

    The single highest-yield technique, worth naming here because reviewers skip it:
    **to prove "nothing tests this", delete the thing and run the suite.** A green
    suite after removing a guard is a fact nobody can argue with. A red one refutes
    the claim, which is equally useful. Revert afterwards and confirm the tree is
    clean.

    This does not replace Step 7, which attacks the survivors adversarially with
    fresh agents. It exists so that Step 7 spends its budget on claims that already
    have evidence behind them, instead of on the weakest third of the list.

13. **The materiality gate: after proving a finding, ask whether it matters. If the
    honest answer is "not much", let it slide.** This is a second, independent filter
    and it runs *after* rule 12. Rule 12 asks "is this true?". This one asks **"so
    what?"**, and a finding has to pass both.

    A proven finding is not automatically worth reporting. Verification tells you the
    code does something wrong; it says nothing about whether anyone will ever care.
    Reviewers systematically overweight truth here, because proving something felt
    like work and discarding it feels like waste. It is not waste — the discard is the
    product. **We are not aiming for perfection. We are aiming for the problems that
    would actually hurt.**

    Ask, in this order:

    1. **What breaks, for whom?** Name the person or system harmed and how they
       notice. If the answer is "a future reader might find it confusing" or "it
       diverges from the pattern next door", it fails. If it is "a user's credential
       is silently lost", it passes.
    2. **Can it be reached?** By whom, doing what? A defect on a path with no caller
       is a smaller claim than one a user can trigger, and often a much smaller one.
       Reachability is part of the finding, not a footnote (see rule 10).
    3. **Is the wrong outcome silent?** A loud failure is largely self-solving: the
       next person hits it, sees the exact error, and fixes it. Silent wrongness is
       what review is for. A `TypeError` naming the exact missing argument is not a
       finding. A lost write that reports success is.
    4. **What does it cost to leave it?** Weigh that against the cost of the fix and
       the cost of the author's attention. A one-line fix to a real-but-minor problem
       can still be worth raising; a large refactor for a theoretical one never is.

    Then say the verdict out loud, per finding, in your report: **matters** or **let
    it slide**, with the reason. Forcing the sentence is what stops the gate being
    skipped.

    Worked examples from real runs, all of them *proven true* and correctly let slide:

    - A stub missing a keyword argument that the protocol declares. True. Nothing
      calls it, and the failure mode is a `TypeError` naming the exact keyword. Let it
      slide.
    - A destructive migration rollback with no warning comment. True, and the data is
      genuinely unrecoverable. But rollback is a deliberate operator action, two prior
      table-creating migrations in the same repo do the same thing, and the repo's own
      policy is fix-forward. Let it slide.
    - An error-message substring match driving a retry, which recursed infinitely.
      True — on SQLite. Production is MySQL, where the branch is never reached.
      Real, but it only bites the test tier. Folded into another thread as one
      sentence rather than raised as a finding.
    - A duplicate revoke raising "invalid transition" instead of being idempotent.
      True. But the transition table declares that state terminal, so the author chose
      it, and no consumer exists yet to have an opinion. Let it slide.

    And two that passed the gate despite looking small:

    - A one-line timezone bug in a function with no callers. Passed: the stored value
      is silently wrong rather than loudly wrong, every other site in the repo already
      does it correctly, and the fix is one method call.
    - A test that passes when the behaviour it is named for is deleted entirely.
      Passed: it is the test the PR description points at as its security guarantee,
      so it will be trusted later without being re-read. False assurance is worse than
      no assurance.

    **What the gate must never soften.** It filters conformance gaps, tidiness, and
    small divergences. It does not filter a data-corruption risk, a credential leak, a
    duplicate un-undoable external effect, or a security hole — those are reported at
    full strength however inconvenient the fix (see `references/posting_triage.md`).
    And it is not a licence to skip the *looking*: the principles in rule 6, rule 7 and
    the repo's data-handling document tell you **where to look** and what failure modes
    to hunt. The gate only decides what survives the hunt. Searching less hard is not
    pragmatism, it is just a worse review.

## Step 5 — Run everything deterministic once, centrally

This step exists as much for speed as for correctness. Every reviewer needs the same
baseline facts, and if you don't give them, each one independently runs the linter, the
type checker and the full test suite. That happened on the run this guidance came from:
three agents ran the same five gates and the same 1800-test suite, tripling the wall
clock for identical output. **Run it once, save it, hand it over as data.**

Produce `/tmp/pr<N>_baseline.md` containing:

- **The dependency install command that actually works**, discovered once. Do not trust
  the documented one; project docs drift (in one run `CLAUDE.md` documented an extra that
  no longer existed in `pyproject.toml`, and every agent would have hit the same error).
  Run it, confirm it exits clean, and put the exact working command in the file.
- **A baseline test run**: the full suite at head, with the result. This matters more than
  it looks, because it identifies **pre-existing failures**. Without it, agents waste time
  investigating a red test that was already red, or worse, attribute it to the PR. Name
  any pre-existing failure explicitly and tell them to discount it.
- **Every gate the repo defines**, run exactly as its own CI would: linter, formatter,
  type checker, complexity, import/layer contracts. Record the real output.
- **Coverage for the files the PR touches**, if the repo has a coverage tool. Cheap, and
  it answers "is this path tested" for free rather than each agent deriving it.

Then the security scan, per `references/security_review_policy.md`: prefer whatever
SAST/dependency tooling the repo already wires into its own pre-commit/CI; fall back to
the Snyk CLI (`snyk code test`, `snyk test`) if installed and authenticated and the repo
has none of its own. Save that plus a diff of any security-relevant config/suppression
changes between base and head (policy files, new suppression comments, ignore flags added
to CI/pre-commit, dependency pins or downgrades) to `/tmp/pr<N>_security.md`. Hand the
security file to Reviewer B and the baseline file to all three.

Tell reviewers plainly: **these have already been run, do not run them again.** They may
re-run a *single targeted* test or gate when a mutation experiment needs it, which is
different and expected.

## Step 6 — Dispatch parallel reviewers

**All Agent calls must be in a single message so they run concurrently.** Use
`subagent_type: general-purpose` for each. Give every reviewer:

- the context file from Step 1 and the diff file path;
- the relevant reference file(s), **including the repo's own principles doc when it
  has one** (Step 3) rather than only the bundled copy;
- the bot/human-review file, with the "verify, don't repeat" instruction, **and
  the explicit list of which tagged items are this reviewer's to verify** (per
  Step 1's A/B/C tagging) — the other reviewers' tagged items are for situational
  awareness only, not theirs to re-prove;
- **both Step 2 answers, stated separately** — the maturity lens (PoC / MVP /
  Scale-ready) and the API-standards answer. The lens is context only: it must not
  change what they look for or how hard they look, it tells them how much hardening
  the product warrants right now so they don't spend effort arguing with that framing.
  The two axes are independent and must not be blended;
- the path to the PR worktree from Step 0, so they read full files there rather than
  reconstructing context from diff hunks. `git show <SHA>:<path>` also works;
- **a list of any sibling repos, service contracts or schema sources the user has
  already pointed at**, with paths. Reviewers cannot ask the user directly, so
  anything you already know must be handed to them up front, or they will infer it;
- **explicit permission and an expectation to read outside the repo**, per ground rule
  11: the installed dependency source under `.venv`/`node_modules`, the lockfile for
  the pinned version, sibling checkouts near the repo, and the host CLI (`gh api`,
  `gh search code`, `gh release list`) for the remote. Say it in the prompt, because a
  reviewer told only "review this diff" will treat the repo boundary as the edge of
  what is knowable and hedge instead of looking. Name the concrete move: *if a finding
  turns on whether a library declares a field, go read the library*;
- ground rules 1, 10, 11, 12 and 13 verbatim. Rules 1 and 10 govern how findings are
  worded and how confidence is reported. Rules 11, 12 and 13 are what stop unverified,
  externally-dependent and trivial findings reaching the user, and they are the three
  the panel most often skips because all three feel like extra work after the finding
  already "looks right". State plainly in the prompt that **a reviewer returning three
  findings that all matter has done a better job than one returning nine**, and that
  the count is not the deliverable.

Every reviewer's output format: findings tagged `SEVERITY: CRITICAL | IMPORTANT |
MINOR`, `FILE: path:line`, what the code does, the specific condition that makes that
wrong, the outcome, and the fix — plus per ground rule 10, whether the finding is
**traced** or **inferred**, and how the bad condition is actually reached. Never
attribute a finding to "reviewer X," a bot, or any named source, and never justify one
by naming a standard.

Three further requirements on every finding, all non-negotiable:

- **`PROOF:` the command they ran and the real output.** Per ground rule 12, a finding
  reported without an execution attempt is not finished work, and anything they could
  not substantiate by execution is dropped rather than downgraded. Where a claim
  genuinely cannot be executed against (it needs a browser, a live cloud service, a
  multi-instance deploy, a third party's behaviour), they say so explicitly and mark it
  unproven rather than quietly presenting reasoning as evidence.
- **`MATTERS:` the rule-13 verdict — "matters" or "let it slide", with the reason.**
  Require this as a named field, because a gate that is only implied gets skipped. A
  reviewer that marks every finding "matters" has not applied the gate; push back on
  that. Tell them explicitly that a "let it slide" verdict on something they worked
  hard to prove is a correct and valued outcome, and that they should report those in
  the CONSIDERED AND DROPPED section rather than quietly promoting them.
- **`SCALE:` does it fire at today's volume, or only at anticipated scale?** Per ground
  rule 2a. Required on anything touching concurrency, throughput or growth.

Also require, from each reviewer:

- **`CONTEXT NEEDED`** — anything they could not resolve *after* reading the installed
  dependencies, the lockfile, sibling checkouts and the remote. Rule 11 makes looking
  mandatory, so this list should contain only runtime facts, third-party behaviour and
  other teams' intent — never "what does this library declare", which they can answer
  themselves. Each entry names what is needed and what the answer would change. An empty
  list is a good answer and should be stated as such.
- **anything they checked and found genuinely correct**, and **anything they considered
  raising and decided not to**. Both stop the panel behaving as though only faults count
  as output, and the second is often where the best judgement shows.

When the `CONTEXT NEEDED` lists come back, batch them into a single question to the user
before Step 7. This is the cheapest step in the whole skill and it routinely kills the
most confident wrong findings.

**Reviewer A — data-handling correctness + plan alignment.** Does the
implementation match the PR's own stated design? Compare-and-swap vs. blind-write
on the mutation paths; ownership/tenant scoping in queries, not just app-code
checks; auditability of state changes; an independent verdict on each bot-flagged
item relevant to correctness. Migration correctness is Reviewer C's job, don't
duplicate it here.

**Reviewer B — adversarial + design quality + security.** Concurrency/races,
SQL/data safety, error handling (swallowed exceptions, partial writes), security
(trust boundaries, auth, PII/credentials in logs), edge cases, operational
visibility, plus the full design-quality smell list from ground rule 6 **and the
dedicated over-defensive/illegal-states pass from ground rule 7** — give this its
own explicit attention in the prompt, not a passing mention. Give this reviewer
`/tmp/pr<N>_security.md` from Step 5 and ground rule 9. This reviewer tends to
find the sharpest correctness bugs; give it room and full file context.

**Reviewer C — API standards + repo conventions + test placement.** First
determine plainly whether the PR touches any HTTP surface at all before
evaluating anything against the API standards reference, then apply the
**API-standards** answer from Step 2 — not the maturity lens; tell this reviewer
explicitly which is which, because conflating them is the most likely way this
reviewer goes wrong. Under Lenient it still owes the user a one-line verdict on
whether the PR touches HTTP surface at all. Check migrations against the repo's own documented
conventions (ground rule 3) — this reviewer owns migration correctness exclusively.
Own ground rule 4's full test-tier survey, including the composition-seam check. Every
finding here must meet ground rule 5's bar.

Also warn this reviewer about the diff-basis trap, because it produces spectacular
false positives: comparing the PR against the *tip* of the base branch with a two-dot
diff (`git diff base..pr`) shows commits merged into base but absent from the branch as
though the PR **deleted** them. Use three-dot (`git diff base...pr`, the merge-base
diff, which is what GitHub shows), and before reporting that a PR removes an existing
feature, confirm with `git merge-base` and `git log pr..base` that the branch isn't
simply behind.

Three reviewers is the whole panel. Don't add a fourth for breadth — the returns on
another reading pass are far lower than the returns on a well-scoped Step 7.

**Give each reviewer an explicit effort budget, because otherwise they optimise for
coverage and the cost lands on you twice** — once in their own runtime, once in the
verification they generate downstream. Tell them directly:

- Prove three or four claims properly rather than listing eight with thin evidence. The
  materiality gate (rule 13) should be doing most of the cutting before anything is
  written up.
- The baseline gates and full test suite have already been run and are in
  `/tmp/pr<N>_baseline.md`. Do not re-run them. Targeted single-test runs for a mutation
  experiment are expected and fine.
- Settle by reading what reading can settle, and spend execution budget on the categories
  where reading is unreliable: concurrency, effect ordering, error propagation,
  reachability, and "nothing tests this".
- Stop when the remaining candidates are all things you would let slide. Finding more is
  not the goal.

## Step 7 — Attack the survivors

**Read `references/finding_verification.md` now and follow it.** This step is what
separates this skill from a plausible-sounding review, and it is not optional or
skippable when the findings "look solid" — findings always look solid to whoever
just wrote them.

Because rules 12 and 13 now run inside each reviewer, the list arriving here is
pre-filtered: every claim already carries a `PROOF:` and a `MATTERS:` verdict. That
makes this step cheaper than it used to be, and it changes its job. It is no longer
first-pass verification. It is an adversarial second opinion by agents that did not
form the theory, and it does three things:

1. **Re-runs the proof independently.** A reproduction written by the same agent that
   formed the hypothesis tends to encode the hypothesis. Fresh agents catch harnesses
   that prove less than they appear to.
2. **Adjudicates disagreements between reviewers.** When two reviewers reach opposite
   conclusions, the one with better evidence wins, and the tie-break is usually which
   dialect or environment matches production. This is high-yield: in one run, two
   reviewers proved a recursion bug on SQLite and a third proved the same code correct
   on MySQL. Production was MySQL, so the finding shrank to a test-tier footnote.
3. **Re-judges materiality, harder than the original reviewer did.** Each reviewer
   judged its own finding in isolation. This pass sees the whole set and can ask which
   ones are actually worth the author's attention *relative to each other*. Expect it
   to overturn some "matters" verdicts to "let it slide", and treat that as the step
   working.

Do not skip it on the grounds that the reviewers already verified things. In the run
this guidance came from, it eliminated five of ten pre-verified findings and surfaced a
sharper one nobody had raised.

**Send it only what actually needs attacking.** This is the single biggest lever on how
long a review takes, because this step used to re-verify the whole list serially after the
reviewers had finished — roughly doubling the wall clock. Since rules 12 and 13 now run
inside each reviewer, most claims arrive already proven. Triage before dispatching:

**Must go** — these are where wrong findings concentrate:
- **Contested claims**, where two reviewers disagree. Highest yield in the whole step.
- **Anything marked unproven, inferred, or UNPROVABLE-HERE.**
- **Anything whose proof came from a different environment than production** — a different
  SQL dialect, a different runtime version, an in-memory stand-in for a real service.
- **A blocking claim whose proof has a specific, nameable weakness** — the repro was
  thin, the harness might be encoding the hypothesis, the environment is close to but
  not exactly production, or the command shown doesn't quite match the claim. Blocking
  status alone is not the trigger; a named doubt is. If you cannot articulate what might
  be wrong with an already-clean proof, it does not go here solely because it's heading
  for a blocking comment — re-running an unchallenged, production-equivalent proof for
  no stated reason is the same wasted work this step exists to avoid elsewhere.
- **"Nothing tests this" claims**, unless the reviewer already showed the break-and-run
  output.

**Can skip** — say so explicitly rather than silently dropping them:
- A claim all three reviewers independently reached with the same proof, where the proof is
  a command and its output you can read.
- **A single-reviewer claim proven against the production-equivalent engine/runtime,
  with a command and real output, and no one has raised a doubt about the harness.**
  Being the only reviewer who touched it is not a weakness by itself — rerunning a clean
  proof to generate the identical result a second time is not verification, it's cost.
- Anything settled by reading, where the reading is conclusive (a missing field, a version
  pin, grep showing no callers).
- Anything already marked "let it slide" — it is not going to be posted, so proving it
  harder is wasted budget. Note it and move on.

Then the shape (the reference has the detail):

- Fan out in parallel, grouped by the *proof technique* they share rather than by which
  reviewer produced the finding — one group per test tier, one for anything needing the
  real database engine, and so on. **If the must-go list is small, one agent is the right
  answer.** Do not fan out three agents over four claims.
- Reuse the worktrees created in Step 0, which already have dependencies installed. Give
  each agent its own, so they can mutate source without colliding.
- **Reserve the heavyweight environment for claims that actually need it.** Spinning up
  Docker, a real database and a real migration run is the most expensive thing in this
  skill, and on one run it was also the most decisive — it refuted a finding two reviewers
  had proven against the test dialect. So: use it, but only for claims that turn on
  engine-specific behaviour (lock semantics, constraint messages, truncation, rowcount
  semantics), and start it as early as possible since it dominates that agent's runtime.
- Force each claim into exactly one verdict: **DEMONSTRATED** (with the command and
  the real output), **DEMONSTRATED-BUT-NARROWER** (real, but only under a
  materially narrower precondition — say which), **UNPROVABLE-HERE** (needs a
  browser, a real cloud service, a multi-instance deploy — say what stays
  inference), **REFUTED**, or **PREFERENCE-NOT-BUG**.
- Require, for each claim, an answer to: *would a reasonable senior engineer on this
  team push back on this comment, and would they be right?* That question catches
  the confidently-worded non-issues that severity labels don't.
- Tell them plainly that **refuting a finding is a success**, and that recommending
  a finding be dropped is as valuable as confirming one. Otherwise they'll
  rationalise toward confirming, because confirming feels like finding something.

Obvious things don't need a harness. A missing `rel` attribute, a scheme comparison
that's case-sensitive, a numbering collision, a dependency pin — read the code,
state the fact, move on. Reserve the expensive verification for claims about
concurrency, effect ordering, error propagation, data retention, reachability, and
"no test covers this" — the categories where reasoning-from-reading is least
reliable.

Two proof techniques are worth naming because they're unusually decisive:

- **For a "nothing tests this" claim, break it and see.** Remove the protection the
  finding says is untested, run the suite, and report the result. If it stays
  green, that *is* the finding, stated in a way nobody can argue with. If something
  fails, the claim is refuted — say so.
- **For a "this races / this strands an effect" claim, drive the interleaving
  deterministically.** Use events or explicit seams rather than sleeps, and show the
  final state. A probabilistic repro that passes sometimes proves nothing and will
  flake if it becomes a real test.

Feed the verdicts back into Step 8. REFUTED and PREFERENCE-NOT-BUG findings are
gone — they don't get a softened version, they don't get an FYI mention.
DEMONSTRATED-BUT-NARROWER findings get rewritten to their true precondition, which
often changes their severity.

## Step 8 — Synthesize the verified findings

Work from the Step 7 verdicts, not the raw reviewer output.

- **Deduplicate across reviewers.** When two or more reviewers independently land
  on the same underlying issue, that's your highest-confidence finding and it
  should lead its section — but never say so explicitly in the output.
- **Organize as Critical / Important / Minor.** Severities are now the *verified*
  ones: a claim that survived only as DEMONSTRATED-BUT-NARROWER usually drops a
  level, and a "no test covers this" finding whose missing test turns out to
  **pass** against current code is a coverage gap, not a defect — say so, because
  it's a much smaller ask.
- **Every finding**: what the code does, the specific condition that produces a
  wrong outcome, that outcome, and the cheapest fix — plus the reproduction
  evidence. Attach the actual command output where you have it. No doc names, no
  reviewer attribution, no "the bot said."
- **Carry a Credit section.** Name what you verified as genuinely correct, with the
  same specificity as the criticisms. If a well-engineered piece held up under
  testing, that's a finding too, and it's the reason the author will believe the
  rest.
- **Carry a Retractions section.** Anything Step 7 refuted that you would otherwise
  have raised belongs here, briefly, with why it didn't survive. Including it feels
  exposing and is exactly why it builds trust: a reviewer who shows which of their
  own suspicions were wrong is demonstrating that the surviving ones were tested.
- **Reconcile every item from any existing bot or human review** explicitly —
  confirmed, refined with detail they couldn't see, or explained as a non-issue with
  the reasoning that makes it one. If their review targeted an older commit, verify
  against the *current* head and say which of their findings the newer commits
  actually fixed; don't repeat a stale finding as though it were live.
- **Note merge-readiness facts** that aren't defects but affect the author's next
  action — the branch being behind its base, a conflict a rebase would hit, a
  failing external check you've adjudicated. Keep these separate from findings.

This step produces the full verified findings list — what you'd show if the user
asked "what did you find," independent of what eventually gets posted. Step 9
decides posting; it doesn't re-decide what's a real finding.

## Step 9 — Decide how to post

Read `references/posting_triage.md` fully now if you haven't already — it's the
primary grounding for this step, more so than re-deriving the logic from scratch.

For every Critical/Important/Minor finding from Step 8, sort it into exactly one
of three buckets using that file's reasoning, calibrated by the Step 2 maturity lens
answer: **FIX NOW**, **DEFER WITH MARKER**, or **DROP**. Before recommending a new
marker for a DEFER-WITH-MARKER item, check whether an existing marker in the
codebase (whatever convention this repo already uses) already covers the same
gap — if so, say that explicitly instead of raising it as a fresh finding.

DROP-bucket findings do not appear anywhere in the output from this point on —
not as a "minor notes" section, not as an FYI aside. If a whole review turns up
nothing at FIX-NOW or DEFER-WITH-MARKER, say the PR is clean at that bar rather
than padding the output with dropped items to have something to show.

## Step 10 — Present and ask before posting

**Read `references/comment_style.md` now and draft against it.** Everything that
follows assumes it. The three failures it prevents are the ones that actually sink
reviews: facts listed without the consequence that makes them matter, an authoritative
register that turns a technical point into a disagreement about standing, and length.

**Length is a hard constraint, not advice.** Three to five sentences per thread, 250 to
450 characters, 600 as a ceiling. Draft long if that helps you think, then cut to a
third before anything is shown. Count the characters rather than eyeballing it — the
budget is small enough that estimates are wrong. If a thread will not fit, the usual
cause is that it contains two findings or a paragraph of methodology, not that the
finding is complex. The evidence goes in the terminal report to the requester; the
thread gets the problem, one proof point, and the ask.

Before drafting, answer one question for yourself and state the answer in the output:
**is anything here actually critical** — data loss, corruption, security, outage, or a
duplicate un-undoable external effect? If not, say so plainly and unprompted. Being
asked "is anything here really critical?" after you have already recommended blocking
means the calibration was wrong.

Present the results in two sections:

- **Fix before merging** — every FIX-NOW finding, with the concrete scenario and
  the fix.
- **Fine to defer** — every DEFER-WITH-MARKER finding, phrased as a recommendation
  to add the marker (with a concrete drafted `Known gap:` line), not a request to
  implement the fix now. If an item is already covered by an existing marker, say
  that explicitly here rather than omitting it — "already acknowledged, no action
  needed" is a useful thing to confirm.

Then a **Suggested PR comments** section previewing exactly what would be posted
(DROP items are simply absent, per Step 9). Default to showing this as a set of
**inline review comments** — one per finding, each anchored to the specific
`file:line` it concerns — plus a short overall review summary. This is what the
user almost always wants: a reviewer files inline threads the author works through
and *resolves* one by one, whereas a single bottom-of-PR issue comment can't be
resolved, bundles unrelated findings into one blob, and scrolls out of view. Post
as inline threads unless the user asked for a plain summary comment, or a finding
genuinely doesn't attach to any changed line (see the fallback below).

**Clean up the worktrees before presenting** (`git worktree remove <path> --force`
for each, then `git worktree prune`), and confirm in one line that the user's
branch and working tree are as they left them. Do this even if the review errored
partway — leaving worktrees and stray branches behind is a rude way to end a
read-only errand.

**If the thread count is getting large, say so and offer to trim.** Twenty threads
on one PR reads as a pile-on even when every one is valid, and the author will
triage by skimming rather than by severity. Offer a concrete split — post the
substantive ones as threads and fold the cheap mechanical ones into the summary
body — and let the user choose. Volume is a real cost, not a sign of thoroughness.

**Always ask explicitly whether to post these to the PR now or hold off — never
post automatically**, even if the user's original request sounded like a standing
instruction to review-and-post. Reviewing and commenting on someone else's PR is a
visible, externally-facing action; a prior "yes, post" in an earlier conversation
doesn't carry forward as blanket approval for future runs.

### If the user says yes

Follow `references/posting_mechanics.md` — anchoring comments to lines that are
actually in a diff hunk, building and validating the payload, choosing the right
`event`, and confirming afterwards that every thread attached where intended. That
file also covers the later "were my comments addressed?" follow-up, including the two
traps that make it easy to get wrong (rebased SHAs, and treating a "Fixed in abc123"
reply as evidence).

Two things from it are worth stating here because they're judgment, not mechanics:
the posted summary `body` should **open with what you credited as correct and what you
retracted**, before any criticism; and `event: "APPROVE"` is never yours to give on
someone else's PR — if the user wants it approved, say plainly that it's their click.

If the user says no, or doesn't respond, don't post. That's a fine outcome, not a
failure state.
