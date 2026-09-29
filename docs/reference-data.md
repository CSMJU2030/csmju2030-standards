# ข้อมูลอ้างอิงกลาง (Reference Data) — สารบัญชุดข้อมูล

**เวอร์ชัน 1.2** · เจ้าของข้อมูล: Core Hub · สเปกฉบับเต็มของรูปแบบกลาง: `SHARED_DATA_HANDOFF`
(เอกสารสั่งงานของ PL) — หน้านี้คือ**สารบัญที่ระบบย่อยใช้ดูว่ามีชุดอะไรให้เรียก** และสรุปสัญญาที่ทุกชุดทำตามเหมือนกัน

---

## 1. สัญญากลางโดยย่อ (ทุกชุดเหมือนกัน)

- **อ่าน:** `GET /api/v1/<dataset>` (แบ่งหน้า `page`/`limit`≤100/`includeInactive` · ค่าเริ่มต้นเฉพาะที่เปิดใช้งาน · `meta` ชั้นบน)
  และ `GET /api/v1/<dataset>/:code` (คืนแม้ `isActive: false` · ไม่เจอ = `404 NOT_FOUND`)
- **สิทธิ์:** อ่าน = `reference:read` (ทุก role ที่ login) · เขียน = `reference:manage` (admin) ผ่าน `POST`/`PATCH`
  — **ไม่มี DELETE** ปิดใช้งานด้วย `isActive: false` · **`code` แก้ไม่ได้หลังสร้าง**
- **เรียกจาก backend ของระบบย่อย** ด้วย access token ของผู้ใช้ที่ login อยู่ (`Authorization: Bearer`) —
  Core Hub ไม่เปิด CORS ให้เรียกจากเบราว์เซอร์ · ห้าม log token
- **field บังคับทุกชุด:** `code` (ตัวพิมพ์ใหญ่ ตัวเลข `-`) · `isActive` · `updatedAt` — **ไม่มี `id` ใน response**
- **ระบบย่อยเก็บแค่ `code`** ส่วนชื่อ/รายละเอียดถามผ่าน API ตอนแสดงผล · **ห้ามสร้างตารางของชุดเหล่านี้ซ้ำในฐานของตัวเอง**
  (เก็บเฉพาะข้อมูลของระบบเองที่อ้าง `code` เช่น การจองห้อง) · **cache รวมทุกผู้ใช้ TTL 10 นาที**
  (ค่าแนะนำ) · Core Hub ล่มชั่วคราวใช้ของเก่าต่อได้ — แบบเดียวกับที่ทำกับ JWKS
- **header:** ทุก GET ตอบ `Cache-Control: private, max-age=300`
- ปี พ.ศ. · วันที่ `YYYY-MM-DD` · เวลาเป็น UTC (แสดงผลแปลงเป็น `Asia/Bangkok`)
- ตัวเรียกฝั่งระบบย่อยเป็นตัวกลางตัวเดียว เพิ่มชุดใหม่ = เพิ่มหนึ่งบรรทัดในรายการชุดข้อมูล
  (reference implementation: `demo-student-subsystem` → โฟลเดอร์ `backend/src/core-hub/` · รายการชุดข้อมูลอยู่ที่
  `reference-datasets.ts` · ตัวอย่างการใช้คือระบบจองห้องที่ใช้ห้องของ Core Hub ใน `backend/src/rooms/`)

เกณฑ์ว่าข้อมูลชุดไหนเข้าข่ายเป็น reference data ได้ (6 ข้อ: Core Hub เป็นเจ้าของ · ไม่ใช่ข้อมูล
ส่วนบุคคล · ทุก role เห็นเท่ากัน · มี code คงที่ · เปลี่ยนช้า · หลักพันแถวลงมา) อยู่ในสเปกฉบับเต็ม —
ชุดที่ไม่ผ่านครบ **ห้าม**ใช้รูปแบบนี้

---

## 2. ชุดข้อมูลที่เปิดให้ใช้

| dataset | path | filter เฉพาะชุด | endpoint พิเศษ | สถานะ |
|---|---|---|---|---|
| คณะ | `/api/v1/faculties` | — | — | ✅ |
| สาขาวิชา | `/api/v1/departments` | `facultyCode` | — | ✅ |
| อาคาร | `/api/v1/buildings` | — | — | ✅ |
| ห้อง | `/api/v1/rooms` | `buildingCode` · `facultyCode` · `roomType` · `floor` | — | ✅ |
| ภาคการศึกษา | `/api/v1/academic-terms` | `academicYear` | `GET /academic-terms/current` (ยังไม่กำหนด = 404) · `GET /academic-terms/:code/events` (ปฏิทินการศึกษา เรียง `sortOrder`) | ✅ |
| รายวิชา | `/api/v1/courses` | `baseCode` · `departmentCode` · `curriculumCode` · `q` (ค้นรหัส/ชื่อ) | `GET /courses/:code` บอกด้วยว่าวิชาอยู่หลักสูตรไหน กลุ่มไหน ปีไหน และวิชาบังคับก่อน | ✅ |
| หลักสูตร | `/api/v1/curricula` | `departmentCode` | `GET /curricula/:code` (ปริญญา ปรัชญา วัตถุประสงค์ PLO เกณฑ์หน่วยกิต) · `GET /curricula/:code/structure` · `GET /curricula/:code/study-plan` | ✅ |

`roomType`: `LECTURE` · `LAB` · `SEMINAR` · `MEETING` · `PROJECT` · `OFFICE`

> ✅ = endpoint อยู่บน `develop` ของ `csmju-core-hub` แล้ว (ตรวจ 30 ก.ย. 2569) · ข้อมูลชุดแรกมาจาก `master-data.sql`
> ใน repo ของ Core Hub ซึ่งผู้ดูแล deploy โหลดเข้าฐาน — ระบบย่อยไม่ใช้ไฟล์นั้นเอง ·
> ถ้าเอกสารนี้ขัดกับระบบจริง ให้ยึดระบบจริงแล้วแจ้ง PL (หลักเดียวกับ `overview.md` ข้อ 3)

## 3. สิ่งที่**ไม่ใช่** reference data

**ข้อมูลบุคคล (`/api/v1/people` — นักศึกษา · บุคลากร) ไม่อยู่ใต้สัญญานี้:**
เป็นข้อมูลส่วนบุคคล สิทธิ์การเห็นไม่เท่ากัน — **เรียกตรงเฉพาะตอนใช้ ห้าม cache รวมทุกผู้ใช้เด็ดขาด**
(ทุก route ตอบ `Cache-Control: no-store`) และห้ามเก็บชื่อ/อีเมลถาวรในฐานของระบบย่อย

| endpoint | ได้อะไร | ใครเรียกได้ |
|---|---|---|
| `GET /api/v1/people/me` | ข้อมูลของผู้ใช้ที่ login · ยังไม่ผูกบัญชีกับบุคคล = `200` + `data: null` | ทุก role ยกเว้น `guest` (`people:me:read`) |
| `GET /api/v1/people` · `/people/:personCode` · `/people/:personCode/advisors` · `/people/:personCode/advisees` | รายชื่อ · บุคคล · อาจารย์ที่ปรึกษา · นักศึกษาในที่ปรึกษา | `staff` · `lecturer` · `admin` (`people:read`) |
| อีเมลของคนอื่น (`universityEmail`) | ส่งเฉพาะผู้เรียกที่มีสิทธิ์ | `staff` · `lecturer` · `admin` (`people:contact:read`) |

ข้อมูลธุรกิจของระบบย่อย (การจอง · การลงทะเบียน · ครุภัณฑ์คงเหลือ ฯลฯ) เป็นของระบบย่อยเจ้าของ —
ให้เปิด API ตาม `api-conventions.md` เอง ไม่ผ่าน Core Hub
