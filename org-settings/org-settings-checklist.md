# Organization settings checklist (reference only — not applied)

> Everything on this page is a **manual, one-time setup task** performed by
> DevOps against a real GitHub organization with admin rights. It cannot be
> scripted from inside a subsystem repo's CI, and nothing in this scaffold
> applies it automatically — see the implementation report for why.

## Teams to create (§5.2)

| Team | Members | Access per subsystem repo |
|---|---|---|
| `@csmju2030/devops` | Infrastructure team | Admin |
| `@csmju2030/pm` | PM1–PM5 | Maintain |
| `@csmju2030/pl-<subsystem>` | subsystem's PL | Maintain |
| `@csmju2030/aie-<subsystem>` | subsystem's AIE | Write |

## Organization settings (§9.3)

| Setting | Value |
|---|---|
| Base permissions | `Read` |
| Members can create repositories | ❌ |
| Members can delete repositories | ❌ |
| Members can change repo visibility | ❌ |
| Require 2FA for all members | ✅ |
| Actions permissions | Allow select actions |
| Workflow permissions | Read repository contents (default) |
| Allow GitHub Actions to approve PRs | ❌ |

## Allowed Actions list (§9.4)

```
actions/*
github/codeql-action/*
pnpm/action-setup@*
dorny/paths-filter@*
csmju2030/*
```

## Secret scanning (§10.4)

```
✅ GitHub Secret scanning        (Settings → Code security)
✅ Push protection               (บล็อกตอน push ก่อนเข้า repo)
✅ Dependabot alerts
✅ Dependabot security updates
✅ Custom patterns (เพิ่ม pattern ของ CSMJU client_secret)
```

## Rulesets

The `.yml` files here are human-readable reference; GitHub never reads them.
The importable payloads are the `.json` files, applied by `apply-rulesets.sh`:

```bash
./apply-rulesets.sh validate csmju2030-standards   # POST as disabled, then delete
./apply-rulesets.sh org                            # needs admin:org
./apply-rulesets.sh repo csmju-equipment           # plain `repo` scope, per repo
```

Both payloads were verified against the live API on 2026-09-04 (created as
`enforcement: disabled` on `CSMJU2030/csmju2030-standards`, then deleted).

Two things must be true before applying with `enforcement: active`:

| Prerequisite | Why |
|---|---|
| Every target repo defaults to `main` | `branch-naming` excludes only `refs/heads/main`, so a `master` default is rejected by its own rule. `apply-rulesets.sh repo` refuses such a repo. |
| Team `devops` exists | `bypass_actors` currently bootstraps with `OrganizationAdmin` (actor_id 1); swap for `{"actor_type":"Team","actor_id":<id>}` once created. |

The required status check contexts are `compliance / <job name>` — the caller
job in `templates/ci.yml` is named `compliance`, and GitHub reports a reusable
workflow's checks as `<caller job id> / <job name>`. A bare job name never
matches and therefore blocks nothing.

## Rollout order

Follow §12 of `ci-compliance-spec.md` (weeks 1–7): teams and org settings
first, then the standards repo + first scripts, then a warn-only pilot on
one subsystem, then blocking + full check coverage, then roll out to all
37 repos.
