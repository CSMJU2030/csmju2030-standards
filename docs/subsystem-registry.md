# Subsystem Registry

**เวอร์ชัน 1.0** · ทะเบียนระบบย่อยที่ Core Hub ดูแล

ระบบย่อยจะทำ SSO ได้ก็ต่อเมื่อ **ลงทะเบียนแล้ว + อนุมัติแล้ว + เปิดใช้งานแล้ว** เท่านั้น

---

## 1. ลงทะเบียน

```bash
POST {CORE_HUB_URL}/api/v1/subsystems      # ต้องมี Bearer token ของผู้มีสิทธิ์
Content-Type: application/json

{
  "name": "equipment-service",
  "displayName": "ระบบครุภัณฑ์",
  "owner": "admin",
  "repo": "csmju-equipment",
  "standardsVersion": "1.0",
  "defaultRoleMapping": { "admin": "ADMIN", "staff": "STAFF", "student": "USER" },
  "requestedExceptions": [],
  "callbackUrl": "http://localhost:3002/auth/callback"
}
```

| field | กฎ |
|---|---|
| `name` | `[a-z0-9-]+` · ต้องตรงกับ `name` ใน `subsystem.yaml` และ `data.service` ของ `/api/health` |
| `owner` | `username` ของผู้ใช้ใน Core Hub ที่เป็นเจ้าของระบบ |
| `standardsVersion` | เวอร์ชันมาตรฐานที่ระบบผ่าน conformance จริง (เช่น `"1.0"`) |
| `defaultRoleMapping` | core role → subsystem role · **key คือรายชื่อ core role ที่เข้าระบบนี้ได้** |
| `callbackUrl` | ดูกฎข้อ 3 |

---

## 2. วงจรชีวิต

```text
สร้าง → approvalStatus=PENDING, status=INACTIVE
  │  POST /api/v1/subsystems/:id/approve      → APPROVED
  │  POST /api/v1/subsystems/:id/activate     → ACTIVE     ← SSO ใช้ได้เมื่อถึงขั้นนี้
  │  POST /api/v1/subsystems/:id/deactivate   → INACTIVE
  └  POST /api/v1/subsystems/:id/suspend      → SUSPENDED
```

Core Hub จะทำ SSO ให้เฉพาะ `approvalStatus = APPROVED` **และ** `status = ACTIVE`
สถานะอื่นตอบ `409`

---

## 3. กฎของ `callback_url`

| กฎ | รายละเอียด |
|---|---|
| ต้องเป็น absolute URL | มี scheme เสมอ |
| ต้องเป็น `https` | ยกเว้น `localhost` / `127.0.0.1` ตอน development |
| ต้องตรงกับ URL จริงของระบบย่อย | conformance `L3-04` ตรวจข้อนี้ |
| path มาตรฐาน | `/auth/callback` (นอก prefix `/api`) |
| ถ้า client ส่ง `callback_url` มาด้วย | ต้อง **ตรงเป๊ะ** กับที่ลงทะเบียน ไม่งั้น `400` |
| ห้าม | ยอมรับ callback ที่ client กำหนดเอง (open redirect) |

Core Hub ตรวจตามลำดับนี้ก่อนออก token:

```text
subsystem มีจริง (404) → APPROVED (409) → ACTIVE (409)
   → core role อยู่ใน default_role_mapping (403) → callback_url ตรงทะเบียน (400) → 302
```

---

## 4. ดูและแก้ทะเบียน

| Method & path | ใช้ทำอะไร |
|---|---|
| `GET /api/v1/subsystems/all` | รายการทั้งหมด |
| `GET /api/v1/subsystems/:id` | รายตัว |
| `PATCH /api/v1/subsystems/:id` | แก้ข้อมูล (รวม `callbackUrl`) |
| `GET` / `PATCH /api/v1/subsystems/:id/role-mapping` | ดู/แก้ตาราง role mapping |
| `DELETE /api/v1/subsystems/:id` | ลบทะเบียน |

---

## 5. Subsystem Exception (สิทธิ์พิเศษรายบุคคล)

```bash
POST /api/v1/subsystems/:id/exceptions      { "username": "...", "role": "staff", "reason": "..." }
GET  /api/v1/subsystems/:id/exceptions
POST /api/v1/subsystems/:id/exceptions/:exceptionId/approve   # หรือ /reject
```

ใช้เมื่อต้องให้ผู้ใช้บางคนมีสิทธิ์ต่างจาก core role ปกติ
**ห้าม**ฮาร์ดโค้ดรายชื่อผู้ใช้ในโค้ดของระบบย่อย

---

## 6. `subsystem.yaml` ใน repo ของระบบย่อย

ข้อมูลชุดเดียวกันต้องประกาศไว้ที่รากของ repo ด้วย — CI และ conformance อ่านไฟล์นี้

```yaml
name: csmju-equipment
standards_version: "1.0.0"
conformance_level: L3

base_url: http://localhost:3002
core_hub_url: http://localhost:3000
callback_path: /auth/callback

public_endpoints:
  - GET /api/health
  - GET /auth/callback

probes:                       # conformance ใช้ตรวจ contract (ประกาศไม่ครบ = SKIP = ไม่ผ่าน)
  collection: /api/v1/equipment-items
  not_found: /api/v1/equipment-items/99999999-9999-4999-8999-999999999999
  invalid_id: /api/v1/equipment-items/not-a-uuid
  create:
    path: /api/v1/equipment-items
    allowed_role: staff
    denied_role: student
    invalid_body:
      name: ""
    valid_body:
      name: Conformance Probe
      quantity: 1

owners:
  pl: "@csmju2030/pl-equipment"
  aie: "@csmju2030/aie-equipment"
```

schema: [`../schemas/subsystem.schema.json`](../schemas/subsystem.schema.json)
