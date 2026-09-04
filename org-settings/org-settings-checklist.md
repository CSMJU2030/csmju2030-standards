# Organization settings checklist

> สถานะ ณ 2026-09-04 — ส่วนใหญ่ตั้งแล้วผ่าน `gh api` ที่เหลือระบุไว้ว่าทำไมยัง
> ไม่ได้ ไม่ใช่ทุกข้อที่ทำได้บน plan Free

## สรุปสถานะ

| ข้อ | สถานะ |
|---|---|
| Teams `devops` `pm` `pl-equipment` `aie-equipment` | ✅ สร้างแล้ว + ผูกสิทธิ์เข้า repo แล้ว |
| Base permissions = Read | ✅ |
| Members can create repositories | ✅ ปิดแล้ว (ทั้ง public และ private) |
| Actions = Allow select actions | ✅ + allow-list |
| Workflow permissions = read | ✅ |
| Allow Actions to approve PRs | ✅ ปิดแล้ว |
| Secret scanning + push protection | ✅ ทั้ง 2 repo |
| Dependabot alerts + security updates | ✅ ทั้ง 2 repo |
| Ruleset ระดับ repo | ✅ ทั้ง 2 repo (bypass = team `devops`) |
| **Ruleset ระดับ org** | ❌ **ทำไม่ได้บน plan Free** — API ตอบ 403 `"Upgrade to GitHub Team to enable this feature."` ต้องตั้งราย repo ด้วย `apply-rulesets.sh repo <name>` ทุกครั้งที่สร้าง subsystem ใหม่ |
| Require 2FA for all members | ⬜ ยังไม่ได้ตั้ง — ตั้งในหน้าเว็บ: Settings → Authentication security |
| Members can delete repositories | ⬜ ยังไม่ได้ตั้ง — ตั้งในหน้าเว็บ: Settings → Member privileges |
| Members can change repo visibility | ⬜ ยังไม่ได้ตั้ง — ตั้งในหน้าเว็บ: Settings → Member privileges |
| Custom secret-scanning pattern (CSMJU client_secret) | ⬜ ต้องทำในหน้าเว็บ |

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

`.yml` ในโฟลเดอร์นี้เป็นฉบับให้คนอ่าน GitHub ไม่อ่านไฟล์พวกนี้ ตัวที่ import
ได้คือ `.json` ใช้ผ่าน `apply-rulesets.sh`

```bash
./apply-rulesets.sh validate <repo>       # POST แบบ disabled แล้วลบ — ตรวจ payload
./apply-rulesets.sh repo csmju-equipment  # ตั้งราย repo (ใช้ได้บน plan Free)
./apply-rulesets.sh self                  # ป้องกัน main ของ standards repo เอง
./apply-rulesets.sh org                   # ❌ 403 บน plan Free
```

**ระดับ org ใช้ไม่ได้บน plan Free** — ยืนยันแล้วว่า
`GET /orgs/CSMJU2030/rulesets` ตอบ 403 `"Upgrade to GitHub Team to enable this
feature."` แม้ token มี `admin:org` ครบ เพราะฉะนั้นทุกครั้งที่สร้าง subsystem
ใหม่ ต้องรัน `apply-rulesets.sh repo <name>` ด้วย (`new-subsystem.sh` เตือนไว้
ท้ายสคริปต์แล้ว)

`bypass_actors` ใช้ team `devops` (`actor_id` 19344982) + `OrganizationAdmin`
ทั้งคู่เป็น `bypass_mode: pull_request` บน subsystem repo — คือ bypass ได้ตอน
merge PR แต่ยัง push ตรงเข้า `main` ไม่ได้ ส่วน standards repo เป็น `always`
ระหว่าง bootstrap (ดู `ruleset-standards-repo.README.md`)

**หมายเหตุเรื่อง `actor_id`** — id ของ team ผูกกับ org นี้เท่านั้น ถ้าย้าย org
ต้องอ่านค่าใหม่: `gh api orgs/<org>/teams/devops --jq .id`

### required status check ต้องมี prefix

ชื่อ context ที่ GitHub รายงานคือ `compliance / <ชื่อ job>` เพราะ job ใน
`templates/ci.yml` ชื่อ `compliance` และ GitHub ตั้งชื่อ check ของ reusable
workflow เป็น `<caller job id> / <job name>` ใส่ชื่อ job เปล่า ๆ จะไม่ match
อะไรเลย และไม่บล็อกอะไรทั้งสิ้น — ยืนยันจากผลรันจริงบน PR #1 และ #2 ของ
`csmju-equipment`

## Allowed Actions ที่ตั้งไว้จริง

```json
{
  "github_owned_allowed": true,
  "verified_allowed": false,
  "patterns_allowed": ["pnpm/action-setup@*", "dorny/paths-filter@*", "CSMJU2030/*"]
}
```

`actions/checkout` และ `actions/setup-node` อยู่ใต้ `github_owned_allowed`
ส่วน `pnpm/action-setup@v4` ต้องอยู่ใน `patterns_allowed` ไม่งั้น job
**API Contract Sync** และ **Code Quality** จะพังตั้งแต่ step ติดตั้ง toolchain
— ทดสอบแล้วบน PR #2 ว่าตั้งค่านี้แล้วทั้ง 8 job ยังผ่าน

## Rollout order

Follow §12 of `ci-compliance-spec.md` (weeks 1–7): teams and org settings
first, then the standards repo + first scripts, then a warn-only pilot on
one subsystem, then blocking + full check coverage, then roll out to all
37 repos.
