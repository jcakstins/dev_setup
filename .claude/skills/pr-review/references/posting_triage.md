# Deciding how to post findings

Reviewers always work at full rigor, regardless of which maturity lens (PoC, MVP or
Scale-ready) the user picked in Step 2 — that choice never changes what counts as
a bug, a race, or a leak. What it changes is what happens *after* the findings
exist: which ones become a "please fix this before merge" comment, which become
a "fine to defer, but leave a marker so it doesn't get lost" comment, and which
don't get posted at all. This file is the primary grounding for that decision —
read it fully before Step 9.

Apply the reasoning below on its own merits, not just when a PR is explicitly
labeled PoC/spike/early-stage or the user picked a lenient lens. Work that never gets formally labeled that way is
often exactly the work most likely to ship unrevisited — the goal is "distinguish
what's actually load-bearing from what's cosmetic," which holds regardless of
label.

## The three posting buckets

**FIX NOW** — post as a direct, concrete fix request.
- Every CRITICAL finding, at every lens, without exception. A marker documents an
  accepted risk; it does not make a data-corruption, duplicate-side-effect,
  credential-leak, or functional-breakage bug acceptable, no matter how invasive
  the real fix is.
- Any IMPORTANT (or even MINOR) finding whose fix is cheap and mechanical — reuses
  a pattern or utility that already exists elsewhere in the codebase, is local to
  the touched file(s)/function(s), needs no new design decision (a retry/locking
  strategy, a new table, a new service) and no call-site changes outside this PR's
  own scope. Given implementation is typically AI-assisted, a fix this cheap is
  often no more expensive to apply than it would be to write and justify a marker
  — deferring it is busywork, not leniency, at any lens.

**DEFER WITH MARKER** — post as a non-blocking recommendation to add a tracked
marker comment, with a concrete drafted line, not a request to implement the fix
now.
- An IMPORTANT finding that's real but whose fix needs infrastructure that doesn't
  exist yet (a poller, an outbox, a cache, a distributed lock manager), a scoping
  decision that would affect other current or future work, a migration touching
  existing data, or would expand the PR well past its stated scope.
- Never applies to CRITICAL findings (see above) and never applies to something
  that would otherwise be DROP-tier — a marker is for a real, named gap, not a
  place to park a nitpick so it looks handled.

**DROP** — never posted, not even as an FYI line. Reporting these erodes trust in
everything else the review says.
- **Anything whose materiality verdict was "let it slide"** (ground rule 13). By the
  time a finding reaches this step it has already been judged twice on whether it
  matters — once by the reviewer that found it, once by the pass that attacked it. Do
  not relitigate that here and quietly promote it back. A proven-but-immaterial finding
  is exactly the thing this bucket exists for.
- **Anything Step 7's verification returned as REFUTED or PREFERENCE-NOT-BUG.**
  These don't get a hedged version, a softened version, or an "worth a look"
  mention. They were tested and they didn't hold. (They do get named in the review's
  Retractions section, which is a different thing: that's a record of what you
  checked and withdrew, not a finding being smuggled back in.)
- Anything you could only justify by naming a standard or principles document,
  rather than by naming the wrong outcome it produces. If there's no consequence to
  point at, there's no finding.
- File/module placement preference, naming preference where the existing name is
  already clear, docstring wording, comment phrasing, minor rewording.
- A test-coverage suggestion that targets implementation mechanics (a private
  helper, an internal call sequence) rather than observable behavior, or exists
  just to raise a coverage number rather than protect a named, realistic
  regression.
- A design-quality smell (illegal state left representable, a pseudo-discriminated
  union, duplicate logic across layers, a one-caller abstraction) where no
  reachable path currently produces a wrong outcome — see
  `illegal_states_check.md` for the full reasoning on when this stays DROP versus
  escalates.
- Anything else with no behavioral or architectural consequence.

## The litmus test for "is this more urgent than it looks"

The easiest way to under-triage is treating a concurrency or scoping finding as a
deferral question when it's actually a correctness question wearing a scoping
costume. Ask: **if this fires twice (a race, a retry, a crash-and-resume), does
anything external happen twice — an LLM call, an MCP/tool call, a DB write, an
email, a payment, a webhook?** If yes, it's FIX NOW regardless of lens and
regardless of how contained today's deployment looks. "Only one worker/instance
today" is a deployment fact, not something the code enforces, and it changes
without the code being revisited.

Likewise, a stated contract with genuinely zero test coverage (a constraint, an
allowlist, a status code claimed but never exercised) is FIX NOW even under PoC
— the issue isn't rigor for its own sake, it's that nobody actually knows the
contract holds.

## The scale question, asked before the bucket

Before bucketing anything about concurrency, throughput or growth, answer: **does this
fire at the product's current volume, or only at anticipated scale?**

This is not the same as severity and it changes the bucket on its own. A duplicate write
that needs two concurrent workers is a different claim at three pilot schools than at
three thousand. Both versions are true; only one is actionable now.

- **Fires today** — bucket normally by severity. Say "one trip is enough to cause this",
  because that is the sentence that stops a premature-optimisation reply.
- **Fires only at scale** — under Scale-ready it is a normal finding. Under MVP it is an
  observation with the trigger named ("this becomes likely once N runs overlap"), not a
  fix request. Under PoC it is usually DROP.

Getting this wrong in the pessimistic direction is expensive: a correct finding presented
as urgent when it cannot fire yet invites a fair rebuttal that also discredits the
findings which *can* fire, and those are the ones you needed them to read.

A caveat worth carrying into the comment when the answer is "wait for data": waiting only
works if the failure is *visible* when it happens. If the bad outcome is silent today,
the observability gap is the finding, and it is a smaller and much more acceptable ask
than the hardening.

## How the maturity lens shifts the calibration

All three lenses use the same three buckets and the same CRITICAL bar above. The
difference is how liberally an IMPORTANT finding gets pushed toward DEFER-WITH-MARKER
instead of FIX NOW, and how much airtime pure conformance gaps get at all.

| | Conformance gap | IMPORTANT, cheap fix | IMPORTANT, needs design | Fires only at scale |
|---|---|---|---|---|
| **PoC** | DROP | FIX NOW | DEFER-WITH-MARKER | DROP |
| **MVP** | DROP unless it's a quick win | FIX NOW | DEFER-WITH-MARKER | Observation, not an ask |
| **Scale-ready** | FIX NOW | FIX NOW | FIX NOW unless genuinely invasive | FIX NOW |

**MVP deserves the most explanation, because it is the setting most often chosen and the
easiest to get wrong in the strict direction.** The team is trying to get a product in
front of users and learn how it behaves. The key test: **can this fix be sized without
usage data?** A retry budget, a dedup window, a cache TTL and a rate limit all need a
failure rate to be chosen sensibly, and guessing at one now is not obviously better than
waiting a fortnight for real numbers. So under MVP:

- Raise what breaks at today's volume, with the evidence that it breaks today.
- For anything that only bites later, name the trigger and stop there. Do not attach a
  fix request to it.
- Do not ask for hyper-optimisation, defensive layers against unreached states, or
  abstraction for future flexibility.
- A cap or limit that protects the system regardless of load is still FIX NOW if it is
  cheap. "We already cap X, and Y has no cap" is a strong, well-received argument even at
  MVP, because it is a small guard rather than speculative hardening.

The API-standards answer is applied separately from the lens and must not inherit from
it. Under **Lenient**, a conformance gap is DROP unless it is a genuine quick win: local,
low-risk, reduces future tech debt, and does not make the new code inconsistent with its
siblings. Under **Strict**, raise the gap regardless of existing repo patterns. A user on
MVP with Strict API standards means exactly that.

Across all lenses, MINOR findings still default to DROP; promote one to FIX NOW only when
it is both trivial to fix and has a concrete, if small, failure mode. Never promote a
MINOR straight to DEFER-WITH-MARKER — a marker is overkill for something that was not
worth blocking on.

## The marker convention

The point of a marker is that the acknowledgment survives in the place that
actually gets read again — the code — instead of living only in a PR thread that
becomes unreachable once the conversation scrolls away.

**Before recommending a new marker, check what the repo already uses.** Grep the
touched file(s) and their immediate surrounding function/class for an existing
convention — `POC-SHORTCUT`, `TODO(tech-debt)`, `FIXME`, a ticket-tagged `TODO`, or
whatever this specific codebase already does. If one exists and its stated gap
plausibly covers the finding at hand, don't report a new finding at all — say
explicitly that it's already covered, and confirm briefly whether it's still
accurate. If one exists but covers a different gap, still report the new one, but
note the existing marker so the two don't accumulate as unrelated tags in the same
spot.

If no existing convention covers this gap, recommend adding one in whatever style
the repo already favors; if the repo has no visible convention at all, suggest:

```
# POC-SHORTCUT(<TICKET>): <one-line rationale for the deferral>
# Known gap: <concrete failure scenario in plain terms>. <optional: revisit
# trigger — what condition should prompt fixing this>.
```

(swap the tag for a plain `TODO(<TICKET>):` under MVP or Scale-ready if `POC-SHORTCUT`
would misrepresent work that isn't actually a PoC — the tag should describe the
work, not the review mode). Required fields regardless of tag: a ticket reference
(an unflagged, untracked shortcut isn't a deliberate deferral), a one-line
rationale, and a `Known gap:` line stating the concrete failure scenario — never
"needs hardening" or "could be improved."

As a non-blocking, informational line in the review summary, mention how many
existing markers of this kind were found near the diff (e.g. "2 existing
POC-SHORTCUT markers nearby, both still accurate") — this keeps accumulating
deferred debt visible over time without turning it into a gate.
