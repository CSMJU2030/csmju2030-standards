# Changelog

## 1.3.0 — 2026-09-04

First version published to the `CSMJU2030` organization. v1.0.0–v1.2.0 existed
only under a throwaway personal account used to test the CI gate and were never
consumed by a subsystem, so the tightened rules below are not treated as a
breaking change.

### Rules corrected against the owning teams' real documents

The six standards documents arrived from their owners and replaced the stubs in
`docs/`. Reading them against the check scripts turned up four disagreements,
all of which would have blocked a subsystem that followed the documents:

- **`layer1_role` enum.** Scripts allowed `student|staff|faculty|admin|guest`.
  Both `data-dictionary.md` ข้อ 4 and `auth-contract.md` ข้อ 11 say
  `student|alumni|staff|admin`. `alumni` was being rejected, and `faculty` was
  accepted although it is a *field* name (รหัสคณะ) in the JWT, not a role.
  `guest` is a Layer 2 role, set per subsystem, not a Layer 1 value.
- **API global prefix.** `check-api-conventions.sh` demanded exactly
  `setGlobalPrefix('v1')`. `api-conventions.md` ข้อ 1 specifies `/api/v1`, and
  ข้อ 8 puts `/health` outside the prefix, which needs
  `setGlobalPrefix('api/v1', { exclude: ['health'] })`. Now both forms are
  accepted, and a trailing option argument no longer breaks the match.
- **Commit types.** The pattern accepted ten types; `github-workflow.md`
  ข้อ 1.3 lists seven. `style`, `perf` and `build` were passing CI although the
  published standard does not allow them — the script was looser than the
  standard it enforces, so the standard eroded silently. Tightened to
  `feat|fix|chore|refactor|docs|test|ci`.
- **Identity field.** `data-dictionary.md` 1.0.0 made `user_id` canonical while
  `auth-contract.md` ข้อ 11 makes `username` canonical and binds it to the JWT
  (`sub` must equal `username`); `user_id` is on the forbidden-alias list, so a
  subsystem following the data dictionary failed DD-01 on its first field.
  Resolved in favour of `username` and the data dictionary was corrected —
  see its Errata 1.0.0 → 1.0.1. `username` crosses a boundary Core owns (the
  gateway issues tokens with that claim), and `user_id` is too common a name to
  keep working as a forbidden-alias tripwire: every subsystem will use it for a
  local foreign key.

### API-03/API-05 no longer fail an empty repo

`check-api-conventions.sh` fired as soon as `backend/src` existed, so a freshly
scaffolded repo failed the envelope and `/health` checks before anyone had
written a line. It now requires at least one `.ts` file, matching the
"no files means skip" behaviour every other script already had.

### Rulesets are now applicable rather than illustrative

`org-settings/ruleset-*.yml` could not have worked if applied. Four defects:

- required status check contexts used bare job names; GitHub reports a reusable
  workflow's checks as `<caller job id> / <job name>`, so every context needs
  the `compliance / ` prefix. A bare name stays permanently "expected" and
  blocks nothing.
- `Exception Validation` was missing from the required list, leaving EXC-01
  advisory while the other seven jobs blocked.
- `bypass_actors` named `"@csmju2030/devops"`; the API takes
  `actor_id`/`actor_type`. Bootstraps with `OrganizationAdmin` until the team
  exists.
- `type: creation` carried a `restrict` parameter the API does not define.

Added `.org.json` / `.repo.json` payloads (repo-level drops `repository_name`,
which only org rulesets accept) and `org-settings/apply-rulesets.sh` with
`org` / `repo` / `validate` modes. Both payloads were accepted by the live API
as `enforcement: disabled`, then deleted.

### `new-subsystem.sh` rewritten and moved into this repo

The previous copy lived outside version control and produced repos that failed
CI immediately:

- it never created `.standards-version`, which `GH-04` requires, so every new
  repo failed Standards Version Check on its first PR
- `git init` with no `-b` left the default branch as `master`, so
  `on: pull_request: branches: [main]` never fired and the compliance workflow
  never ran at all — `CSMJU2030/csmju-equipment` is in exactly this state
- it pinned `@v1.0.1` while the repo was at 1.2.0
- it wrote its own copies of `ci.yml`, `CODEOWNERS` and `.env.example` instead
  of using `templates/`, so they drifted (its `.env.example` was missing
  `CSMJU_LOGIN_URL`)

It now derives the version from `VERSION`, reads every file from `templates/`,
rejects a non-kebab-case subsystem name, and runs the 15 content checks against
the scaffold before creating anything on GitHub.

### Also

- `.github/workflows/subsystem-compliance.yml` checked out
  `Pimma783/csmju2030-standards` for the check scripts in all eight jobs — the
  throwaway test account. Now `CSMJU2030/csmju2030-standards`.
- `templates/ci.yml` pinned `@v1.0.0`; `templates/subsystem.yaml` declared
  `standards_version: "1.0.0"` and `GET /v1/health` (health is outside the
  prefix, so `GET /health`).
- `ci-compliance-spec.md` moved into this repo. Seven files referenced it by
  name and by section number while it lived outside, leaving a dangling
  reference for anyone who cloned.
- self-test: 29 -> 34 assertions. New fixtures `DD-02` (the enum regression),
  `API-02` (prefix, pass/fail differ only in `main.ts`) and `API-02-EMPTY`
  (empty `backend/src` must pass).

## 1.2.0 — 2026-09-03

Makes `QA-01..04` and `API-01` actually runnable. They were reported as
"skipped" before, which read as passing while checking nothing.

- `ARC-02` now checks `dependencies` and `devDependencies` against different
  lists. Holding devDependencies to the runtime whitelist made QA-01..04
  impossible to satisfy: a Next app cannot typecheck without `@types/react`,
  TypeScript cannot be linted without a TS parser, and a Nest app cannot build
  without `@nestjs/cli`. tech-stack.md ข้อ 1 is an architectural rule about
  what ships to production, not about build tooling.
  - new `allowed_dev_tooling` list + `dev_tooling_patterns` (`^@types/`) apply
    to devDependencies only
  - `forbidden_everywhere` still applies to both, so a banned UI kit hidden in
    devDependencies is still caught
  - dev tooling is still rejected when declared as a runtime dependency
  - `reflect-metadata` added to `allowed_backend` (NestJS requires it)
- Added `__fixtures__/ARC-02-DEV` covering all three of those rules
  (self-test: 27 -> 29 assertions).
- The `API Contract Sync` job now sets up pnpm/node and installs, like
  `Code Quality` already did. `API-01` shells out to the subsystem's own
  `pnpm run generate:openapi`, so without a toolchain in that job the check
  skipped silently while the job still reported green.

## 1.1.0 — 2026-09-03

Fixes two false negatives found by a local pass/fail test round, and makes a
failing job report every violation instead of stopping at the first.

- `DD-04`: the faculty-name match is now case-insensitive. `const FACULTIES =
  [...]` — the most common way to write the constant — used to slip past a
  `[Ff]acult`-only pattern while `const faculties = [...]` was caught.
- `DD-05`: money fields are now caught when a type annotation sits between the
  name and the value (`fine_amount: number = 12.50`), and a prisma
  `Float`/`Decimal` money column is flagged in the schema itself — the root
  cause, which was never scanned before.
- Added `__fixtures__/DD-04` and `__fixtures__/DD-05` as regression cases for
  exactly the shapes that slipped through; self-test is now 27 assertions.
- Reusable workflow: every check step runs with
  `if: always() && steps.tools.outcome == 'success'`, so one PR shows every
  violation in a single run instead of one per push. The `steps.tools` guard
  keeps the checks from running when the standards checkout itself failed.

## 1.0.0 — 2026-09-03

Initial local scaffold implementing `ci-compliance-spec.md`, built to be
testable without a real GitHub organization.

- Added stub reference docs (`docs/`) for the 6 standards documents the
  spec cites but that didn't exist in this environment.
- Added check scripts for all 30 check codes in §7.1, implemented in bash
  so they run with no Node/pnpm toolchain required.
- Added `scripts/run-all-checks.sh` (orchestrator) and `scripts/self-test.sh`
  (fixture-based test harness) — run `bash scripts/self-test.sh` to verify
  the whole system.
- Added the reusable workflow (`.github/workflows/subsystem-compliance.yml`)
  and its self-test wrapper.
- Added `templates/` for what every subsystem repo should copy in
  (`ci.yml`, `CODEOWNERS`, PR template, `.gitignore`, `.env.example`,
  `subsystem.yaml`).
- Added `org-settings/` as reference-only config (org rulesets, Teams,
  2FA/branch-protection checklist) — **not applied**, since this
  environment has no real GitHub organization or admin credentials.
