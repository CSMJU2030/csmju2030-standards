# Changelog

รูปแบบเวอร์ชัน: เอกสารมาตรฐานใช้ `MAJOR.MINOR` (เช่น `1.0`) · repo และ git tag ใช้ semver (`1.0.0`)
ค่า `standards_version` ใน `subsystem.yaml` ของทุกระบบย่อยต้องตรงกับ `VERSION` ของ repo นี้

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

### กฎ CI ที่แก้ให้ตรงกับสถาปัตยกรรมจริง

| รหัส | เดิม | ใหม่ |
|---|---|---|
| `SEC-04` | ห้ามระบบย่อย verify JWT เอง | **ต้อง** verify ด้วย JWKS + `kid` · ห้าม HS256 / secret / กุญแจฮาร์ดโค้ด |
| `DD-03` | บังคับ `snake_case` กับ field ใน TypeScript | บังคับกับ **ฐานข้อมูล** เท่านั้น (`@map`) · JSON/TS ยังเป็น camelCase |
| `ARC-02` | whitelist ไม่มี dependency ที่ Prisma 7 ต้องใช้ | เพิ่มให้ครบ |
| `API-*` | `per_page` · `VALIDATION_ERROR` = 422 | `limit` · 400 |
