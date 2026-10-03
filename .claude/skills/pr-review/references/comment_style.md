# Writing the comment

Read this before drafting anything that will be posted. A correct finding written badly
gets dismissed, and a dismissed finding costs more than no finding at all, because it
spends the credibility the rest of the review needs.

The target reader is a competent engineer who did not write every line themselves (much
of it may be AI-assisted), who is busy, and who may not have traced the path you are
describing. Assume good faith and assume they will act on anything they find convincing.

**Treat length as a defect, not a style preference.** Every thread has a budget of three
to five sentences (see *Shape and length*), and going over is the most common way this
review gets ignored. Verbosity is not thoroughness — it is the finding plus everything
you happened to learn while proving it. The evidence, the methodology, the trial counts
and the alternatives you considered belong in the report to the person who asked for the
review. The PR thread gets the problem, one proof point, and the ask.

## The rule that matters most: every fact must carry its consequence

Do not list code facts and leave the reader to work out why they matter. This is the
single most common way a real finding dies, because the honest reply to a bare fact list
is "so what?", and once they have said that they have stopped reading.

Bad, and typical:

> `enabled` is `true`, `FileDefinitionRegistry.all_definitions()` filters on `enabled`
> only, `GET /api/v1/agent-definitions` returns it to any valid JWT, and any
> application-scoped token can create an agent from it.

Every clause is accurate and the paragraph says nothing. Chain it instead: fact → what
that means → what goes wrong.

> I checked whether anything keeps this definition away from real schools, because if it
> were demo-only both problems below would be fine. Nothing does: `enabled` is the only
> filter, and any application-scoped token can create an agent from it. So this runs
> against real pupil data.

Same facts, plus the reason they were gathered and the conclusion they support. If you
cannot name a consequence for a fact, delete the fact. This shortens comments as a side
effect, which is the second thing that makes them get read.

## Collaborative, not authoritative

Never frame a finding as right-way/wrong-way. "We already do this correctly for X"
implies their code is the wrong way and invites a defensive reply. "We do X for events,
would that shape work here?" says the same thing and opens a conversation.

- Prefer "this returns X when Y, which means Z" over "this is wrong".
- Where the answer is genuinely theirs (product decisions, deliberate deferrals,
  anything they documented as intentional), ask rather than instruct.
- **Prefer a stated assumption over a question.** "The heading says Demo, so I assume
  this was meant for the demo definition" is easier to act on than "did this go in the
  intended file?", and it does not add to the pile of things they must answer. Keep the
  number of open questions per review low; repeated requests for clarification are
  exhausting to read.
- Concede the strongest objection to your own finding, up front, in your own words. A
  comment that begins "the fix here does not belong in this file, prompt text cannot
  guarantee this" is very hard to push back on, because the reply they were forming is
  already in the comment.

## What to leave out

- **Meta-narration about your own review process.** No "things I thought were problems
  and turned out fine", no "I checked this and dropped it", no retractions section. If
  something was dropped it simply does not appear. Narrating your own false starts reads
  as noise and is actively irritating.
- **Anything the tooling already surfaces.** That is the test: if GitHub, CI or the PR UI
  already shows it, do not write it. Merge-order and stacked-PR notes, "your branch is
  behind, rebase needed" (the conflict is already flagged), empty-PR-description nags.
  Reviewer value is in things that took work to find, not housekeeping.
- **Praise padding.** Credit is worth including only where it is load-bearing for the
  finding — "the rule itself is correct, the issue is its timing" tells them something.
  A list of what they did well does not, and some readers find it patronising. Check
  whether the user wants it at all.
- **Repeated preamble.** State "I verified this by running tests" once, in the review
  summary, not at the top of every thread.

## Shape and length

Open plainly and get to the point: *"Hey, I ran some tests on this one and I think it
needs a look."* Then what the code does, the condition, the consequence, the ask.

Write first person. Keep sentences short. Prioritise clarity over polish — English is
often not the reader's first language, so plain words beat precise-but-dense ones. Avoid
em dashes.

**Target 250 to 450 characters per thread. Treat 600 as a hard ceiling.** That is three
to five sentences. Not a paragraph each for the problem, the evidence and the fix — the
whole thread. A thread at 1500 characters is not more thorough, it is unedited: it gets
skimmed, and skimming defeats the ordering you put the findings in.

**Write the long version if it helps you think, then cut it to a third.** Not a trim, a
third. If that sounds impossible, that is the reaction that precedes every successful
cut, and the result reads better every time. The bulk is always one of these five
things, none of which the reader needs:

- **Evidence narration.** The reader does not need your methodology. "I drove two
  writers at it with a deterministic barrier so both read version 1 before either
  wrote, against real MySQL 8" is you showing your work. "Two writers, both told
  success, one token lost" is the finding. **One number or one line of output is
  enough proof for a thread.** The full evidence goes in the terminal report to the
  person who asked for the review, not into the PR.
- **Restating the code back to the author.** They wrote it. Name the line and the
  behaviour that is wrong, not the whole mechanism.
- **Second-order consequences spelled out in full.** Say the primary consequence.
  If the knock-on matters, one clause, not a paragraph.
- **Pre-empting objections you have not heard yet.** Concede the single strongest one
  (see above) and stop. Three hedges read as nervousness and invite the argument.
- **Two findings in one thread.** If a thread has a "separately, while you are here"
  section, that is a second thread or a line in the summary.

Length discipline is not cosmetic. The person reading has a queue, and every sentence
that is not load-bearing spends attention the next finding needed.

Lead the review summary with what is actually blocking, so scope is clear in one line
before they read anything. The summary can be longer than a thread, since it carries the
awareness items and the credit, but the same cut applies.

### The cut, worked

A real posted thread, 1470 characters, every sentence true:

> This guard is the right thing and it works correctly. The problem is that nothing
> holds it. If I delete this line, all 1799 unit tests still pass. The same deletion on
> `replace_refresh_token` fails 2 tests, so the gap is specific to this method. The
> reason is the Python check at line 165: it short-circuits every single-threaded test
> before the SQL guard matters, so the guard looks covered when it is not. What made me
> want to raise it rather than let it go is that the Python check is not a real second
> line of defence. Under actual concurrency both callers read version 1 and both pass
> it. With this SQL line removed, against real MySQL, I got 2 successes and 0 stale
> errors on 5 runs out of 5. With it in place, 1 success and 1 `AgentTokenStaleUpdateError`.
> So the only thing protecting the transition is the part no test touches, and a future
> reader could reasonably delete it as redundant given the check above. Coverage agrees:
> lines 178-179 and 166 are both unhit. [...plus a paragraph proposing the test...]

The same finding, 430 characters, nothing lost:

> This guard works, but nothing holds it: delete this line and all 1799 unit tests still
> pass. Deleting the same clause in `replace_refresh_token` fails 2 tests, so the gap is
> specific here. The Python check above short-circuits single-threaded tests, so the
> guard looks covered and is easy to delete later as redundant. Under real concurrency
> both callers pass that check, so this line is the only thing working.
>
> A `db_integration` test with two concurrent `mark_status(expected_version=1)` calls
> asserting one stale error would hold it.

What went: trial counts, coverage line numbers, "what made me want to raise it", and the
explanation of why the Python check is not a real defence, which the reader now gets in
one step from "both callers pass that check". What stayed: every load-bearing fact, the
proof, and the ask.

A second real one, cut from 2060 characters to 400. The original opened by narrating the
test harness, spelled out a second-order consequence over a full paragraph, and appended
an unrelated finding under "separately, while you are in here":

> This update has no `version` predicate and no rowcount check, unlike the two methods
> below. Two writers that both read version 1 both report success, version goes 1 to 2
> instead of 1 to 3, and one token is lost silently (reproduced on InnoDB). It also
> makes `version` ambiguous, so a later CAS on version 2 can win against a row that
> changed under it.
>
> Careful with the fix: adding only the predicate makes the update match zero rows and
> still return success. Predicate plus server-side increment plus retry on
> `rowcount == 0` worked, or `INSERT ... ON DUPLICATE KEY UPDATE`.

The unrelated finding became one line in the review summary, where it belonged.

## Layer discipline: never ask config to hold an invariant

Prompt files, playbooks, skill markdown and agent definitions are often authored by
people outside the team, and increasingly by customers. Treat them as untrusted input.
Safety belongs in code.

So when a genuine issue surfaces in prompt or config text, keep the finding but move the
ask: state the verified consequence, then name the missing code-level guard. Asking for
better wording to prevent duplicate writes is asking a text file to enforce correctness,
and a thoughtful author will say so.

The corollary is that a finding about *task flow* in a playbook is usually not a defect
at all — it is a product decision belonging to whoever owns the flow. Distinguish guards
(limits, caps, idempotency, anything that protects the system regardless of the task)
from steering (what the agent should do for this particular job). Press on the first;
raise the second as a question at most.

## Two mistakes that come from not knowing the domain

Both of these produced wrong suggestions in real runs, and both are avoidable by asking.

- **Assuming a repeat is always wrong.** Before proposing deduplication, check whether
  repeating the action is sometimes correct. Resending an approval after a document is
  revised is legitimate, so a naive dedup would suppress real behaviour.
- **Assuming a flow is settled when it is experimental.** A deliberately prescriptive
  example, written to test whether the approach works at all, is not a contract. Ask
  about maturity before treating it as one.

## Blocking or not

Default to approving when nothing is critical, rather than blocking over cheap fixes.
Say plainly that nothing critical was found, then frame the remaining items as easy
improvements to fold into work already happening — resolving conflicts, a rebase, a
follow-up commit. A one-line file move does not justify a merge block.

Decide this *before* posting: is anything here actually critical — data loss, corruption,
security, outage, or a duplicate un-undoable external effect? If not, say so unprompted.
Being asked "is anything here really critical?" after you have already requested changes
means the calibration was wrong.

`APPROVE` is the user's call, not yours. If they direct it explicitly, note once that it
posts under their identity and proceed.
