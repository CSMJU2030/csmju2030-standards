# api-conventions.md

**เวอร์ชัน:** 1.0 · **บังคับใช้กับ:** ทุก API ที่ระบบย่อยเปิดให้เรียก

> เอกสารนี้กำหนดรูปแบบ API ให้เหมือนกันทุกระบบย่อย เพื่อให้ automated check ตรวจได้
> และให้ AI คนละตัวสร้าง API ออกมาในรูปแบบเดียวกัน
> ทุกข้อในเอกสารนี้มีการตรวจจริงใน `conformance/` ระดับ L2

---

## 1. โครงสร้าง URL

```text
https://<subsystem-domain>/api/v1/<resource>[/<id>][/<sub-resource>]
```

| กฎ | รายละเอียด |
|---|---|
| prefix | endpoint ธุรกิจทุกตัวอยู่ใต้ `/api/v1/` |
| ชื่อ resource | **noun พหูพจน์ + kebab-case** — `/api/v1/borrow-records` ไม่ใช่ `/borrowRecords` หรือ `/getEquipment` |
| ห้ามใส่กริยาใน path | ใช้ `POST /api/v1/enrollments` ไม่ใช่ `/api/v1/createEnrollment` |
| การกระทำพิเศษ | ให้เป็น sub-resource ของ id เช่น `POST /api/v1/borrow-records/:id/return` |
| ความลึก | ซ้อนได้ไม่เกิน **1 ระดับ** เช่น `/api/v1/students/:id/enrollments` |
| trailing slash | ห้ามมี |
| path parameter | เป็น UUID v4 · ค่าที่ไม่ใช่ UUID ต้องตอบ `400` |
| query parameter | `camelCase` เช่น `?studentId=&status=&page=&limit=` |

**เส้นทางที่อยู่นอก `/api/v1`** (มีแค่ 2 เส้นทาง):

| Path | เหตุผล |
|---|---|
| `GET /api/health` | ใช้ monitor · ไม่ผูกกับเวอร์ชัน API · public |
| `GET /auth/callback` | ต้องตรงกับ `callback_url` ที่ลงทะเบียนกับ Core Hub · public |

**การขึ้นเวอร์ชัน**: การเปลี่ยนที่ทำให้ client เดิมพัง (ลบ/เปลี่ยนความหมาย field, เปลี่ยน status)
ต้องออกเป็น `/api/v2` และคง `v1` ไว้อย่างน้อย 1 ภาคการศึกษา · การ **เพิ่ม** field/endpoint ไม่ใช่ breaking change

---

## 2. HTTP Method และ status ที่ต้องคืน

| Method | ใช้กับ | สำเร็จ | หมายเหตุ |
|---|---|---|---|
| `GET /api/v1/<res>` | รายการ | `200` + `data[]` + `meta` | ต้องมีลำดับที่แน่นอนเสมอ |
| `GET /api/v1/<res>/:id` | รายการเดียว | `200` + `data{}` | ไม่พบ → `404` |
| `POST /api/v1/<res>` | สร้าง | **`201`** + `data{}` ของที่สร้าง | ชนกฎธุรกิจ → `409` |
| `PATCH /api/v1/<res>/:id` | แก้บางฟิลด์ | `200` + `data{}` หลังแก้ | |
| `DELETE /api/v1/<res>/:id` | ลบ | `200` + `data{ id, deleted: true }` | **ห้ามตอบ `204`** เพราะต้องมี envelope เสมอ |
| `PUT` | แทนทั้ง object | `200` | **ควรเลี่ยง** ใช้ `PATCH` แทน |

---

## 3. Response — กรณีสำเร็จ

```json
{ "success": true, "data": { } }
```

คอลเลกชันต้องมี `meta` เสมอ:

```json
{
  "success": true,
  "data": [ ],
  "meta": { "total": 42, "page": 1, "limit": 20, "totalPages": 3 }
}
```

top-level key มีได้เฉพาะ `success`, `data`, `meta`

---

## 4. Response — กรณี error

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": ["quantity must be greater than 0"]
  }
}
```

`error.code` เป็น SCREAMING_SNAKE_CASE และต้องอยู่ในรายการปิดนี้เท่านั้น
(ค่าจริงที่ CI/conformance อ่าน: [`../contracts/error-codes.json`](../contracts/error-codes.json))

| code | HTTP | ความหมาย |
|---|---|---|
| `BAD_REQUEST` | 400 | request ไม่ถูกต้องทั่วไป |
| `VALIDATION_ERROR` | **400** | body/query ไม่ผ่าน validation · ใส่รายละเอียดใน `details` เป็น array of string |
| `UNAUTHORIZED` | 401 | ไม่รู้ว่าเป็นใคร (ไม่มี token / token ใช้ไม่ได้) |
| `FORBIDDEN` | 403 | รู้แล้วว่าเป็นใคร แต่สิทธิ์ไม่พอ |
| `NOT_FOUND` | 404 | ไม่พบ resource |
| `CONFLICT` | 409 | ชนกฎธุรกิจ เช่น ค่าซ้ำ หรือสถานะไม่อนุญาต |
| `INTERNAL_ERROR` | 500 | ข้อผิดพลาดภายใน |

> `VALIDATION_ERROR` ใช้ **400** ไม่ใช่ 422 เพื่อให้ตรงกับพฤติกรรมเริ่มต้นของ `ValidationPipe` ใน NestJS
> ระบบย่อยจึงไม่ต้องเขียน exception filter พิเศษเพื่อฝืนมาตรฐาน

**ห้าม**ส่ง stack trace, ชื่อไฟล์, ข้อความจาก ORM หรือ SQL ออกไปใน response

---

## 5. Pagination

```text
?page=1&limit=20      ค่าเริ่มต้น page=1, limit=20, สูงสุด limit=100
```

- `limit` ที่ไม่ใช่ตัวเลขหรือเกินช่วง → `400 VALIDATION_ERROR`
- คอลเลกชันว่างคืน `data: []` + `meta.total: 0` (**ไม่ใช่** `null` และไม่ใช่ `404`)

---

## 6. Field naming ใน response

| ชั้น | รูปแบบ | ตัวอย่าง |
|---|---|---|
| JSON ที่ส่งออก API | **camelCase** | `studentCode`, `createdAt`, `coreUserId` |
| ฟิลด์ตามสัญญา OAuth | `snake_case` (ตามมาตรฐานสากล) | `access_token`, `token_type`, `expires_in`, `callback_url`, `state` |
| คอลัมน์ในฐานข้อมูล | **snake_case** | `student_code`, `created_at` — ดู [`data-dictionary.md`](data-dictionary.md) ข้อ 9 |

- วันเวลาใช้ **ISO 8601 UTC** ลงท้าย `Z` เช่น `"2026-09-11T09:30:00.000Z"`
- id ทุกตัวเป็น **UUID v4**
- ฟิลด์ที่ตรงกับตัวแปรกลางต้องใช้ชื่อตาม `data-dictionary.md` เป๊ะ

---

## 7. Public / Protected endpoint

ทุก route ใต้ `/api/v1/` **ต้อง**ผ่านการตรวจ token ไม่มีข้อยกเว้น
endpoint ที่เข้าถึงได้โดยไม่มี token ต้องประกาศไว้ใน `subsystem.yaml`:

```yaml
public_endpoints:
  - GET /api/health
  - GET /auth/callback
```

---

## 8. Health check (บังคับทุกระบบย่อย)

```http
GET /api/health        (public — ไม่ต้องมี token)
```

```json
{ "success": true, "data": { "status": "ok", "service": "csmju-equipment" } }
```

`data.service` ต้องเท่ากับ `name` ใน `subsystem.yaml` และเท่ากับ `name` ในทะเบียนของ Core Hub

> Core Hub เองใช้ `/api/v1/health` (มีเวอร์ชัน) ซึ่งเป็นข้อยกเว้นของ Core Hub เท่านั้น

---

## 9. สิ่งที่ยังไม่มีในสถาปัตยกรรมปัจจุบัน

| หัวข้อ | สถานะ |
|---|---|
| API Gateway / rate limit header (`X-RateLimit-*`) | ❌ ยังไม่มี — อย่าออกแบบโดยสมมติว่ามี |
| การเรียกข้ามระบบย่อย (service-to-service) | ❌ ยังไม่มีสัญญา — ต้องเสนอผ่าน Change Process ก่อน |

---

## 10. Checklist ก่อนขอ merge PR

- [ ] URL เป็น noun พหูพจน์ + kebab-case + อยู่ใต้ `/api/v1/`
- [ ] `POST` คืน `201` · `DELETE` คืน `200` + `{id, deleted:true}`
- [ ] response ทุกตัวห่อด้วย envelope `{ success, data[, meta] }` / `{ success:false, error }`
- [ ] `error.code` อยู่ในรายการปิด และ `VALIDATION_ERROR` เป็น 400
- [ ] คอลเลกชันมี `meta{total,page,limit,totalPages}` และรองรับ `?page=&limit=`
- [ ] field ใน JSON เป็น camelCase · คอลัมน์ใน DB เป็น snake_case
- [ ] มี `GET /api/health` ที่ `data.service` ตรงกับชื่อระบบ
- [ ] ประกาศ `public_endpoints` ใน `subsystem.yaml` ครบ
- [ ] `node standards/conformance/run.js` ผ่านระดับ L2 ขึ้นไป
