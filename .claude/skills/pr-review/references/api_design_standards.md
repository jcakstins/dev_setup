> Generic distillation of common REST API design conventions. If your org has its own
> API design standards doc (Confluence, a wiki, a design-standards repo, etc.), swap this
> file for a distillation of that instead — the review logic in SKILL.md just reads
> whatever is here as the target shape.

# API Design Standards (generic target direction, not any one org's current state)

Audience: engineers designing new API endpoints. Describes target shape, NOT current state of any existing API — this repo has pre-existing tech debt against these standards; do not demand retrofits of unrelated existing endpoints.

Key points relevant to review:
- URL shape: `{baseUrl}/{feature}/v{n}/{path}`. Resources are plural nouns, CRUD via HTTP verbs. RPC-style actions only for business-meaning operations with no durable outcome, as `POST /{resource}/{id}:{action}` (colon separator, business verb, never a CRUD verb).
- GET must never mutate state; must be idempotent with optional query params.
- POST that creates a resource returns 201 + the new id only (not the full object).
- JSON field naming: camelCase everywhere in externally-facing payloads. Enums as string values, not integer ids (except customizable reference-table rows, which use an `xId` + documented lookup).
- Dates: ISO 8601, always UTC/Zulu.
- Response envelope: root is always an object (never a bare array), wrapped under a key named after the resource; lists include pagination metadata.
- Errors: conventional HTTP status codes carry the semantics; error body only needs `traceId` (+ optional `title`/`params`); never leak internal exception/stack/SQL/filesystem detail. 404 (not 403) when the caller has no access to a resource, to avoid confirming existence.
- Distributed tracing: `traceparent` header ingested/propagated; error responses include a `traceId`.
- Pagination: offset-based (`pageNumber`/`pageSize`) is the default/standard approach.
- Versioning: version only on breaking changes, scoped to the smallest feature area, not the whole API.

## How to use this
Most existing repos and services do not fully conform to these standards project-wide — existing routes and response shapes commonly predate this doc, and that's normal, accepted tech debt everywhere, not a property of any one codebase. How hard to push for adherence is a choice made explicitly at review time, via Step 2's **API-standards** question. That question is asked on **every** run, separately from the maturity lens, and it very often gets the opposite answer (pragmatic on maturity, lenient here). Never carry the maturity answer over to this axis. This file describes the target shape either way; it does not itself decide how strict to be.

**Lenient is the recommended default**, and it means something specific rather than "ignore this file". Do not expect conformance, because the surrounding code very likely already diverges and making this one PR conform would leave the new endpoints inconsistent with every sibling — a worse outcome than the divergence itself. What you *do* raise under Lenient is **quick wins**: changes that are local, low-risk, reduce future tech debt, and do not create inconsistency. Adding a `traceId` to a new error body, using a plural noun on a brand-new route, returning 404 rather than 403 on a cross-tenant miss in new code — all quick wins. Renaming existing routes, restructuring an established response envelope, or introducing versioning across a feature area are not; they are retrofits, and Lenient means not asking for them.

Under **Strict**, raise every conformance gap against the target shape regardless of existing repo patterns.

Regardless of the answer: only flag something here if this PR actually introduces or changes an HTTP API endpoint, route, or request/response shape. If it touches no HTTP-facing contract at all (internal services, MCP tool schemas, background workers, prompt/config files, or DB-only changes), **say so in one line in the output rather than staying silent** — the user was asked the question, so they are owed the answer, and silence looks like the axis was forgotten. MCP tool call schemas and internal factory functions are not HTTP APIs and these standards do not apply to them.
