# CSMJU2030 — Data Dictionary & Schemas

**Version:** 1.0.0  
**Scope:** Phase 1 — ใช้งานภายในสาขาเดียว

## 1. Shared Data Contract

| Table | Field | Type | Required | Source | Rule |
|---|---|---|---|---|---|
| `users` | `user_id` | string | Yes | Core | รหัสนักศึกษา / รหัสอาจารย์ / รหัสบุคลากร ใช้อ้างอิง User กลาง |
| `users` | `layer1_role` | enum | Yes | Core | `student`, `staff`, `alumni`, `admin` |
| `users` | `department` | string/code | Yes | Core | สาขาที่ผู้ใช้สังกัด |
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
  user_id:
    type: string
    required: true
    unique: true
  layer1_role:
    type: enum
    required: true
    values: [student, staff, alumni, admin]
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
  user_id: string
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
    reference: user_id
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

ห้ามสร้าง alias สำหรับ field เดียวกัน เช่น:

```text
user_id
user_code
student_id
student_code
std_id
```

หากหมายถึง Global Identity เดียวกัน ให้ใช้:

```text
user_id
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
├── user.schema.yaml
├── role.schema.yaml
├── department.schema.yaml
├── subsystem.schema.yaml
└── common.schema.yaml
```

รูปแบบไฟล์ต้องยืนยันกับ PM/PL ก่อนใช้งานจริง

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
