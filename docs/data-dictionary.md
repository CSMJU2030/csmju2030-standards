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

| Table | Field | Type | Required | Source | Rule |
|---|---|---|---|---|---|
| `users` | `username` | string | Yes | Core | รหัสนักศึกษา / รหัสอาจารย์ / รหัสบุคลากร ใช้อ้างอิง User กลาง (ห้ามใช้ `user_id` — ดูข้อ 9) |
| `users` | `layer1_role` | enum | Yes | Core | `student`, `staff`, `alumni`, `admin` |
| `users` | `faculty` | string | Yes | Core | รหัสคณะ — เป็น claim required ใน JWT ตาม `auth-contract.md` ข้อ 11 |
| `users` | `department` | string/code | Yes | Core | สาขาที่ผู้ใช้สังกัด (ระดับย่อยกว่า `faculty`) |
| `users` | `full_name` | string | Yes | Core | ชื่อ-นามสกุล; Subsystem ห้ามแก้ |
| `users` | `email` | string | Yes | Core | อีเมลมหาวิทยาลัย |
| `users` | `is_active` | boolean | No | Core/Owner | `true` / `false` |
| `users` | `visibility` | enum | No | Owner | `public`, `internal`, `private` |

## 2. Core Rules

- ใช้ชื่อ field ตามมาตรฐานนี้
- Shared Data ต้องมี Source of Truth เดียว
- Subsystem ห้ามแก้ข้อมูลที่ Core เป็นเจ้าของ
- Local Data อยู่ใน Schema ของ Subsystem
- ห้ามสร้าง field ซ้ำความหมายกับ Shared Data
- Shared Contract เปลี่ยนได้ผ่าน Change Process เท่านั้น
- Breaking Change → Major Version

## 3. User Schema

```yaml
User:
  username:
    type: string
    required: true
    unique: true
  layer1_role:
    type: enum
    required: true
    values: [student, staff, alumni, admin]
  faculty:
    type: string
    required: true
    source: Core
    writable: false
  department:
    type: string
    required: true
  full_name:
    type: string
    required: true
    source: Core
    writable: false
  email:
    type: string
    required: true
    source: Core
    writable: false
  is_active:
    type: boolean
    required: false
  visibility:
    type: enum
    required: false
    values: [public, internal, private]
```

## 4. Role Schema

```yaml
Layer1Role:
  type: enum
  values:
    - student
    - staff
    - alumni
    - admin

Layer2Role:
  type: string
  scope: subsystem

RoleMapping:
  layer1_role: Layer1Role
  layer2_role: Layer2Role

RoleException:
  username: string
  layer2_role: Layer2Role
  approval_required: true
```

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

```yaml
Subsystem:
  subsystem_name:
    type: string
    format: kebab-case
  display_name:
    type: string
  owner:
    type: string
    reference: username
  status:
    type: enum
    values: [proposed, staging, production, deprecated]
  standards_version:
    type: semver
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

```text
field: snake_case
table: plural snake_case
enum value: lowercase
date: YYYY-MM-DD
datetime: ISO 8601
```

ห้ามสร้าง alias สำหรับ Global Identity เดียวกัน — ชื่อต่อไปนี้ห้ามใช้ทุกที่
ทั้งในโค้ด schema และ API payload (`check-field-aliases.sh` ตีตกทันที):

```text
user_id
user_code
userId
userCode
student_id
student_code
studentId
std_id
stdId
```

หากหมายถึง Global Identity ให้ใช้ชื่อนี้เท่านั้น:

```text
username
```

หมายเหตุ: ค่าที่บรรจุอยู่เป็นรหัสนักศึกษา/บุคลากร (เช่น `64123456`) การตั้งชื่อว่า
`username` จึงไม่ตรงความหมายตามตัวอักษร แต่เลือกไว้โดยเจตนา เพราะเป็นชื่อที่
`auth-contract.md` ผูกกับ JWT claim ไว้แล้ว และเพราะเป็นชื่อที่ไม่ชนกับ
foreign key ของตาราง local ซึ่งมักตั้งว่า `user_id`

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
