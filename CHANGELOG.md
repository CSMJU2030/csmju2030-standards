# Changelog

รูปแบบเวอร์ชัน: เอกสารมาตรฐานใช้ `MAJOR.MINOR` (เช่น `1.0`) · repo และ git tag ใช้ semver (`1.0.0`)
ค่า `standards_version` ใน `subsystem.yaml` ของทุกระบบย่อยต้องตรงกับ `VERSION` ของ repo นี้

---

## 1.0.3 — 2026-09-28

รุ่นในสาย **1.0.x** (ต่อจาก tag `v1.0.2`) สำหรับระบบย่อยที่ทดสอบกับ Core Hub `main` — การแก้ชุดเดียวกับ 1.4.0 บน `main`

- `scripts/check-ui-tokens.sh` (`UI-01`) และ `scripts/check-authorized-deps.sh` (`ARC-02`) **อ่าน `.compliance-exceptions.yml`**
  ตาม `ci-compliance-spec.md` ข้อ 11.1 แล้ว — ก่อนหน้านี้กระบวนการยกเว้นมีแค่ในเอกสาร ต่อให้ DevOps อนุมัติ CI ก็ยังตก
  - `UI-01`: `scope` เป็นไฟล์ หรือโฟลเดอร์ที่ลงท้ายด้วย `/` · ไฟล์อื่นตรวจตามปกติ
  - `ARC-02`: ต้องระบุ `package.json` + `dependency` · ไม่ยกเว้น `ARC-03`
  - exception ที่ไม่มี `issue` / `scope: "*"` / หมดอายุ ไม่มีผล · exception ที่มีผลขึ้น warning ทุกครั้ง
  - ตัวอ่านอยู่ที่ `scripts/lib/exceptions.sh` (bash ล้วน รันบน bash 3.2 ได้)
- `docs/tech-stack.md` ข้อ 1.1 — pnpm เลขเดียวทั้งโครงการ: **`12.3.4`** ตรงกับ Core Hub และ demo
- fixture `UI-01-EXC` · `UI-01-EXC-EXPIRED` · `ARC-02-EXC` + `scripts/self-test.sh`

**ใครต้องทำอะไร:** ไม่มีกฎที่เข้มขึ้น · ระบบย่อยที่ได้รับอนุมัติข้อยกเว้น (เช่น ภาพของเกม · แพ็กเกจที่ใช้ร่วมกันในรีโปเดียวกัน)
ให้ DevOps/PM เพิ่มรายการใน `.compliance-exceptions.yml` ของ repo นั้น (มี `issue` และ `expires` เสมอ) แล้วเลื่อน pin เป็น 1.0.3 ·
repo ที่ยังใช้ pnpm รุ่นอื่นให้ตั้ง `packageManager` เป็น `pnpm@12.3.4` แล้วรัน `pnpm install` ใหม่หนึ่งครั้ง

---

## 1.0.2 — 2026-09-28

รุ่นในสาย **1.0.x** สำหรับระบบย่อยที่ทดสอบกับ Core Hub `main` (SSO 1.0 — เข้าระบบจาก portal ของ Core Hub ผ่าน `/api/sso/<ชื่อ>`)
ออกต่อจาก tag `v1.0.1` โดยตรงแบบเดียวกับที่ 1.0.1 ออกจาก `v1.0.0` จึง**ไม่รวม**งานของ 1.1.0 ขึ้นไปบน `main`
(SSO 1.1 ที่เริ่มจาก `GET /auth/login` ของระบบย่อย · error code 9 ค่า · conformance L3-16..22) ซึ่ง Core Hub `main` ยังไม่รองรับ

- `scripts/lib/allowed-deps.json` — อนุญาต frontend เพิ่ม 4 ตัว (PM อนุมัติ 28 ก.ย. ชุดเดียวกับ 1.2.1 บน `main`):
  `lucide-react` (ไอคอน · ISC) · `leaflet` (แผนที่ · BSD-2-Clause) · `qrcode.react` (QR · ISC) ·
  `@tailwindcss/postcss` (Tailwind v4 · MIT — อยู่ทั้ง `allowed_frontend` และ `allowed_dev_tooling` แบบเดียวกับ `tailwindcss`)
- **`react-leaflet` ไม่อนุญาต** — ใช้ license Hippocratic-2.1 ซึ่งไม่ผ่าน OSI · ให้เรียก `leaflet` ตรง ๆ
  (ตัวอย่าง client component ใน `docs/tech-stack.md` ข้อ 1.4.2)
- `scripts/check-ui-tokens.sh` (`UI-01`..`UI-04`) — นำตัว scan ของ `main` (1.1.0) มาใช้: ตรวจทั้ง `frontend/` ไม่ใช่แค่ `frontend/src`
  และยกเว้นไฟล์ token กลาง (`globals.css` · โฟลเดอร์ `csmju/`) ที่ประกาศสีเป็น hex ใน `@theme` ของ Tailwind v4
  ถ้าไม่มีข้อนี้ ระบบย่อยที่ย้ายไป Tailwind v4 ตามที่อนุมัติจะตก `UI-01` ที่ไฟล์ token ของตัวเอง ·
  token จาก `@csmju2030/design-system` ยังผ่านเหมือนเดิม
- `scripts/check-api-conventions.sh` · `scripts/check-no-jwt-verify.sh` — เลิกใช้ `find | head -1` ซึ่งทำให้สคริปต์จบเงียบ ๆ
  ด้วย SIGPIPE บน CI (Linux) เมื่อ `backend/src` มีไฟล์มาก (การแก้เดียวกับ 1.1.1 บน `main`)
- `docs/tech-stack.md` ข้อ 1.2 และ 1.4.2 (ใหม่) · `ci-compliance-spec.md` ข้อ 7.3 — อัปเดตให้ตรงกับ whitelist
  พร้อมข้อกำหนดแผนที่ (แสดง attribution ของ OpenStreetMap · เพิ่มโดเมน tile ใน CSP) และ QR (ใส่ได้เฉพาะข้อมูลสาธารณะ)
- fixture `ARC-02-MAP` · `UI-01` (ไฟล์ token) · `UI-01-NOSRC` และชุดทดสอบ SIGPIPE ใน `scripts/self-test.sh`

**ใครต้องทำอะไร:** ระบบย่อยที่ทดสอบกับ Core Hub `main` ให้ขอ PL เลื่อนเป็น 1.0.2 ได้แก่ pin ใน `ci.yml` (`@v1.0.2`) ·
submodule `standards` (tag `v1.0.2`) · `.standards-version` · `standards_version` ใน `subsystem.yaml`
repo ที่มี `app/` อยู่ที่ราก `frontend/` จะถูกตรวจ `UI-01` จริงเป็นครั้งแรก — hex ดิบนอกไฟล์ token จะตก ·
ระบบย่อยที่ผูก 1.1.0 ขึ้นไปต้องทดสอบกับ Core Hub `develop` ไม่ใช่ `main`

---

## 1.0.1 — 2026-09-26

- `scripts/lib/allowed-deps.json` — เพิ่ม `@nestjs/schedule` ใน `allowed_backend` สำหรับงานตั้งเวลา (scheduled job)
  มาจากคำขอของทีม CampusShare ที่มีงานตั้งเวลา 3 งาน (ยกเลิกคำขอยืมที่เจ้าของไม่ตอบ · ติดธงคำขอที่เกินกำหนดคืน ·
  เก็บ listing ที่ไม่มีความเคลื่อนไหวเกิน 180 วัน) เลือกเพิ่มเข้า whitelist แทนการทำ exception รายทีม
  เพราะเป็นแพ็กเกจทางการของ NestJS และระบบย่อยอื่นน่าจะต้องใช้งานแบบเดียวกัน
- `docs/tech-stack.md` ข้อ 1.4.1 (ใหม่) — กติกาของงานตั้งเวลา 3 ข้อ: รันซ้ำได้โดยไม่เสียหาย · ระบุ time zone ·
  ถ้ารันหลาย instance ให้ใช้ advisory lock ของ PostgreSQL
- fixture `__fixtures__/ARC-02-03/pass` ใช้ `@nestjs/schedule` เพื่อพิสูจน์ว่า `ARC-02` ยอมรับ

ออกจาก tag `v1.0.0` โดยตรง จึง**ไม่รวม**งานที่ค้างอยู่บน `main` หลัง 1.0.0 (เช่น `UI-01`..`UI-04` ที่ตรวจทั้ง `frontend/`)
งานเหล่านั้นจะออกในเวอร์ชันถัดไป

**ระบบย่อยต้องทำอะไร:** ถ้าต้องใช้ `@nestjs/schedule` ให้ขอ PL เลื่อนเป็น 1.0.1 ได้แก่ pin ใน `ci.yml` · submodule `standards` ·
`.standards-version` · `standards_version` ใน `subsystem.yaml` · ระบบย่อยอื่นไม่ต้องทำอะไร

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
