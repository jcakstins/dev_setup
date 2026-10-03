# Over-defensive code and illegal states

This is a standalone check, not a sub-bullet of the general design-smell list —
give it dedicated attention on every review, at every maturity lens, because
it's easy to skim past: the code looks careful (there's a guard! there's a check!)
when the actual problem is that the guard is compensating for a shape that should
have made the bad state impossible to construct in the first place.

## The question to ask, every time

For any defensive check — a re-validated condition, a boolean re-derived from
primitive fields, a `None`/empty-string used to mean more than one thing — ask
explicitly:

**Is this check protecting a state that's actually reachable, or is it guarding
against something that's already unreachable given the guarantees earlier in the
call chain?**

- **Reachable → keep it**, and say so plainly. Not every defensive check is a
  smell; a check that catches a genuinely possible bad input or state is doing
  its job. Don't flag it just because it exists.
- **Unreachable today → this is the finding.** Name concretely what makes it
  unreachable (the earlier guard, the type, the single call site), and propose
  the structural fix — not "add a comment explaining this is fine," but the
  actual shape change that would make the bad state impossible to represent at
  all.

## Common patterns to watch for

- **A condition re-checked in two places fed by the same inputs.** If both checks
  are downstream of the same call chain with no divergence possible between them,
  the second one isn't protecting anything today — it's a decision computed twice
  instead of once. The fix is usually to compute the decision once and thread the
  *result* through as data (a return value, a field), so a second independently-
  derived boolean can't exist to diverge under a future refactor.
- **A nullable/optional field standing in for a closed set of causes.** `token:
  str | None`, `error: str | None`, a boolean that's `True` for one reason and
  `False` for several different reasons — when several distinct causes ("not
  configured," "request failed," "not permitted," "succeeded") all collapse into
  the same two-valued shape, something downstream will eventually need to
  distinguish them and won't be able to without re-deriving logic that already
  ran once. The structural fix is a small closed union or enum — `Minted(token) |
  NotConfigured | NotPermitted(...) | MintFailed` instead of `str | None` plus a
  separately-computed bool — so a consumer pattern-matches instead of re-deriving.
- **A boolean re-derived from primitive fields in more than one place.** E.g. an
  `enabled` property computed from two raw strings, then re-checked ad hoc
  wherever "is this configured" matters. If the two checks could ever see
  different inputs (partial config, a race, a second constructor path), they can
  silently disagree. The fix is to make "configured" and "not configured" two
  distinct constructible shapes (e.g. a frozen dataclass with non-empty fields
  guaranteed at construction, wrapped in `Credentials | None`) rather than a
  derived boolean recomputed from parts.
- **A branch that exists because a type is looser than the real invariant.** A
  dict/dataclass field that's `Optional` even though exactly one calling
  convention ever leaves it unset, or a union of primitives standing in for what
  should be a tagged variant — ask whether tightening the type would delete the
  branch entirely rather than requiring it to keep re-checking.

## Judging cost, and how this feeds the posting decision

Not every instance calls for an immediate rewrite. Weigh it the same way as any
other finding:

- **Single call site today, full test coverage pinning current behavior, no
  second consumer on the horizon** — the structural fix would be premature
  abstraction for one caller. Say so, describe the fix concretely so it's ready
  when a second call site or a metrics/alerting need actually arrives, and treat
  it as DROP or DEFER-WITH-MARKER (never FIX NOW) per `posting_triage.md`.
- **Already spreading — a second caller exists, or the ambiguous shape is already
  being read by code that assumes one specific cause** — this has crossed from
  "inert but reasonable" into "reachable bad state," which makes it FIX NOW under
  the same file's rules: silently misreading which of several collapsed causes
  actually happened is a correctness bug, not a style preference.

Either way, never resolve this with "add a comment explaining the redundancy is
intentional" as the *only* recommendation when a structural fix is realistic and
not much more expensive — a comment documents the ambiguity, it doesn't remove
it. Reserve the comment-only recommendation for cases where the structural fix
would genuinely be premature abstraction, and say that's why, rather than
defaulting to it because it's the path of least resistance.
