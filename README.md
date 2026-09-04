# csmju2030-standards

มาตรฐานกลางและ automated compliance gate ของโครงการ **CSMJU2030**
(ระบบ MIS สาขาวิชาวิทยาการคอมพิวเตอร์ — 1 ระบบย่อย = 1 repo)

repo นี้เป็นแหล่งความจริงเพียงแหล่งเดียวของกฎที่ทุกระบบย่อยต้องทำตาม
และเป็นที่อยู่ของสคริปต์ที่ CI ใช้ตรวจจริง ระบบย่อยไม่ต้องคัดลอกกฎไปเก็บเอง
แค่ชี้มาที่นี่

**เวอร์ชันปัจจุบัน:** ดู [`VERSION`](VERSION) · การเปลี่ยนแปลง: [`CHANGELOG.md`](CHANGELOG.md)

---

## ถ้าคุณเป็น AIE (คนเขียนโค้ดระบบย่อย)

อ่าน 3 ไฟล์นี้ก่อนเริ่ม แล้วค่อยกลับมาดูตัวอื่นเมื่อต้องใช้

| อ่านเพื่อ | ไฟล์ |
|---|---|
| วิธีแตก branch, ตั้งชื่อ commit, เปิด PR | [`docs/github-workflow.md`](docs/github-workflow.md) ข้อ 1 |
| stack ที่อนุญาต และกฎ Database Isolation | [`docs/tech-stack.md`](docs/tech-stack.md) |
| รูปแบบ API ที่ต้องทำตาม | [`docs/api-conventions.md`](docs/api-conventions.md) |

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
./standards/scripts/run-all-checks.sh .
```
ได้ผลเหมือน CI ทุกข้อ แต่เร็วกว่า และไม่ต้องรอคิว runner

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
docs/              เอกสารมาตรฐาน — คนอ่าน ไม่มีสคริปต์ไหนอ่านไฟล์พวกนี้
scripts/           กฎที่บังคับจริง (check-*.sh) + self-test + run-all-checks
scripts/lib/       allowed-deps.json — whitelist dependency
schemas/           JSON Schema ของ shared data
templates/         ไฟล์ที่ทุก subsystem repo ต้องมีเหมือนกัน (ci.yml, CODEOWNERS, …)
org-settings/      ruleset + checklist ที่ต้องตั้งในหน้า Settings ของ GitHub
__fixtures__/      ตัวอย่าง pass/fail สำหรับ self-test
.github/workflows/ subsystem-compliance.yml (reusable) + self-test.yml
```

**จุดที่มักเข้าใจสลับกัน:** ไฟล์ `.yml` รายงานผ่าน/ไม่ผ่านได้เท่านั้น
มันห้าม merge ไม่ได้ด้วยตัวเอง สิ่งที่ห้ามได้จริงคือ required status checks
ใน ruleset ซึ่งเป็น setting บน GitHub ไม่ใช่ไฟล์ในโค้ด

---

## จะแก้กฎหรือเอกสาร ทำอย่างไร

กฎอยู่ใน `scripts/` เอกสารอยู่ใน `docs/` — สองอย่างนี้ต้องตรงกันเสมอ
ถ้าไม่ตรง จะเกิดสภาพ "ทำตามเอกสารแล้ว CI ตีตก" ซึ่งเคยเกิดจริงมาแล้ว 4 จุด
(ดู `CHANGELOG.md` 1.3.0)

ลำดับที่ต้องทำใน PR เดียว

1. แก้เอกสารใน `docs/` และระบุ errata ว่าแก้อะไรเพราะอะไร
2. แก้สคริปต์ใน `scripts/` ให้ตรงกับเอกสาร
3. เพิ่ม fixture `__fixtures__/<รหัสกฎ>/{pass,fail}` ที่พิสูจน์กฎใหม่
4. `./scripts/self-test.sh` ต้องผ่าน
5. bump `VERSION` + เขียน `CHANGELOG.md`
6. ติด tag ใหม่ แล้วแจ้งให้แต่ละ subsystem เลื่อน pin ใน `ci.yml`
   และ `.standards-version` ตามจังหวะตัวเอง

subsystem ปักหมุดเวอร์ชันไว้ (`@v1.3.0`) จึงไม่มีใครถูกเปลี่ยนกฎกลางคันโดยไม่รู้ตัว

---

## สถานะที่ยังไม่เสร็จ

| เรื่อง | สถานะ |
|---|---|
| `docs/ui-prompt-template.md` | ยังเป็น stub รอเจ้าของส่งฉบับจริง |
| Teams (`devops`, `pm`, `pl-*`, `aie-*`) | ยังไม่ได้สร้าง — `bypass_actors` ใช้ `OrganizationAdmin` ชั่วคราว |
| ruleset ระดับ org | ต้องมี scope `admin:org` และอาจต้องมี plan Team |
| org settings ตาม checklist | ยังไม่ได้ตั้ง |
| standards repo เป็น private | ยังไม่ได้ — ต้องทำ GitHub App ก่อน (เหตุผลใน `new-subsystem.sh`) |
