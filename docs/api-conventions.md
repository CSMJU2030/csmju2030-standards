# api-conventions.md

**เวอร์ชัน:** 1.0.0
**ดูแลโดย:** PM3 (API Gateway & Infrastructure)
**บังคับใช้กับ:** ทุก API ที่ระบบย่อยเปิดให้เรียก (ทั้งจาก frontend ของตัวเองและจากระบบย่อยอื่น/Core)

> เอกสารนี้กำหนดรูปแบบ API ให้เหมือนกันทุกระบบย่อย เพื่อให้ automated compliance check ตรวจสอบได้ และให้ AI ที่ใช้พัฒนาแต่ละระบบสร้าง API ออกมาในรูปแบบเดียวกัน แม้เป็น AI คนละตัว

---

## 1. โครงสร้าง URL

```
https://<subsystem-domain>/api/<resource>[/<id>][/<sub-resource>]
```

- ใช้ **noun พหูพจน์** เสมอ (`/equipment-items` ไม่ใช่ `/getEquipment`)
- ใช้ **kebab-case** สำหรับชื่อ path (`/borrow-records` ไม่ใช่ `/borrowRecords`)
- ห้ามใส่ verb ใน path (`/equipment-items/123/return` ❌ ให้ใช้ `POST /borrow-records/123` พร้อม body ระบุ action แทน หรือออกแบบเป็น resource ใหม่)
- ระบุเวอร์ชัน API ไว้ที่ prefix เสมอ: `/api/v1/...`

## 2. HTTP Method

| Method | ใช้เมื่อ |
|---|---|
| `GET` | อ่านข้อมูล ไม่มีผลข้างเคียง |
| `POST` | สร้างข้อมูลใหม่ |
| `PUT` | แก้ไขข้อมูลทั้ง object |
| `PATCH` | แก้ไขข้อมูลบางฟิลด์ |
| `DELETE` | ลบข้อมูล |

## 3. รูปแบบ Response — กรณีสำเร็จ

ทุก endpoint ต้องห่อ response ด้วย envelope นี้เสมอ:

```json
{
  "success": true,
  "data": { "...": "..." },
  "meta": { "...": "optional เช่น pagination" }
}
```

ตัวอย่าง list พร้อม pagination:

```json
{
  "success": true,
  "data": [
    { "id": "eq_001", "name": "โปรเจกเตอร์", "status": "available" }
  ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 134
  }
}
```

## 4. รูปแบบ Response — กรณี error

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "ฟิลด์ quantity ต้องมากกว่า 0",
    "details": { "field": "quantity" }
  }
}
```

`error.code` ใช้ SCREAMING_SNAKE_CASE และต้องอยู่ในรายการมาตรฐานต่อไปนี้ (เพิ่มค่าใหม่ต้องเสนอ PM3):

| code | HTTP status | ความหมาย |
|---|---|---|
| `UNAUTHORIZED` | 401 | ไม่มี/token หมดอายุ |
| `FORBIDDEN` | 403 | มี token แต่ไม่มีสิทธิ์ (Layer 2) |
| `NOT_FOUND` | 404 | ไม่พบ resource |
| `VALIDATION_ERROR` | 422 | ข้อมูล request ไม่ถูกต้อง |
| `CONFLICT` | 409 | ข้อมูลขัดแย้ง (เช่น ของถูกยืมไปแล้ว) |
| `INTERNAL_ERROR` | 500 | ข้อผิดพลาดฝั่งเซิร์ฟเวอร์ |

## 5. Pagination

Query parameter มาตรฐาน: `?page=1&per_page=20` (ค่าเริ่มต้น `per_page=20`, สูงสุด `100`)

## 6. Field naming ภายใน response

- ใช้ `snake_case` ทุกฟิลด์ (`created_at` ไม่ใช่ `createdAt`)
- วันเวลาใช้ ISO 8601 เสมอ: `"2026-08-11T09:30:00+07:00"`
- ฟิลด์ที่ตรงกับตัวแปรกลาง (username, faculty ฯลฯ) ต้องใช้ชื่อและ type ตาม `data-dictionary.md` เป๊ะ ห้ามตั้งชื่อเอง

## 7. การประกาศ Public / Protected endpoint

ทุกระบบย่อยต้องประกาศไว้ใน `subsystem.yaml` (ดูตัวอย่างใน registry) ว่า endpoint ไหนเข้าถึงได้โดยไม่ต้องมี token:

```yaml
public_endpoints:
  - "GET /api/v1/announcements"
  - "GET /health"
```

Endpoint ที่ไม่ได้ประกาศในนี้ ถือเป็น **protected โดย default** — gateway จะบังคับตรวจ token ก่อนส่งต่อเสมอ (ดูรายละเอียดการแนบ token ใน `auth-contract.md`)

## 8. Health check (บังคับทุกระบบย่อย)

```
GET /health  →  200 OK
{ "status": "ok", "version": "1.4.2" }
```

ใช้โดย gateway/monitoring เพื่อเช็คว่าระบบย่อยยังทำงานอยู่ ไม่ต้องแนบ token

## 9. Rate limit header (gateway แนบมาให้ทุก response)

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1754900400
```

## 10. Checklist ก่อนขอ merge PR (AIE ตรวจเองก่อนส่ง PL review)

- [ ] URL เป็น noun พหูพจน์ + kebab-case + มี `/v1/` prefix
- [ ] Response ทุก endpoint ห่อด้วย envelope `{ success, data/error, meta }`
- [ ] error.code อยู่ในรายการมาตรฐาน (ข้อ 4)
- [ ] field ทุกตัวเป็น snake_case และตรงกับ data-dictionary.md
- [ ] มี `/health` endpoint
- [ ] ประกาศ public_endpoints ใน subsystem.yaml ครบ
