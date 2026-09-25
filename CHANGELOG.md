# Changelog

รูปแบบเวอร์ชัน: เอกสารมาตรฐานใช้ `MAJOR.MINOR` (เช่น `1.0`) · repo และ git tag ใช้ semver (`1.0.0`)
ค่า `standards_version` ใน `subsystem.yaml` ของทุกระบบย่อยต้องตรงกับ `VERSION` ของ repo นี้

---

## ยังไม่ออกเวอร์ชัน

- `scripts/check-ui-tokens.sh` (`UI-01`..`UI-04`) — สแกนทั้ง `frontend/` แทน `frontend/src`
  เดิมถ้า Next.js วาง `app/` ไว้ที่ราก `frontend/` สคริปต์จะไม่เจอไฟล์ไหนเลยแล้วผ่านเฉย ๆ
  (fixture ใหม่ `__fixtures__/UI-01-NOSRC`) · ยกเว้นไฟล์ token กลาง `globals.css` และ `csmju/`
  จาก template ซึ่งประกาศสีเป็น hex โดยตั้งใจ — เดิม `globals.css` ใต้ `src/` ทำให้ `UI-01` ตกเอง
- ข้อความ `UI-01` และ `SEC-03` ชี้ไป `ui-design-system.md` แทน `ui-prompt-template.md`
  ที่ถูกรวมเข้าไปแล้ว (เช่นเดียวกับตารางกฎใน `ci-compliance-spec.md` ข้อ 7)
- ชื่อ token: เลิกใช้ `--csmju-*` ใน `aie-workflow.md`, `ci-compliance-spec.md`,
  `templates/pull_request_template.md` ให้ตรงกับ `ui-design-system.md` ข้อ 3
  (Tailwind v4 `@theme` เช่น `bg-primary-container`)
- `ui-design-system.md` ข้อ 16.1 — ใช้ `frontend/` + `backend/` ตาม `repo-structure.md`
  (เดิมเขียน `web/` + `api/`) · ข้อ 17.0 — ระบุว่า template `csmju-subsystem-web` อยู่ใน repo
  `csmju-core-hub` และให้ copy ลง `frontend/` ด้วย `pnpm` แทนการแยก repo `-web` ด้วย `npm`

---

## Errata ของ 1.0.0 — 2026-09-23

แก้เอกสารเท่านั้น ไม่มีการเปลี่ยนกฎหรือสคริปต์ตรวจ จึงไม่ขึ้นเวอร์ชัน
(`VERSION` ยังเป็น `1.0.0` ระบบย่อยไม่ต้องเลื่อน `.standards-version`)

- `tech-stack.md` ข้อ 1.2.1 (ใหม่) — `typecheck` ของ frontend ต้องเป็น
  `next typegen && tsc --noEmit` ไม่ใช่ `tsc --noEmit` เฉย ๆ
  Next.js สร้าง type ของ route/layout (`LayoutProps`, `PageProps`) ตอน dev/build
  เท่านั้น สคริปต์แบบเดิมจึงผ่านในเครื่อง (มี `.next/` ค้าง) แต่ตกบน CI ที่ checkout
  ใหม่ด้วย `TS2304: Cannot find name 'LayoutProps'` — เจอจริงตอนทำ frontend ของ Core Hub
- `tech-stack.md` ข้อ 1.2 — ระบุ Next.js เป็น `15.5+` เพราะ `next typegen` เพิ่งมีในเวอร์ชันนั้น
- `ai/AGENTS.md` — เพิ่มลงตาราง "สิ่งที่ agent มักทำผิด" และเพิ่มคำสั่ง
  `rm -rf frontend/.next && pnpm -r typecheck` ในชุดคำสั่งที่ต้องรันก่อนส่งงาน

---

## 1.0.0 — 2026-09-11

**เวอร์ชันแรกที่ประกาศใช้จริง** — เริ่มนับใหม่ที่ 1.0.0

> เวอร์ชัน 1.0.0–1.3.0 ก่อนหน้านี้เป็นช่วงเตรียมการ ยังไม่เคยส่งมอบให้ทีม AIE ทีมใดใช้งาน
> และยังไม่มีระบบย่อยใดผูกอยู่ จึงยกเลิกประวัติเดิมทั้งหมดแล้วเริ่มนับใหม่
> ไม่ถือเป็น breaking change เพราะไม่มีผู้ใช้เดิม

### ที่มาของเนื้อหา

มาตรฐานฉบับนี้เขียนจาก **ระบบที่ทำงานได้จริงและผ่านการทดสอบแล้ว** ไม่ใช่จากการออกแบบล่วงหน้า:

| อ้างอิงจาก | สถานะ |
|---|---|
| `csmju-core-hub` | Core Hub จริง — login · RS256 · JWKS · Subsystem Registry · Central SSO (unit 35 เคส) |
| `demo-student-subsystem` | reference implementation — unit 77 · e2e 70 · integration 13 · conformance 62/62 |

ทุกข้อกำหนดในเอกสารนี้มีโค้ดที่ทำได้จริงรองรับ และมีชุดทดสอบที่ยิงระบบจริงเป็นตัวพิสูจน์

### สัญญาการยืนยันตัวตน (`docs/auth-contract.md` — เขียนใหม่ทั้งฉบับ)

- Core Hub ออก JWT **RS256** · `iss=core-hub` · `aud=csmju2030` · `kid=core-hub-2026` · อายุ 15 นาที
- เผยแพร่กุญแจสาธารณะที่ `/api/v1/.well-known/jwks.json` แบบ **RFC 7517 ดิบ**
- **ระบบย่อยเป็นผู้ตรวจ JWT เอง** ผ่าน JWKS (8 ขั้น) — ยังไม่มี API Gateway ในสถาปัตยกรรมปัจจุบัน
- Central SSO: `GET /api/v1/auth/sso/authorize` → 302 ไปยัง `callback_url` ที่ลงทะเบียนไว้เท่านั้น
- ระบบย่อยรับที่ `GET /auth/callback` แล้วตั้งคุกกี้ HttpOnly ของตัวเอง

### สิทธิ์ (`docs/authorization.md` — ใหม่)

- Core Hub ตัดสิน *ใครเข้าระบบไหนได้* (ตรวจ core role กับ `default_role_mapping` ก่อน redirect)
- ระบบย่อยตัดสิน *เข้ามาแล้วทำอะไรได้* ผ่านชั้น permission `resource:action[:own|:any]`
- แยก `401` (ไม่รู้ว่าใคร) กับ `403` (รู้แล้วแต่สิทธิ์ไม่พอ) อย่างเคร่งครัด

### สัญญา API (`docs/api-conventions.md`)

- pagination เป็น `?page=1&limit=20` (จากเดิม `per_page`)
- `VALIDATION_ERROR` คืน **400** (จากเดิม 422) ให้ตรงกับพฤติกรรม `ValidationPipe` ของ NestJS
- field ใน JSON เป็น `camelCase` · ฐานข้อมูลเป็น `snake_case` (แยกชั้นกันชัดเจน)
- เพิ่มกฎ URL: resource เป็นพหูพจน์ `kebab-case` · `POST`→201 · `DELETE`→200 + `{id, deleted:true}`

### ฐานข้อมูล (`docs/data-dictionary.md`)

- ตาราง/คอลัมน์เป็น `snake_case` ผ่าน `@map`/`@@map` · field ใน Prisma เป็น `camelCase`
- ห้ามลบหรือ squash migration · เปลี่ยนชื่อคอลัมน์ต้องใช้ `RENAME COLUMN` ไม่ใช่ drop+add

### Tech stack (`docs/tech-stack.md`)

- ระบุเวอร์ชันที่ใช้จริง: Node 22 · NestJS 11 · TypeScript 5.9 · **Prisma 7.9.1 (pin)** · PostgreSQL 16+
- แก้ whitelist ที่ทำให้ Prisma 7 ใช้ไม่ได้ — เพิ่ม `@prisma/adapter-pg`, `pg`, `jose`, `dotenv`

### เครื่องมือใหม่

- `conformance/` — ชุดทดสอบ **runtime** แบบ black-box ไม่มี dependency (L1 32 · L2 47 · L3 62 เคส)
- `contracts/` — สัญญาที่เครื่องอ่านได้ (JWT · error code · vocabulary · log event · OpenAPI)
- `ai/` — `AGENTS.md`, `TASK_TEMPLATE.md`, `CHECKLIST.md` สำหรับสั่งงาน AI ให้ได้ผลตรงกันข้ามโมเดล

### Profile `core-hub` (`docs/core-hub-rules.md` — ใหม่)

- `csmju-core-hub` ไม่ใช่ระบบย่อย จึงมี workflow แยก `core-hub-compliance.yml` ที่ตั้ง `CSMJU_PROFILE=core-hub`
- ยกเว้นเฉพาะกฎที่ขัดกับหน้าที่ของมันเอง: `SEC-04` `SEC-05` `GH-03` `GH-04` `API-01` `API-06` `UI-01..04`
  · `DD-01` ถูกข้ามในสคริปต์ · `ARC-02` ขยาย whitelist ด้วยคีย์ `allowed_core_hub`
- กฎที่เหลือ 19 ข้อยังบังคับเต็มเหมือนระบบย่อย และมี 3 ข้อที่เข้มกว่า (JWKS ดิบ · สัญญา JWT ห้ามเปลี่ยน · ตรวจ `callback_url`)
- self-test ยืนยันทั้งสองทิศทาง: fixture เดียวกันต้องตกใน profile `subsystem` และผ่านใน `core-hub`
  รวมถึงยืนยันว่าค่าเริ่มต้นคือ `subsystem` และ workflow ของระบบย่อยไม่ส่ง profile นี้ (45 assertions)

### กฎใหม่

- `QA-06` — ชื่อ package ในแต่ละ workspace ต้องไม่ซ้ำ และ `--filter <name>` ใน script ที่รากต้องชี้ไปยัง
  package ที่มีอยู่จริง มิฉะนั้น pnpm จะไม่รันอะไรเลยแต่คืน exit 0 ทำให้ script ที่รากดูเหมือนผ่าน
  (พบจริงใน `demo-student-subsystem` — root กับ backend ตั้งชื่อซ้ำกัน `pnpm test` ที่รากจึงไม่ได้รันเทสต์)

### แก้บั๊กในเครื่องมือตรวจเอง

- `API-02` เคยตีตกชื่อ path parameter แบบ camelCase (`:exceptionId`) ทั้งที่ URL จริงยังเป็น kebab-case
- `pnpm/action-setup` ฮาร์ดโค้ด `version: 9` ซึ่งชนกับ `packageManager` ใน `package.json` ของ repo ที่เรียก
- `node_version` ค่าเริ่มต้นเป็น `20` ทั้งที่ `tech-stack.md` ล็อก Node 22
- `run-all-checks.sh` ใช้ associative array ซึ่ง bash 3.2 (ค่าเริ่มต้นของ macOS) ไม่รองรับ

### กฎ CI ที่แก้ให้ตรงกับสถาปัตยกรรมจริง

| รหัส | เดิม | ใหม่ |
|---|---|---|
| `SEC-04` | ห้ามระบบย่อย verify JWT เอง | **ต้อง** verify ด้วย JWKS + `kid` · ห้าม HS256 / secret / กุญแจฮาร์ดโค้ด |
| `DD-03` | บังคับ `snake_case` กับ field ใน TypeScript | บังคับกับ **ฐานข้อมูล** เท่านั้น (`@map`) · JSON/TS ยังเป็น camelCase |
| `ARC-02` | whitelist ไม่มี dependency ที่ Prisma 7 ต้องใช้ | เพิ่มให้ครบ |
| `API-*` | `per_page` · `VALIDATION_ERROR` = 422 | `limit` · 400 |
