# Verifying findings before they become comments

This is Step 7 of the review, and it is the step that determines whether the review
is worth anything. Read it fully before running the stage.

## Why this exists

A deep-reading reviewer generates plausible findings much faster than it generates
true ones. It has read a diff, built a model of the code, and reasoned about what
could go wrong — and reasoning about what could go wrong is exactly the activity
where a confident narrative and a correct one are hardest to tell apart. The result
is a findings list where some entries are real defects, some are real but far
narrower than described, some are unreachable, and some are simply wrong, all
written in the same authoritative register at the same severity.

Posting that list unfiltered is worse than posting nothing. The author spends hours
investigating non-issues; they find one claim that was confidently wrong; and from
that point they read every remaining finding as noise — including the two that would
have caught real data loss. **The cost of a wrong finding is not zero, it is
negative, because it spends the credibility the correct findings need.**

So the goal of this stage is not to build a case for the findings. It is to try to
destroy them, and ship only what survives. Expect to lose a third to a half of them.
A review that drops many of its own findings is working correctly.

## Verification starts at the reviewer, not here

Step 7 is the adversarial pass, but it is not the first filter. Per ground rule 12,
**every reviewer must try to prove its own findings before reporting them.** Finding and
proving are different jobs, and a reviewer that has just built a convincing mental model
will stop after the first unless told not to.

So each reviewer runs the repo's tests, writes throwaway reproductions under `/tmp`,
mutates source and shows the suite still passes, or prints the assembled artefact — and
reports the command and the real output alongside each finding. Anything it could not
substantiate it either drops or labels unproven in plain terms. This is not duplicated
effort: it removes the weakest third of the list before the expensive stage runs, and it
means Step 7 spends its budget attacking claims that already have evidence behind them.

## Findings that depend on another service: go and read it, then ask

The largest single source of wrong findings is a reviewer reasoning about a contract it
cannot see. Tool schemas served by an MCP server, a downstream API, a shared library, a
sibling repo in the same stack — a reviewer reading only the repo in front of it will
conclude something is missing when it is in fact declared elsewhere, and will say so with
complete confidence.

The first fix is to stop treating the repo boundary as the edge of the knowable. **Read
the installed dependency** (`.venv/lib/python*/site-packages/`, `node_modules/`) — that
is the exact code that runs, so it beats any doc. Check the lockfile for the pinned
version, grep sibling checkouts on disk, and use the host CLI (`gh api`,
`gh search code`, `gh release list`) for the remote. A verifier that does this converts
hedges into hard findings: in one run, reading an installed auth library turned "this
claim probably never arrives" into "the payload model carries it and a projection
function drops it, so the upstream team shipping it is not sufficient and a library
release is an untracked prerequisite".

What remains after looking is usually not code: runtime configuration, a third party's
behaviour, another team's intent. **That is when you ask the user.** They can answer in
seconds and would far rather answer one question than receive a wrong comment.

Concretely:

- Reviewers and verifiers never write "this should be verified against service X's
  contract", "the schema may declare this", or "assuming the downstream doesn't handle
  it". A finding hedged that way is not a finding, it is a research task handed to the
  author.
- They surface it in a `CONTEXT NEEDED` list instead, naming what they need and what the
  answer would change.
- The orchestrator batches those into one question to the user, then resolves them before
  Step 8.
- A finding still resting on an unseen external contract is **unresolved**, not a
  low-confidence finding to post with a caveat.

Worth internalising how decisive this is: in one run, the top finding from two
independent reviewers was that a prompt had dropped a required payload shape. The tool's
own schema in a sibling repo already declared that shape, with a worked example, enforced
by validation. One question would have saved both reviewers' effort and prevented a
confidently wrong comment.

## What needs verifying, and what doesn't

Don't build a harness for things you can settle by reading. These are fine to state
from inspection, as long as you actually looked rather than assumed:

- A missing attribute, a case-sensitive comparison that shouldn't be, an off-by-one
  in a constant.
- A dependency pin, a version specifier, a config value.
- A migration numbering collision, a file that exists or doesn't.
- Whether a function has callers (grep is proof).
- Whether a documented convention says what you claim (quote it).

Spend the verification budget on the categories where reading is least reliable:

- **Concurrency and ordering** — races, interleavings, lock scope, what's inside
  which transaction.
- **Effect sequencing across boundaries** — what's stranded if step two fails after
  step one landed, especially DB-plus-object-storage pairs.
- **Error propagation** — what a caller actually receives, what status code actually
  comes back, what string a tool actually returns to a model.
- **Reachability** — whether the bad path can be entered at all. This one is the
  single most common source of overstated findings.
- **Data retention and deletion** — whether something claimed to be erased is
  actually gone, everywhere.
- **"Nothing tests this"** — trivially checkable and very often wrong.
- **Engine-specific behaviour** — anything that differs between the dialect used in
  tests and the one used in production.

## How to run it

**Fan out by proof technique, not by reviewer.** Findings from three different
reviewers that all need the real database engine belong in one agent; two findings
from the same reviewer that need different tiers belong in different agents. Group
by what the agent has to set up, because setup is the expensive part.

**Give each agent its own throwaway worktree with dependencies installed.** They
will run tests, write scratch files, and sometimes need to mutate source to prove a
point; sharing a tree makes them collide and makes results untrustworthy. Install
dependencies in parallel and in the background before dispatching.

**Let them modify their own worktree, and require them to prove they restored it.**
Some proofs genuinely need a source mutation — the "remove the protection and see if
tests still pass" technique below is the clearest example. Permit it, require the
diff be recorded, require a revert, and require a closing `git status` in the report.

**Tell them refuting is winning.** Say it explicitly, more than once. Without it,
agents rationalise toward confirmation, because confirming feels productive and
refuting feels like coming back empty-handed. Also ask each one directly to
recommend keep-or-drop per finding, which forces a judgement rather than a hedge.

## Two verdicts per claim, not one

Every claim gets a **truth verdict** and a **materiality verdict**, and it has to survive
both. Keeping them separate is what stops the two most common failures: posting a true
finding nobody cares about, and dropping a real one because the fix looked expensive.

The materiality verdict is **matters** or **let it slide**, with a reason, per ground
rule 13. Judge it across the whole set rather than per finding — the original reviewer
saw one claim in isolation and could not ask "is this worth the author's attention
compared to the other four?". You can. Expect to overturn some verdicts to "let it
slide"; that is the pass working, not the pass being lax.

What never gets softened by a materiality verdict: data corruption, credential leaks,
duplicate un-undoable external effects, security holes. Those are reported at full
strength however awkward the fix.

## The truth verdict labels

Force every claim into exactly one. Ambiguity here is what leaks bad findings.

- **DEMONSTRATED** — ran something that proves it. Requires the command, the real
  output, and a one-sentence statement of the consequence.
- **DEMONSTRATED-BUT-NARROWER** — real, but only under a materially narrower
  precondition than the finding claimed. Requires the true precondition. This is the
  most valuable verdict in practice and agents under-produce it; ask for it by name.
- **UNPROVABLE-HERE** — plausibly real, not provable in this environment (needs a
  browser, a real cloud service, a live provider, a multi-instance deploy). Requires
  saying what *was* established, what remains inference, and a confidence level.
  Never let inference be dressed up as proof.
- **REFUTED** — tried to reproduce it, the code handles it. Requires the evidence.
- **PREFERENCE-NOT-BUG** — no demonstrable failure; a taste or consistency argument.

## Two techniques that settle arguments

**To verify a "nothing tests this" claim: break it and see.**
Remove the protection the finding says is unprotected, run the suite, report the
result verbatim. If it stays green, that output *is* the finding and no one can argue
with it. If something fails, the claim is refuted — name the test that caught it.
Then, if you're proposing a new test, confirm the proposed test actually fails
against the mutated code, otherwise you're asking for a test that protects nothing.

**To verify a race or a stranded effect: drive the interleaving deterministically.**
Use events or explicit seams to pin the ordering rather than sleeps or repetition. A
probabilistic reproduction that passes intermittently proves nothing, and if it later
becomes a real test it will flake and get deleted. Show the final persisted state
from both sides — the wrong value is the finding, not the theory of how it got there.

## The question that catches the rest

For every claim, require an answer to: **would a reasonable senior engineer on this
team push back on this comment, and would they be right?**

This is the highest-yield question in the stage. It catches things severity labels
don't: findings that are technically true but not worth a thread; findings that
ignore a constraint the author documented deliberately; findings that would make the
code inconsistent with everything around it; findings whose fix is worse than the
problem. When the honest answer is "yes, they'd push back, and they'd have a point,"
that finding either needs reframing to its defensible core or dropping entirely.

Ask also whether the *author already knows*. If the PR description, a design doc, or
an in-code comment already states the thing as a deliberate decision, then raising it
as a discovery is both wrong and slightly insulting. Either add new information they
didn't have, or leave it alone.

## Reframing rather than dropping

Many findings survive in a smaller, sturdier form. Prefer reframing to discarding
when there is a defensible core:

- "This is a latent security hole" → the path is unreachable, but the two unused
  parameters that create it have no callers, so: "delete these, they're dead."
- "This will corrupt data" → it can't today, but the mapping is correct only because
  no other constraint can currently fire, so: "narrow this catch while it's cheap."
- "This violates the erasure contract" → it does, but the contract wording is what's
  inaccurate rather than the code, so: "the description overstates what this closes."

Each reframe is smaller than the original claim and much harder to argue with. That
trade is almost always worth making.

## What to bring back

Per claim: the verdict label, the exact commands, the real output trimmed to what
matters, the one-sentence consequence a skeptic would accept, and the pushback
answer. Then, across the set:

- **Keep/drop recommendation per claim**, one line each, willing to say "drop this."
- **Credit due** — what the code genuinely gets right, verified to the same standard.
  Several findings will collapse *because* something is well built; say so, because
  that's the most useful thing the author hears.
- **Anything the review missed** that you can demonstrate. Verification agents often
  find the sharper version of a finding while testing a blunter one.
- **Whether any new test the author added would actually fail if the fix were
  reverted** — a test that passes either way protects nothing.
- **Confirmation the worktree source is unmodified.**

## When verifying claimed fixes

The same machinery applies when checking whether earlier review comments were
addressed — don't accept "Fixed in abc123" at face value. The standard is: re-run the
original reproduction and show it no longer reproduces. Then look for the two failure
modes that a fix-verification pass exists to catch:

- **Partially fixed** — the exact case that was demonstrated is closed, but the
  mechanism is intact and an adjacent case still reproduces. Look for this actively;
  it's the most common outcome of a fix written against a specific reproduction.
- **Fixed but introduces a new problem** — especially likely when the fix adds a
  concurrency control, a new column, or a new error path. New code that arrived after
  the review is unreviewed code, and deserves a fresh read rather than a checkbox.

For a fix that adds a column or a constraint to existing data, always ask what
happens to rows that predate it. Fail-closed and fall-back-to-old-behaviour are both
plausible, and they have very different consequences.
