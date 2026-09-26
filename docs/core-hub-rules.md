# Core Hub Rules — ชุดกฎและข้อยกเว้นของ `csmju-core-hub`

**เวอร์ชัน 1.0**

> เอกสารนี้ใช้กับ repo `csmju-core-hub` **เท่านั้น**
> ระบบย่อยทุกระบบยังอยู่ใต้กฎเต็มชุดตาม [`ci-compliance-spec.md`](../ci-compliance-spec.md) ไม่มีข้อยกเว้น

---

## 1. ทำไม Core Hub ต้องมีชุดกฎแยก

มาตรฐานกลางเขียนขึ้นเพื่อบังคับ **ระบบย่อย** ให้เชื่อ identity จาก Core Hub อย่างเดียว
กฎหลายข้อจึงห้ามสิ่งที่ Core Hub **ต้องทำ** ตามหน้าที่:

| ระบบย่อย | Core Hub |
|---|---|
| ห้ามออก JWT เอง — ต้องรับจาก Core Hub | เป็นผู้ออก JWT ทุกใบในแพลตฟอร์ม |
| ห้ามถือ private key | ถือ private key `core-hub-2026` และเผยแพร่ public key ผ่าน JWKS |
| ห้ามมีหน้า login | **คือ** หน้า login กลาง |
| ห้ามเป็นเจ้าของตาราง `users` — ใช้ `core_user_id` อ้างอิง | เป็นเจ้าของตาราง `users` จริง |

ถ้าเอา workflow ของระบบย่อยไปรันกับ Core Hub ตรง ๆ จะ fail ทันทีทั้งที่โค้ดถูกต้อง
เราจึงแยกเป็น **profile** แทนการปิด CI ทิ้ง — Core Hub ยังถูกตรวจ 13 งาน เหลือยกเว้นเฉพาะข้อที่ขัดกับหน้าที่

---

## 2. กลไก: `CSMJU_PROFILE`

สคริปต์ตรวจทุกตัวอ่านตัวแปรแวดล้อม `CSMJU_PROFILE` ค่าเริ่มต้นคือ `subsystem`

| ค่า | ใช้กับ | ตัวเรียก |
|---|---|---|
| `subsystem` (ค่าเริ่มต้น) | ระบบย่อยทุกระบบ | `scripts/run-all-checks.sh` · `.github/workflows/subsystem-compliance.yml` |
| `core-hub` | `csmju-core-hub` เท่านั้น | `scripts/run-core-hub-checks.sh` · `.github/workflows/core-hub-compliance.yml` |

**ห้ามระบบย่อยตั้ง `CSMJU_PROFILE=core-hub`** — workflow ของระบบย่อย hard-code ค่าเป็น `subsystem`
และ `GH-03` (ห้ามแก้ `.github/workflows/`) ปิดช่องไม่ให้ทีมแก้เอง

---

## 3. ตารางกฎ (normative)

สถานะมี 3 แบบ
**บังคับ** = ตรวจเหมือนระบบย่อยทุกประการ ·
**ผ่อน** = ยังตรวจอยู่ แต่ profile `core-hub` ขยายสิ่งที่อนุญาต ·
**ยกเว้น** = ไม่รันเลยใน workflow ของ Core Hub

| รหัส | กฎ | สถานะ | หมายเหตุ |
|---|---|---|---|
| `GH-01` | ชื่อ branch `feature/<subsystem>/<เรื่อง>` | **บังคับ** | Core Hub ใช้ `feature/core-hub/<เรื่อง>` และใช้ `develop` → `main` ตาม github-workflow.md ข้อ 1.5 (`develop` = dev server · `main` = production) |
| `GH-02` | Conventional Commits | **บังคับ** | — |
| `GH-03` | ห้ามแก้ `.github/workflows/`, `CODEOWNERS`, `standards` | **ยกเว้น** | Core Hub เป็นเจ้าของ workflow ของตัวเอง |
| `GH-04` | `.standards-version` ตรงกับ `VERSION` ของ standards | **ยกเว้น** | Core Hub ไม่ได้ผูก standards เป็น submodule |
| `SEC-01` | ห้าม commit ความลับ | **บังคับ** | รวมถึง private key — key จริงต้องมาจาก env/secret manager |
| `SEC-02` | ห้าม commit `.env` | **บังคับ** | — |
| `SEC-03` | ห้ามเก็บ token ใน `localStorage` | **บังคับ** | — |
| `SEC-04` | ต้องตรวจ JWT ผ่าน JWKS + `kid` · ห้ามออก/เซ็นเอง · ห้าม `jsonwebtoken`/`passport-jwt` | **ยกเว้น** | Core Hub เป็นผู้ออก token |
| `SEC-05` | ห้ามมีหน้า login / ฟอร์ม username-password | **ยกเว้น** | Core Hub คือหน้า login กลาง |
| `ARC-01` | frontend ห้ามต่อ DB ตรง | **บังคับ** | — |
| `ARC-02` | dependency ต้องอยู่ใน whitelist ของ stack | **ผ่อน** | เพิ่มได้เฉพาะรายการใน §4 |
| `ARC-03` | ห้าม UI library ต้องห้าม (MUI/Antd/Bootstrap) | **บังคับ** | ยังตรวจ แม้ repo นี้ยังไม่มี frontend |
| `API-01` | `openapi.json` sync กับโค้ด | **ยกเว้น (ชั่วคราว)** | Core Hub ยังไม่มีสคริปต์ `generate:openapi` — กลับมาบังคับเมื่อมี |
| `API-02` | path kebab-case ใต้ `/api/v1` | **บังคับ** | — |
| `API-03` | response envelope `{ success, data/error, meta }` | **บังคับ** | ยกเว้น JWKS (§5) |
| `API-04` | `error.code` จาก 7 ค่า | **บังคับ** | — |
| `API-05` | ต้องมี health endpoint | **บังคับ** | Core Hub ใช้ `/api/v1/health` (ระบบย่อยใช้ `/api/health`) |
| `API-06` | ประกาศ `public_endpoints` ใน `subsystem.yaml` | **ยกเว้น** | Core Hub ไม่มี `subsystem.yaml` |
| `API-07` | ห้าม `per_page` — ใช้ `page`/`limit` | **บังคับ** | — |
| `DD-01` | ห้าม alias ของ Global Identity (`user_id`, `userId`, …) | **ยกเว้น** | Core Hub เป็นเจ้าของตาราง `users` — `user_id` คือ PK/FK ปกติ |
| `DD-02` | core role ต้องอยู่ใน enum 4 ค่า | **บังคับ** | Core Hub เป็นผู้นิยาม enum นี้ |
| `DD-03` | ตาราง/คอลัมน์เป็น snake_case (`@@map`/`@map`) | **บังคับ** | — |
| `DD-04` | ห้าม hardcode รายชื่อคณะ | **บังคับ** | — |
| `DD-05` | ฟิลด์เงินห้ามเป็น float | **บังคับ** | — |
| `UI-01..04` | design tokens · ห้าม emoji | **ยกเว้น (ชั่วคราว)** | ยังไม่มี frontend ของ Core Hub ใน repo — กลับมาบังคับเมื่อมี |
| `QA-01..04` | lint · typecheck · test · build | **บังคับ** | — |
| `QA-05` | pnpm เท่านั้น | **บังคับ** | — |
| `QA-06` | ชื่อ package ไม่ซ้ำ · `--filter` ชี้ถูก | **บังคับ** | — |
| `EXC-01` | `.compliance-exceptions.yml` ต้องมี `expires` + `issue` | **บังคับ** | — |

รวม: **บังคับ 20 · ผ่อน 1 · ยกเว้น 6 · ยกเว้นชั่วคราว 2** (นับ `UI-01..04` และ `QA-01..04` เป็นกลุ่มละ 1 แถว)

---

## 4. Whitelist เพิ่มเติมของ Core Hub (`ARC-02`)

`scripts/lib/allowed-deps.json` มีคีย์ `allowed_core_hub` — ใช้ได้เฉพาะเมื่อ `CSMJU_PROFILE=core-hub`
และ **ทับ** `forbidden_everywhere` ได้เฉพาะรายการเหล่านี้:

| package | เหตุผล |
|---|---|
| `@nestjs/jwt` | ออกและเซ็น access token |
| `@nestjs/passport` · `passport` · `passport-jwt` | strategy ของ Core Hub เอง |
| `bcrypt` · `@types/bcrypt` | hash รหัสผ่านในฐานข้อมูลผู้ใช้ |
| `@types/passport-jwt` | type definitions |

แพ็กเกจนอกรายการนี้ยังถูกตีตกตามปกติ — เพิ่มได้ด้วย PR ที่แก้ `allowed-deps.json` เท่านั้น

---

## 5. ข้อกำหนดเฉพาะที่ "เข้มกว่า" ระบบย่อย

ข้อยกเว้นข้างบนไม่ได้แปลว่า Core Hub หลวมกว่า — สามข้อนี้บังคับกับ Core Hub เท่านั้น:

1. **JWKS ต้องเป็น RFC 7517 ดิบ** — `GET /api/v1/.well-known/jwks.json` ต้องคืน `{"keys":[...]}`
   โดย**ไม่**ห่อ envelope (ต้อง exclude ออกจาก response interceptor) มิฉะนั้นไลบรารีมาตรฐานอย่าง `jose` อ่านไม่ได้
2. **สัญญา JWT เปลี่ยนไม่ได้** — `alg=RS256` · `iss=core-hub` · `aud=csmju2030` · `kid=core-hub-2026` ·
   อายุ access token 15 นาที · payload `{ sub, email, role, sid, iss, aud, iat, exp }`
   การเปลี่ยนค่าเหล่านี้คือ breaking change ของทั้งแพลตฟอร์ม ต้องขึ้นเวอร์ชัน major ของ standards
3. **`callback_url` ต้องผ่านการตรวจก่อนบันทึกทะเบียน** — ต้องเป็น `https://` ยกเว้น `http://localhost`
   และ `http://127.0.0.1` เท่านั้น (กัน open redirect) ดู [`subsystem-registry.md`](subsystem-registry.md)

---

## 6. วิธีรัน

ในเครื่อง:

```bash
# จาก repo ของ standards
bash scripts/run-core-hub-checks.sh /path/to/csmju-core-hub
```

ใน CI — `csmju-core-hub/.github/workflows/ci.yml`:

```yaml
on:
  pull_request:
    branches: [main, develop]

jobs:
  compliance:
    uses: CSMJU2030/csmju2030-standards/.github/workflows/core-hub-compliance.yml@v1.0.0
```

Workflow นี้ตั้ง `CSMJU_PROFILE=core-hub` ให้เอง — repo ปลายทางไม่ต้องตั้งเอง และตั้งเองไม่ได้ผลด้วย

---

## 7. เพิ่ม/ลดข้อยกเว้น

ข้อยกเว้นในเอกสารนี้เป็น **ถาวรตามสถาปัตยกรรม** ไม่ใช่หนี้ทางเทคนิค จึงไม่ต้องมี `expires`
ต่างจาก `.compliance-exceptions.yml` ของระบบย่อยที่มีวันหมดอายุบังคับ (`EXC-01`)

การแก้ไขตารางใน §3 ต้อง:
1. แก้ `docs/core-hub-rules.md` + `scripts/run-core-hub-checks.sh` + สคริปต์ที่เกี่ยวข้องในคราวเดียว
2. เพิ่ม fixture ใน `__fixtures__/` และ assertion ใน `scripts/self-test.sh`
3. ขึ้นเวอร์ชัน standards ตาม semver — การ**เพิ่ม**ข้อยกเว้นคือ minor, การ**ลด**คือ major

---

## 8. อ้างอิง

- [`ci-compliance-spec.md`](../ci-compliance-spec.md) — กฎเต็มชุดของระบบย่อย
- [`docs/tech-stack.md`](tech-stack.md) §1.5 — สรุปข้อยกเว้นแบบสั้น
- [`docs/auth-contract.md`](auth-contract.md) — สัญญา JWT/JWKS ที่ Core Hub ต้องรักษา
- [`docs/conformance.md`](conformance.md) — การตรวจชั้น runtime ของระบบย่อย
