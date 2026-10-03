# Security review policy

## Tooling selection

1. Check the target repo's own pre-commit config (`.pre-commit-config.yaml`) and CI
   workflows for already-wired security tooling — SAST (e.g. bandit, semgrep,
   eslint security rules) and dependency/CVE scanning (e.g. pip-audit, npm audit,
   snyk). If found, run those tools with the exact configuration the project's own
   gate uses (matching the project's own bar is more meaningful than an arbitrary
   external one), e.g.:
   ```bash
   uv run bandit -c pyproject.toml --severity-level medium -r .
   uv run pip-audit
   ```
2. If the repo has no wired dependency/SAST tooling, fall back to the Snyk CLI if
   installed and authenticated (`snyk whoami` succeeds). Run:
   ```bash
   snyk code test      # SAST across changed files/repo
   snyk test           # open-source dependency vulnerabilities against manifest/lockfile
   ```
3. If neither is available, say so plainly in the synthesis and skip this
   reviewer's dependency/SAST checks — don't block the rest of the review on
   missing tooling, but don't silently omit the gap either.
4. Where possible, run against both base and head (or diff the tool's findings
   between them) so pre-existing findings can be told apart from ones this PR
   introduces — see below, that distinction is the whole point of this review.

## Suppression policy — the core check

The point of this reviewer is not "are there CVEs" — most repos already carry some
accepted risk, and that's normal. It's **"did this PR add a new way to hide a CVE
that already has a fix available."**

- **Pre-existing suppressions are out of scope.** Anything already
  ignored/suppressed in the base branch before this PR (an existing `.snyk` ignore
  entry, an existing `# nosec`, an existing pinned/vulnerable dependency version) is
  accepted debt. Don't relitigate it just because the scanner still reports it.
- **Any suppression newly introduced by this PR is in scope.** Concretely:
  - A new entry in a `.snyk` ignore/policy file.
  - A new inline suppression comment (`# nosec`, `# noqa: S<code>`, `//
    nosemgrep`, or equivalent for the target language).
  - A new or widened dependency/SAST ignore flag in CI or pre-commit config
    (`--ignore-vuln`, `--exit-zero`, a lowered `--severity-level`, a disabled
    check).
  - A dependency version pin or downgrade that avoids a fix already published
    upstream (adding an upper bound, rolling back a version) for a package that
    has a newer patched release available.
- **If a newly-suppressed CVE has an available fix, this is always a blocking
  finding** — resolved by upgrading, never by suppressing. State the exact fixed
  version (from the scanner's own remediation advice, or the package registry) so
  the fix is a one-line diff, not an open-ended ask.
- **If a newly-suppressed CVE genuinely has no available fix yet** (upstream
  hasn't patched), suppressing it is reasonable — but flag it as should-fix, not
  silently accepted, and check the suppression itself documents the CVE id and the
  reason inline. An undocumented suppression is worth a one-line comment request
  even when the suppression itself is justified.
- Low/medium-severity dependency findings with no fix available, and anything
  already accepted before this PR, don't need resolving — consistent with any
  org's own accepted policy on unfixable findings.

## What NOT to do

- Don't re-flag a repo's entire pre-existing vulnerability surface just because the
  scanner reports it on every run — that's noise, not a PR-specific finding.
- Don't demand a tool be installed or added to a repo that doesn't have one; note
  the gap and move on.
- Don't treat a low-severity, no-fix-available dependency finding as blocking.
