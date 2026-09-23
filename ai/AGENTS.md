# AGENTS.md — กติกาสำหรับ AI Agent ที่พัฒนาระบบย่อย CSMJU2030

> เขียนสำหรับ **AI coding agent** (Claude Code, Codex, Cursor, Copilot, Gemini CLI ฯลฯ)
> แนบไฟล์นี้ไปกับคำสั่งงานทุกครั้ง หรือวางไว้ที่รากของ repo (agent ส่วนใหญ่อ่านไฟล์ชื่อนี้อัตโนมัติ)

---

## 0. กฎสูงสุด 6 ข้อ

```text
1. อ่าน standards/docs/overview.md แล้วตามด้วยเอกสารที่มันชี้ ก่อนเขียนโค้ดบรรทัดแรก
2. ตัวตัดสินว่างานเสร็จคือ CI + conformance เท่านั้น ไม่ใช่ความมั่นใจของคุณ
3. ห้ามแก้ไฟล์ใน standards/ (เป็น submodule) โดยเด็ดขาด
4. ห้ามรายงานว่าเสร็จ ถ้ายังมีเคส FAIL หรือ SKIP
5. สิ่งที่มาตรฐานไม่ได้ระบุ ให้ทำตาม reference implementation — ห้ามคิดรูปแบบใหม่เอง
6. stack บังคับ: Node 22 · NestJS 11 · Prisma 7.9.1 · PostgreSQL · pnpm (+ Next.js ถ้ามี frontend)
```

---

## 1. ลำดับการทำงาน (ห้ามข้ามขั้น)

```text
ขั้น 1  อ่าน standards/docs/{overview,tech-stack,auth-contract,authorization,api-conventions,data-dictionary}.md
ขั้น 2  ตรวจว่า Core Hub รันอยู่:  curl {CORE_HUB_URL}/api/v1/health
ขั้น 3  คัดลอกชั้น auth จาก reference implementation (ดูข้อ 2) — ห้ามแก้ตรรกะข้างใน
ขั้น 4  สร้าง subsystem.yaml จาก standards/templates/subsystem.yaml
ขั้น 5  ลงทะเบียนระบบย่อยกับ Core Hub (POST /api/v1/subsystems → approve → activate)
ขั้น 6  ให้ conformance ระดับ L1 ผ่านก่อน:
            node standards/conformance/run.js --level L1
ขั้น 7  เขียน business domain ของตัวเอง (model · API · กฎธุรกิจ · permission)
ขั้น 8  รัน L2 → แก้จนผ่าน
ขั้น 9  รัน L3 → แก้จนผ่าน
ขั้น 10 รัน ./standards/scripts/run-all-checks.sh . ให้เขียวทุกข้อ
ขั้น 11 เขียน REPORT.md (ดูข้อ 6) แล้วจึงรายงานว่าเสร็จ
```

ถ้า L1 ยังไม่ผ่าน การเขียน business logic ต่อคือการสร้างหนี้

---

## 2. สิ่งที่ต้อง "คัดลอก" ไม่ใช่ "เขียนใหม่"

reference implementation: `demo-student-subsystem/backend/`

| คัดลอกทั้งไฟล์/โฟลเดอร์ | แก้ได้ไหม |
|---|---|
| `src/auth/jwks.service.ts` · `core-hub-token.verifier.ts` · `auth.errors.ts` · `core-hub-identity.ts` | ❌ ห้ามแก้ตรรกะ |
| `src/auth/guards/` · `src/auth/decorators/` | ❌ ห้ามแก้ |
| `src/auth/sso-callback.controller.ts` · `sso-session.ts` · `me.controller.ts` | ❌ ห้ามแก้ |
| `src/common/` (envelope + exception filter) | ❌ ห้ามแก้ |
| `src/auth/role-mapping.ts` | ✏️ แก้ได้เฉพาะ "ค่า" ในตาราง ให้ตรงกับทะเบียน |
| `src/auth/permissions.ts` | ✏️ เขียน permission ของโดเมนตัวเอง (คงรูปแบบ `resource:action[:scope]`) |
| `prisma/` และโมดูลธุรกิจ | ✍️ เขียนเองทั้งหมด |

ชั้น auth คือส่วนที่ต้อง "เหมือนกันทุกทีม" การเขียนเองทำให้เกิดความต่างที่ตรวจจับยาก
และ `SEC-04` จะตีตกทันทีถ้าไม่ได้ verify ผ่าน JWKS + `kid`

---

## 3. สิ่งที่ agent มักทำผิด

| ❌ ห้ามทำ | ✅ ต้องทำ |
|---|---|
| "เพิ่ม `/login` ให้เผื่อไว้" | ระบบย่อยไม่มี login — ผู้ใช้ล็อกอินที่ Core Hub เท่านั้น (`SEC-05`) |
| "ทำตาราง users ของตัวเองไว้ก่อน" | เก็บได้แค่ `core_user_id` เป็น external reference |
| "ตอบ 401 ตอนสิทธิ์ไม่พอ" | สิทธิ์ไม่พอ = **403** เสมอ · 401 ใช้ตอนไม่รู้ว่าเป็นใคร |
| "ตอบ 404 แทน 403 เพื่อความปลอดภัย" | มาตรฐานบังคับ 403 (conformance จับ) |
| "ตั้งชื่อ error code ให้สื่อกว่า" | ใช้ enum ปิดใน `standards/contracts/error-codes.json` |
| "ใช้ jsonwebtoken / passport-jwt ก็ได้" | ต้องใช้ `jose` เพราะต้องรองรับ JWKS + `kid` |
| "ฮาร์ดโค้ด public key ไว้ก่อน" | ต้องดึงจาก JWKS และเลือกด้วย `kid` |
| "ตั้งชื่อคอลัมน์เป็น camelCase ใน DB" | DB เป็น `snake_case` ผ่าน `@map` · field ใน Prisma เป็น camelCase |
| "endpoint ชื่อ `/api/v1/borrowRecord`" | พหูพจน์ kebab-case: `/api/v1/borrow-records` |
| "ใช้ `per_page` สำหรับ pagination" | ใช้ `?page=&limit=` |
| "ใช้ npm/yarn ก็เหมือนกัน" | ใช้ **pnpm** เท่านั้น (`QA-05`) |
| "`prisma migrate dev` เปลี่ยนชื่อคอลัมน์" | จะกลายเป็น drop+add ข้อมูลหาย — เขียน `RENAME COLUMN` เอง |
| "แก้เทส/สคริปต์ให้ผ่าน" | ห้ามแตะ `standards/` — ให้แก้โค้ดตัวเอง |
| "`typecheck` ของ frontend ใช้ `tsc --noEmit` พอ" | ต้องเป็น `next typegen && tsc --noEmit` ไม่งั้นผ่านในเครื่องแต่ตกบน CI (`tech-stack.md` ข้อ 1.2.1) |
| "รายงานว่าเสร็จ น่าจะผ่าน" | ต้องแนบผลรันจริงของ CI + conformance |

---

## 4. คำสั่งที่ต้องรันได้เสมอ

```bash
pnpm install
pnpm --filter backend build
pnpm --filter backend test
pnpm --filter backend start:dev

# ตรวจ typecheck แบบเดียวกับ CI (ลบของค้างก่อน ไม่งั้นผ่านหลอก)
rm -rf frontend/.next && pnpm -r typecheck

# ตัวตัดสิน
./standards/scripts/run-all-checks.sh .        # static — เหมือน CI
node standards/conformance/run.js              # runtime — ยิงระบบจริง
```

---

## 5. เกณฑ์ผ่าน

```text
RESULT: <n> passed · 0 failed · 0 skipped
✅ CONFORMANT — <subsystem> meets standard v1.0 <level>
```

- **0 failed** เท่านั้นจึงผ่าน
- **SKIP ไม่นับว่าผ่าน** — แปลว่า `probes` ใน `subsystem.yaml` ยังประกาศไม่ครบ
- ถ้าเชื่อว่าเคสใดผิดที่ตัวมาตรฐานเอง **ห้ามแก้** ให้บันทึกใน `REPORT.md` แล้วแจ้ง PL

---

## 6. REPORT.md ที่ต้องส่งพร้อมงาน

````markdown
# REPORT — <subsystem>

## ผลรัน
```
<ผล ./standards/scripts/run-all-checks.sh . 10 บรรทัดสุดท้าย>
<ผล node standards/conformance/run.js 10 บรรทัดสุดท้าย>
```

## ไฟล์ที่สร้าง/แก้ไข
- path — ทำอะไร (เหตุผลสั้น ๆ)

## ชั้น auth ที่คัดลอกมา
- คัดลอกจาก demo-student-subsystem: <รายการไฟล์>
- แก้ไข: <ระบุ ถ้าไม่มีให้เขียน "ไม่มี">

## Role mapping ที่ประกาศ (ต้องตรงกับ default_role_mapping ในทะเบียน)
| core role | subsystem role |
|---|---|

## ข้อสมมติที่ตั้งเอง (เพราะมาตรฐานไม่ได้ระบุ)
1. …

## สิ่งที่ยังทำไม่ได้ / เคสที่ยังไม่ผ่าน
- (ถ้าไม่มี ให้เขียน "ไม่มี")
````

---

## 7. เทมเพลตคำสั่งสำหรับผู้สั่งงาน

ดู [`TASK_TEMPLATE.md`](TASK_TEMPLATE.md) — คัดลอกไปวางใน AI ตัวไหนก็ได้ ผลลัพธ์ควรออกมาเทียบเท่ากัน
