# Unnecessary coupling and responsibility growth

Review whether the change causes a class, service, or module to take on
responsibilities outside its existing architectural role. Not all coupling is a
problem, and an abstraction is not the default answer — only raise a finding when
the design creates a meaningful maintenance risk.

## Raise a finding when

- A component now combines unrelated responsibilities that are likely to change
  independently.
- Business logic, orchestration, persistence, transport, provider-specific
  behavior, or configuration concerns are becoming mixed together.
- A lower-level or inner architectural layer becomes dependent on infrastructure,
  framework, transport, or provider implementation details.
- A caller must understand another component's internal workflow, call ordering,
  storage model, or configuration structure.
- New functionality is repeatedly being added to the same central service because
  it's the easiest integration point.
- A conceptually small change now requires coordinated changes across unrelated
  components or layers.
- The design weakens an existing boundary or makes an existing class noticeably
  harder to reason about or test.

## Never raise a finding based only on

- Class or method size.
- The number of dependencies.
- Theoretical future reuse.
- The absence of an interface.
- A preference for smaller classes.
- The possibility of introducing additional abstractions.

## Before raising the concern, name the concrete consequence

- Unrelated behavior becoming harder to change independently.
- Implementation details leaking across a boundary.
- An invariant no longer having a clear owner.
- Increased change propagation.
- Hidden ordering or lifecycle requirements.
- A class becoming the default home for unrelated future functionality.

A finding with no concrete consequence attached is a style preference, not a
finding — drop it.

## Recommend the smallest useful improvement

Favor extracting a focused responsibility, moving logic to its natural owner, or
preserving an existing boundary. Do not automatically suggest additional
interfaces, factories, registries, or layers — that just trades a coupling problem
for a premature-abstraction problem.

## Raising the finding

Raise a finding when the coupling creates a credible maintenance risk, weakens an
established architectural boundary, or contributes to a class becoming a
general-purpose coordinator or god class. State:

1. Which responsibilities or layers have become coupled.
2. Why they're likely to change independently.
3. The concrete maintenance or correctness risk.
4. The smallest reasonable improvement.

Never frame the finding as a universal design rule or personal preference — it's a
claim about this specific change's risk, not a style mandate.

## How the review mode calibrates this

In **PoC/early-stage mode** (Step 2 of the calling skill), apply a more permissive
standard. Accept direct/concrete coupling when it's local to the experiment,
explicit, easy to remove or replace, isolated from shared production abstractions,
and proportionate to the short-term work. Only raise a finding when the coupling:

- Changes shared architecture for experiment-specific needs.
- Spreads conditional or provider-specific logic through existing production code.
- Adds substantial new responsibility to an already-overloaded component.
- Weakens security, authorization, data integrity, or domain guarantees.
- Is likely to survive beyond the experiment but is presented as temporary.
- Would make the experiment difficult to remove without restructuring unrelated
  code.

Under **Scale-ready**, hold the plain "Raise a finding when" criteria above without
the extra permissiveness — coupling that would need a marker under PoC or MVP is more
often a FIX NOW finding here, since there's no "this is throwaway" framing to
justify deferring it.

Sort every such finding into the same three posting buckets as any other finding
(see `posting_triage.md`) — don't invent a separate bucket for coupling:

- **FIX NOW** — the coupling is a live risk today (weakens security/authorization/
  data integrity, or otherwise meets the criteria above) or the fix is cheap and
  local.
- **DEFER WITH MARKER** — real, but deferrable, and the fix is genuinely invasive;
  apply the usual fix-now-vs-marker cost judgment.
- **DROP** — coupling that would only matter if throwaway work is retained/becomes
  permanent is speculative at review time, same as any other theoretical-future
  concern — don't raise it now.
