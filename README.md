# csmju2030-standards

มาตรฐานกลางและ automated compliance gate ของโครงการ **CSMJU2030**
(ระบบ MIS สาขาวิชาวิทยาการคอมพิวเตอร์ — 1 ระบบย่อย = 1 repo)

repo นี้เป็นแหล่งความจริงเพียงแหล่งเดียวของกฎที่ทุกระบบย่อยต้องทำตาม
และเป็นที่อยู่ของสคริปต์ที่ CI ใช้ตรวจจริง ระบบย่อยไม่ต้องคัดลอกกฎไปเก็บเอง
แค่ชี้มาที่นี่

**เวอร์ชันปัจจุบัน:** ดู [`VERSION`](VERSION) · การเปลี่ยนแปลง: [`CHANGELOG.md`](CHANGELOG.md)

มาตรฐาน v1.0 เขียนจาก **ระบบที่ทำงานได้จริง** ไม่ใช่จากการออกแบบล่วงหน้า:
`csmju-core-hub` (Core Hub จริง) และ `demo-student-subsystem`
(reference implementation ที่ผ่าน conformance L3 · 62/62)

---

## ถ้าคุณเป็น AIE (คนเขียนโค้ดระบบย่อย)

อ่าน 3 ไฟล์นี้ก่อนเริ่ม แล้วค่อยกลับมาดูตัวอื่นเมื่อต้องใช้

| อ่านเพื่อ | ไฟล์ |
|---|---|
| **เริ่มที่นี่** — ภาพรวมและสถานะจริงของสถาปัตยกรรม | [`docs/overview.md`](docs/overview.md) |
| JWT · JWKS · SSO · callback | [`docs/auth-contract.md`](docs/auth-contract.md) |
| role mapping · permission · 401/403 | [`docs/authorization.md`](docs/authorization.md) |
| stack ที่บังคับ + เวอร์ชัน และกฎ Database Isolation | [`docs/tech-stack.md`](docs/tech-stack.md) |
| รูปแบบ API ที่ต้องทำตาม | [`docs/api-conventions.md`](docs/api-conventions.md) |
| ชื่อตาราง/คอลัมน์ · migration | [`docs/data-dictionary.md`](docs/data-dictionary.md) |
| ลงทะเบียนระบบย่อยกับ Core Hub | [`docs/subsystem-registry.md`](docs/subsystem-registry.md) |
| เกณฑ์ผ่าน/ไม่ผ่าน และวิธีรัน | [`docs/conformance.md`](docs/conformance.md) |
| วิธีแตก branch, ตั้งชื่อ commit, เปิด PR | [`docs/github-workflow.md`](docs/github-workflow.md) ข้อ 1 |
| กฎของ Core Hub และข้อยกเว้น (ทีม Core Hub เท่านั้น) | [`docs/core-hub-rules.md`](docs/core-hub-rules.md) |
| ใช้ AI ช่วยเขียนโค้ด | [`ai/AGENTS.md`](ai/AGENTS.md) · [`ai/TASK_TEMPLATE.md`](ai/TASK_TEMPLATE.md) |

ขั้นตอนทำงานปกติ

```bash
git submodule update --remote standards/      # ดึงมาตรฐานล่าสุดก่อนเริ่มทุกวัน
git checkout -b feature/<subsystem>/<เรื่องที่ทำ>
# ...เขียนโค้ด...
git commit -m "feat(<subsystem>): <คำอธิบาย>"
git push origin feature/<subsystem>/<เรื่องที่ทำ>
gh pr create --base main
```

### ตรวจเองก่อนเปิด PR (ไม่ต้องรอ CI)

```bash
./standards/scripts/run-all-checks.sh .        # static — ได้ผลเหมือน CI ทุกข้อ
node standards/conformance/run.js              # runtime — ยิงระบบที่รันอยู่จริง
```

> ทีม Core Hub ใช้ `./scripts/run-core-hub-checks.sh /path/to/csmju-core-hub` แทน — มันตั้ง
> `CSMJU_PROFILE=core-hub` และข้ามกฎที่ขัดกับหน้าที่ของ Core Hub ตาม [`docs/core-hub-rules.md`](docs/core-hub-rules.md)

การตรวจมี **สองชั้น** และต้องผ่านทั้งคู่:

| ชั้น | ตรวจอะไร | รันเมื่อไร |
|---|---|---|
| `scripts/` (static) | ซอร์สโค้ด: naming · dependency · secret · commit · openapi sync | ทุก PR |
| `conformance/` (runtime) | พฤติกรรมจริงผ่าน HTTP ตามสัญญา (L1/L2/L3) | nightly + ก่อน release |

CI ตรวจว่า "เขียนถูกกฎ" · conformance ตรวจว่า "ทำงานได้จริงตามสัญญา"

---

## กฎที่ CI บังคับ

ทุก PR ที่เข้า `main` จะรัน 8 job นี้ ต้องเขียวหมดจึง merge ได้

| Job | ตรวจอะไร |
|---|---|
| Convention Check | ชื่อ branch, commit message, ห้ามแก้ไฟล์ CI เอง |
| Standards Version Check | `.standards-version` ตรงกับเวอร์ชันที่ PM อนุมัติ |
| Security & Stack Scan | secret, token ใน localStorage, JWT verify เอง, DB isolation, dependency นอก whitelist |
| API Contract Sync | `openapi.json` sync กับโค้ด, รูปแบบ API |
| Data Dictionary Compliance | ชื่อฟิลด์ต้องห้าม, snake_case, รายชื่อคณะ hardcode, ฟิลด์เงินเป็น float |
| UI Token Compliance | สีดิบแทน design token |
| Code Quality | lint, typecheck, unit test, build, บังคับ pnpm |
| Exception Validation | `.compliance-exceptions.yml` ถูกต้องและไม่หมดอายุ |

กฎแต่ละข้อมีรหัสกำกับ (`SEC-01`, `DD-04`, `QA-03` …) เวลา CI ตีตกจะบอกรหัส
ข้อความ พร้อมชี้ว่าอ้างอิงเอกสารข้อไหน และวิธีแก้

รายละเอียดกฎทุกข้อ: [`ci-compliance-spec.md`](ci-compliance-spec.md) §7

---

## ถ้าคุณเป็น DevOps

### สร้างระบบย่อยใหม่

```bash
./new-subsystem.sh payroll "ระบบเงินเดือน"
```
สร้างโครงไฟล์, ตรวจ compliance กับของที่สร้าง, สร้าง repo บน GitHub, push,
แล้วผูก standards submodule ให้ — ถ้า scaffold ไม่ผ่าน compliance
จะหยุดก่อนสร้างอะไรบน GitHub

### ตั้ง branch protection

```bash
./org-settings/apply-rulesets.sh validate <repo>   # ลองยิง payload แบบ disabled แล้วลบ
./org-settings/apply-rulesets.sh repo csmju-payroll
./org-settings/apply-rulesets.sh org               # ต้องมี scope admin:org
```

งานตั้งค่าระดับ organization ที่สคริปต์ทำแทนไม่ได้ อยู่ใน
[`org-settings/org-settings-checklist.md`](org-settings/org-settings-checklist.md)

### ทดสอบว่าสคริปต์ยังทำงานถูก

```bash
./scripts/self-test.sh
```
รันทุก check กับ fixture pass/fail ใน `__fixtures__/` แล้วเทียบ exit code
**ทุก PR ที่แก้ `scripts/` ต้องให้ชุดนี้ผ่านก่อน**

---

## โครงสร้าง repo

```
docs/              เอกสารมาตรฐาน — คนอ่าน
ai/                กติกา + เทมเพลตสั่งงาน AI + checklist ส่งงาน
contracts/         สัญญาที่เครื่องอ่านได้ (jwt · error-codes · vocabulary · log-events · openapi)
conformance/       ชุดทดสอบ runtime แบบ black-box (Node 20+ ไม่มี dependency)
scripts/           กฎที่บังคับจริง (check-*.sh) + self-test + run-all-checks + run-core-hub-checks
scripts/lib/       allowed-deps.json — whitelist dependency
schemas/           JSON Schema ของ shared data + subsystem.yaml
fixtures/          บัญชี dev ของ Core Hub + manifest ตัวอย่าง (ใช้กับ conformance)
templates/         ไฟล์ที่ทุก subsystem repo ต้องมีเหมือนกัน (subsystem.yaml, ci.yml, …)
org-settings/      ruleset + checklist ที่ต้องตั้งในหน้า Settings ของ GitHub
__fixtures__/      ตัวอย่าง pass/fail สำหรับ self-test
.github/workflows/ subsystem-compliance.yml · core-hub-compliance.yml (reusable) · conformance-nightly.yml · self-test.yml
```

> `docs/` คนอ่าน · `contracts/` เครื่องอ่าน · ถ้าสองอย่างขัดกันให้ยึด `contracts/` แล้วแจ้ง PL

**จุดที่มักเข้าใจสลับกัน:** ไฟล์ `.yml` รายงานผ่าน/ไม่ผ่านได้เท่านั้น
มันห้าม merge ไม่ได้ด้วยตัวเอง สิ่งที่ห้ามได้จริงคือ required status checks
ใน ruleset ซึ่งเป็น setting บน GitHub ไม่ใช่ไฟล์ในโค้ด

---

## จะแก้กฎหรือเอกสาร ทำอย่างไร

กฎอยู่ใน `scripts/` เอกสารอยู่ใน `docs/` — สองอย่างนี้ต้องตรงกันเสมอ
ถ้าไม่ตรง จะเกิดสภาพ "ทำตามเอกสารแล้ว CI ตีตก" หรือแย่กว่านั้นคือ
"ทำตามเอกสารแล้วต่อกับ Core Hub จริงไม่ได้" ซึ่งเป็นเหตุผลที่ v1.0 เขียนใหม่
จากระบบที่รันได้จริงทั้งหมด (ดู `CHANGELOG.md` 1.0.0)

ลำดับที่ต้องทำใน PR เดียว

1. แก้เอกสารใน `docs/` และระบุ errata ว่าแก้อะไรเพราะอะไร
2. แก้สคริปต์ใน `scripts/` ให้ตรงกับเอกสาร
3. เพิ่ม fixture `__fixtures__/<รหัสกฎ>/{pass,fail}` ที่พิสูจน์กฎใหม่
4. `./scripts/self-test.sh` ต้องผ่าน
5. bump `VERSION` + เขียน `CHANGELOG.md`
6. ติด tag ใหม่ แล้วแจ้งให้แต่ละ subsystem เลื่อน pin ใน `ci.yml`
   และ `.standards-version` ตามจังหวะตัวเอง

subsystem ปักหมุดเวอร์ชันไว้ (`@v1.0.0`) จึงไม่มีใครถูกเปลี่ยนกฎกลางคันโดยไม่รู้ตัว

---

## สถานะที่ยังไม่เสร็จ

ยืนยันแล้วว่าใช้งานได้จริง: PR ทดสอบบน `csmju-equipment` (#1 และ #2) รันครบ
ทั้ง 8 job ผ่านหมด และ `mergeStateStatus` เป็น `BLOCKED` เพราะรอ review ตามที่
ตั้งใจ — คือ gate บล็อก merge ได้จริง ไม่ใช่แค่รายงานผล

| เรื่อง | สถานะ |
|---|---|
| Teams `devops` `pm` `pl-equipment` `aie-equipment` | ✅ สร้างและผูกสิทธิ์แล้ว |
| org settings, Actions allow-list, secret scanning, Dependabot | ✅ ตั้งแล้ว — รายละเอียดใน `org-settings/org-settings-checklist.md` |
| ruleset ระดับ repo | ✅ ทั้ง 2 repo |
| **ruleset ระดับ org** | ❌ ต้องมี plan **GitHub Team** — API ตอบ 403 ตรง ๆ บน Free ต้องรัน `apply-rulesets.sh repo <name>` ทุกครั้งที่สร้าง subsystem ใหม่ |
| Require 2FA / ห้าม member ลบ repo / เปลี่ยน visibility | ⬜ ต้องตั้งในหน้าเว็บ |
| `docs/ui-prompt-template.md` | ⬜ ยังเป็น stub รอเจ้าของส่งฉบับจริง (อีก 6 ฉบับเป็นของจริงแล้ว) |
| สมาชิกจริงใน team `pl-*` / `aie-*` | ⬜ ยังมีแค่เจ้าของ org — จนกว่าจะมีคนจริง PR จะ approve ไม่ได้นอกจากใช้ bypass ของ devops |
| standards repo เป็น private | ⬜ ต้องทำ GitHub App ก่อน (เหตุผลอยู่ในหัว `new-subsystem.sh`) |
