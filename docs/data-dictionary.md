# CSMJU2030 — Data Dictionary & Schemas

**Version:** 1.0.1  
**Scope:** Phase 1 — ใช้งานภายในสาขาเดียว

> ### Errata 1.0.0 → 1.0.1 (2026-09-04)
>
> ฉบับ 1.0.0 กำหนดชื่อฟิลด์ identity กลางเป็น `user_id` ซึ่งขัดกับ
> `auth-contract.md` ข้อ 11 ที่กำหนดเป็น `username` และผูกไว้กับ JWT claim
> (`sub` ต้องมีค่าเท่ากับ `username`) เอกสารทั้งสองฉบับอ้างอิงกันไปกลับ
> โดยที่ค่าไม่ตรงกัน ทำให้ระบบย่อยที่ทำตามฉบับใดฉบับหนึ่งถูก CI ตีตก
>
> **มติ: ยึด `username`** เพราะเป็น contract ที่ข้ามขอบเขตไปหา Core แล้ว
> (gateway ออก token ด้วยชื่อนี้) และเพราะ `user_id` เป็นชื่อสามัญที่จะชนกับ
> foreign key ของตาราง local ทำให้กลไก forbidden-alias ตรวจแยกไม่ออก
>
> รายการที่แก้ในฉบับนี้
>
> | ข้อ | เดิม | ใหม่ |
> |---|---|---|
> | 1, 3, 4, 7 | `user_id` | `username` |
> | 1, 3 | — | เพิ่มฟิลด์ `faculty` ที่ `auth-contract.md` บังคับเป็น required แต่ฉบับ 1.0.0 ไม่มี |
> | 9 | canonical เป็น `user_id` | canonical เป็น `username`, `user_id` ย้ายไปอยู่ในลิสต์ alias ต้องห้าม |
> | 13 | `*.schema.yaml` | `*.schema.json` (ตามไฟล์จริงใน `schemas/`) |
> | 14 | `auth-contract.md` | `auth-contract.md` |
>
> `layer1_role` ไม่ถูกแก้ — ฉบับ 1.0.0 ถูกต้องแล้ว (`student, staff, alumni,
> admin`) ที่ผิดคือสคริปต์ `check-field-aliases.sh` ซึ่งแก้ไปพร้อมกัน

## 1. Shared Data Contract

ตารางนี้คือข้อมูลที่ **Core Hub เป็นเจ้าของ** และสิ่งที่ระบบย่อยได้รับจริงในเวอร์ชัน 1.0

### 1.1 สิ่งที่มาใน access token (ใช้ได้ทันที)

| ชื่อใน token | ชื่อในระบบย่อย (DB / TS) | Type | ความหมาย |
|---|---|---|---|
| `sub` | `core_user_id` / `coreUserId` | string | **Global Identity** — id ผู้ใช้ของ Core Hub เช่น `user-002` |
| `email` | `email` | string | อีเมลของผู้ใช้ |
| `role` | `core_role` / `coreRole` | enum | `student` · `alumni` · `staff` · `admin` |
| `sid` | — | string | session id ของ Core Hub (ไม่ต้องเก็บ) |

### 1.2 สิ่งที่ Core Hub มีแต่ **ไม่ได้ส่งมาใน token**

| field | สถานะใน v1.0 |
|---|---|
| `username` | มีในฐานข้อมูล Core Hub แต่ไม่อยู่ใน token · ดึงได้เฉพาะผ่าน `GET /api/v1/users/:id` ซึ่งต้องมี permission |

### 1.3 สิ่งที่ **ยังไม่มี** ใน Core Hub v1.0

```text
faculty · department · full_name · is_active · visibility
```

ห้ามออกแบบระบบโดยสมมติว่าได้ field เหล่านี้จาก Core Hub หรือจาก token
ถ้าระบบย่อยจำเป็นต้องใช้ ให้เก็บเป็น **local data ของตัวเอง** และระบุไว้ใน `REPORT.md`
จนกว่าจะมี Change Process เพิ่มเข้าสัญญากลาง (ดูข้อ 11)

## 2. Core Rules

- ใช้ชื่อ field ตามมาตรฐานนี้
- Shared Data ต้องมี Source of Truth เดียว
- Subsystem ห้ามแก้ข้อมูลที่ Core เป็นเจ้าของ
- Local Data อยู่ใน Schema ของ Subsystem
- ห้ามสร้าง field ซ้ำความหมายกับ Shared Data
- Shared Contract เปลี่ยนได้ผ่าน Change Process เท่านั้น
- Breaking Change → Major Version

## 3. Identity ที่ระบบย่อยเก็บได้

ระบบย่อย **ห้าม**สร้างตาราง user ของตัวเองที่ซ้ำกับ Core Hub และ **ห้าม**เก็บรหัสผ่าน
ให้เก็บเพียง external reference:

```prisma
model Student {
  id         String  @id @default(uuid())
  coreUserId String? @unique @map("core_user_id")   // ← ค่า sub จาก token เท่านั้น
  // ...ข้อมูลธุรกิจของระบบย่อยเอง
}
```

```yaml
CoreIdentityReference:
  core_user_id:
    type: string
    required: false        # อาจยังไม่ผูกกับผู้ใช้ Core Hub ในตอนสร้างข้อมูล
    unique: true
    source: Core (JWT claim `sub`)
    writable: false        # ระบบย่อยห้ามแก้ค่านี้เอง
  core_role:
    type: enum
    values: [student, alumni, staff, admin]
    source: Core (JWT claim `role`)
    writable: false
```

## 4. Role Schema

```yaml
CoreRole:                    # claim `role` ใน access token (Layer 1)
  type: enum
  source: Core Hub
  values: [student, alumni, staff, admin]

SubsystemRole:               # role ภายในระบบย่อย (Layer 2) — แต่ละระบบตั้งเอง
  type: string
  scope: subsystem
  example: [STUDENT, ALUMNI, STAFF, ADMIN, USER]

RoleMapping:                 # ประกาศทั้งใน Registry (default_role_mapping) และในโค้ดระบบย่อย
  core_role: CoreRole
  subsystem_role: SubsystemRole

RoleException:               # ขอผ่าน Subsystem Registry เท่านั้น ห้าม hardcode
  username: string           # username ของผู้ใช้ใน Core Hub
  subsystem_role: SubsystemRole
  approval_required: true
```

> key ของ `default_role_mapping` ในทะเบียน = รายชื่อ core role ที่เข้าระบบนั้นได้
> Core Hub ใช้ตรวจตั้งแต่ก่อน redirect (ดู [`authorization.md`](authorization.md) ข้อ 3)

## 5. Department Schema

```yaml
Department:
  code:
    type: string
    required: true
    unique: true
  name:
    type: string
    required: true
  active:
    type: boolean
    required: true
```

Phase 1 ใช้เฉพาะ Department ของสาขาที่กำหนดให้ระบบ

## 6. Common Schema

```yaml
Date:
  format: YYYY-MM-DD

DateTime:
  format: ISO 8601
  timezone: required

Money:
  type: integer
  unit: satang
  float: forbidden

Phone:
  type: string
  format: no-hyphen

Boolean:
  values: [true, false]

Visibility:
  values: [public, internal, private]
```

## 7. Subsystem Schema

ตรงกับตาราง `subsystems` ของ Core Hub และ `subsystem.yaml` ในระบบย่อย
(ดู [`subsystem-registry.md`](subsystem-registry.md))

```yaml
Subsystem:
  name:
    type: string
    format: kebab-case         # ต้องตรงกับ subsystem.yaml และ data.service ของ /api/health
  display_name:
    type: string
  owner:
    type: string
    reference: username        # username ของผู้ใช้ใน Core Hub
  repo:
    type: string
  standards_version:
    type: semver               # เวอร์ชันมาตรฐานที่ผ่าน conformance จริง
  default_role_mapping:
    type: object               # core role → subsystem role
  callback_url:
    type: url                  # https เท่านั้น ยกเว้น localhost ตอน dev
  approval_status:
    type: enum
    values: [PENDING, APPROVED, REJECTED]
  status:
    type: enum
    values: [ACTIVE, INACTIVE, SUSPENDED]
```

## 8. Table / Schema Boundary

```text
Shared
├── users
├── departments
└── common

Subsystem
└── local tables / schemas
```

ตัวอย่าง Local Data:

```text
equipment_id
serial_number
purchase_date
```

Local Data ไม่ต้องเพิ่มใน Data Dictionary กลาง เว้นแต่มีความจำเป็นต้องใช้ร่วมกันหลาย Subsystem

## 9. Naming

### 9.1 กฎรวม

```text
ตาราง           : plural snake_case      (students, borrow_records)
คอลัมน์          : snake_case             (student_code, created_at)
field ใน Prisma  : camelCase              (studentCode, createdAt)
field ใน JSON    : camelCase              (studentCode, createdAt)
enum ใน Prisma   : PascalCase  ค่า UPPER_SNAKE_CASE   (enum BorrowStatus { BORROWED })
boolean          : ขึ้นต้น is_ หรือ has_  (is_active, has_returned)
primary key      : id (UUID v4)
foreign key      : <entity>_id            (student_id, course_id)
timestamp        : created_at, updated_at (ทุกตาราง)
ชื่อ database    : <subsystem>_db
date             : YYYY-MM-DD
datetime         : ISO 8601 UTC ลงท้าย Z
```

ฐานข้อมูลเป็น `snake_case` ส่วนโค้ดเป็น `camelCase` — เชื่อมกันด้วย `@map` / `@@map`
ไม่ใช่การตั้งชื่อสองแบบมั่ว ๆ แต่เป็นการแยกชั้น **DB ↔ application** อย่างตั้งใจ

```prisma
model Student {
  id          String   @id @default(uuid())
  coreUserId  String?  @unique @map("core_user_id")
  studentCode String   @unique @map("student_code")
  firstName   String   @map("first_name")
  createdAt   DateTime @default(now()) @map("created_at")
  updatedAt   DateTime @updatedAt      @map("updated_at")

  @@map("students")
}
```

### 9.2 ห้ามสร้าง alias ของ Global Identity

Global Identity คือค่า `sub` จาก token · ในระบบย่อยต้องตั้งชื่อว่า **`core_user_id` / `coreUserId`** เท่านั้น
ชื่อต่อไปนี้ห้ามใช้เรียกค่านี้ (กฎ `DD-01`):

```text
user_id · userId · user_code · userCode · std_id · stdId · username
```

> หมายเหตุ: `student_code`, `studentId` ฯลฯ **ใช้ได้** ถ้าเป็นข้อมูลธุรกิจของระบบย่อยเอง
> (เช่น รหัสนักศึกษาในทะเบียนของระบบ หรือ foreign key ไปยังตาราง `students` ของตัวเอง)
> เพราะ Global Identity ในสถาปัตยกรรมนี้คือ `sub` ไม่ใช่รหัสนักศึกษา

### 9.3 Migration

- ใช้ Prisma Migrate และ commit `prisma/migrations/` เข้า git
- **ห้าม**ลบหรือ squash migration เดิม — ประวัติต้องรันบนฐานข้อมูลเปล่าได้เสมอ
- เปลี่ยนชื่อคอลัมน์ **ต้อง**เขียน `ALTER TABLE … RENAME COLUMN` เอง พร้อม rename index/constraint
  เพราะ `prisma migrate dev` จะสร้างเป็น drop + add ซึ่งทำให้ **ข้อมูลหาย**
- หลังแก้ schema ต้องตรวจว่าไม่มี drift:

```bash
npx prisma migrate diff --from-config-datasource --to-schema prisma/schema.prisma --exit-code
# ต้องได้: No difference detected.
```

## 10. Source of Truth

```text
Core
 ↓
API / Service Contract
 ↓
Subsystem
```

| Data | Source of Truth | Subsystem Write |
|---|---|---|
| User Identity | Core | No |
| `full_name` | Core | No |
| `email` | Core | No |
| `department` | Core | No |
| Layer 1 Role | Core | No |
| Layer 2 Role | Subsystem | Yes |

## 11. Change Process

```text
Request
 ↓
PM Review
 ↓
Shared / Local
 ├─ Local → Subsystem Schema
 └─ Shared → Data Dictionary + Schema
                    ↓
                 Version
                    ↓
                 Changelog
```

## 12. Versioning

```text
MAJOR.MINOR.PATCH
```

- PATCH → ไม่เปลี่ยน Contract
- MINOR → เพิ่มแบบไม่ทำลายของเดิม
- MAJOR → Breaking Change

## 13. `schemas/`

```text
schemas/
├── user.schema.json
├── role.schema.json
├── department.schema.json
├── subsystem.schema.json
└── common.schema.json
```

ไฟล์จริงใน `csmju2030-standards/schemas/` เป็น JSON Schema (`.json`)
ฉบับ 1.0.0 เขียนว่า `.yaml` ซึ่งไม่ตรงกับของจริง

## 14. Integration Boundary

```text
authcontract.md
→ Authentication / Authorization

data-dictionary.md
→ Shared Data Contract

schemas/
→ Data Structure / Validation

api-conventions.md
→ API Contract

ui-design-system.md
→ UI / UX
```

## 15. Completion

```text
[ ] Shared Table กำหนดแล้ว
[ ] Shared Field กำหนดแล้ว
[ ] Type / Required / Enum กำหนดแล้ว
[ ] Source of Truth กำหนดแล้ว
[ ] Read / Write กำหนดแล้ว
[ ] User Schema กำหนดแล้ว
[ ] Role Schema กำหนดแล้ว
[ ] Department Schema กำหนดแล้ว
[ ] Common Schema กำหนดแล้ว
[ ] Subsystem Schema กำหนดแล้ว
[ ] Change / Versioning กำหนดแล้ว
```
