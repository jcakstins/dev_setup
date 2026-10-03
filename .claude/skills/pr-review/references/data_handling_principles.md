> Generic distillation of common data-handling failure modes for services that mutate or
> serve persisted state. If your org has its own data-handling principles doc, swap this
> file for a distillation of that instead — the review logic in SKILL.md just reads
> whatever is here as the bar.

# Data Handling Principles (generic engineering standard — portable fallback)

These are guiding principles for services that mutate persisted state or read/serve data — most existing code doesn't fully follow them and that's fine; the point is to catch AI-assisted code that looks correct but reasons only locally (misses concurrency, retries, crash-mid-write, tenant boundaries, stale reads).

Two core ideas: (1) make illegal states unrepresentable so a bad value/unsafe query shape has nowhere to exist, and (2) don't assume something read earlier is still true later — checks and the action they protect should happen atomically, and reads should be stable/scoped by design, not trusted by default.

## State Mutation (write path)
1. Make invalid states unrepresentable — invalid transitions can't be expressed (e.g. declared transition tables, not scattered `if` guards).
2. Never blind-write state that may have changed — encode the precondition in the write itself (compare-and-swap: `UPDATE ... WHERE id=? AND status=?`, check rows-affected), not read-then-write with a gap. When the new value depends on the row read, take a row lock (`SELECT ... FOR UPDATE`) inside the transaction.
3. Commit one logical business change atomically — co-dependent writes (status change + audit + side effect within your own DB) go in one transaction; return the row as written inside the transaction, not a fresh re-read.
4. Treat non-rollbackable external effects (email, payment, webhook, third-party call) as durable two-phase workflows — commit an intent row before the effect, do the effect, record the outcome after. Do NOT use this for co-dependent writes within your own database — that's principle 3 (one transaction), not an outbox.
5. Make retry behavior explicit — idempotency keys for effects a retry could repeat (money, messaging, provisioning); same key + same payload replays the original result; same key + different payload is a 409, never a silent overwrite/duplicate.
6. Use typed/named errors mapped explicitly to status codes; never catch bare `Exception` and stringify it into a generic 400. Unnamed/unexpected errors should surface as 500, not be swallowed into a 400.
7. Scope ownership in the query itself (e.g. `WHERE id=? AND tenant_id=?`) and parse untyped input into a typed model at the boundary — don't fetch-by-id-then-check-in-app-code (leaks existence via 403 vs 404), don't pass raw dicts deep into write paths.
8. Make every material state change auditable — structured log with stable ids (never PII/names/emails) + correlation id, plus a separate access-controlled audit row (actor, from/to) committed atomically with the change. Degraded best-effort side paths (e.g. search-index mirror failure) must WARN, not silently `pass`/info-log "done".

## Data Consumption (read path)
1. Every read scoped server-side from verified identity (never from a caller-supplied/optional field with a fallback default like `school_id or "all"`); fail closed if scope can't be resolved.
2. Cross-tenant aggregates only released over a cohort large enough that no single tenant's data is identifiable (minimum cohort size, suppress below it) — caller-controlled filters must not be able to shrink the cohort to expose one entity.
3. Query shape (which column/field to filter/sort by) must come from a server-owned allowlist keyed by caller input, never caller input interpolated directly into SQL/query structure — parameter binding protects values, not identifiers.
4. Every external read (HTTP call, DB query) needs both a time budget (timeout) and a size cap (LIMIT) — an unbounded read is a resource-exhaustion risk, not just a correctness one.
5. Downstream read failures mapped to typed, honest statuses (timeout → 503 retryable, invalid query → 422 caller's fault, upstream auth failure → 502 our fault not caller's) — never a blanket 500, never leak internal error text.
6. Pagination/ordering must be stable and total (a unique monotonic key, not a non-unique/mutable timestamp with OFFSET) so concurrent inserts don't shift pages or produce duplicate/skipped rows.
7. If data is precomputed/cached/eventually-consistent, freshness must be an explicit, documented part of the response contract (e.g. an `asOf`/`maxAge` field), not a silent implementation detail.
8. Logging around a read must describe shape only (target, row count, correlation id) — never log filter values, query text with real inputs, or row contents (PII). A separate, access-controlled audit store is where identifiers belong when accountability requires it.

## How to use this
When reviewing, judge the code against these concrete failure modes and explain the *actual bug/risk* in plain terms (race condition, cross-tenant leak, silent duplicate effect, unbounded query, etc.) — do not cite "Data Handling Principles", "State Mutation Principles", or "Data Consumption Principles" by name in your findings; those names should never appear in your output. Just explain what breaks, under what condition, and how to fix it.
