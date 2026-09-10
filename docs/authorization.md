# Authorization

**เวอร์ชัน 1.0** · คู่กับ [`auth-contract.md`](auth-contract.md)

> Authentication ตอบว่า *"นี่คือใคร"* — Authorization ตอบว่า *"คนนี้ทำอะไรได้"*
> สองเรื่องนี้ต้องแยกชั้นกันในโค้ด

---

## 1. สองชั้นของสิทธิ์

```text
Core JWT  →  Core Role  →  Subsystem Role  →  Permission  →  Business Operation
└── Core Hub ────────┘     └────────── ระบบย่อย ─────────────────────────────┘
```

| ชั้น | ใครตัดสิน | ตัดสินอะไร | ผลเมื่อไม่ผ่าน |
|---|---|---|---|
| **Layer 1** | Core Hub | ผู้ใช้คนนี้ **เข้าระบบย่อยนี้ได้ไหม** | `403` ตั้งแต่ Core Hub (ไม่ redirect) |
| **Layer 2** | ระบบย่อย | เข้ามาแล้ว **ทำอะไรได้บ้าง** | `403` จากระบบย่อย |

---

## 2. Core role (Layer 1)

ค่าปิด 4 ค่า ห้ามเพิ่มเอง:

```text
student · alumni · staff · admin
```

มาจาก claim `role` ใน access token เท่านั้น

---

## 3. Role mapping

ระบบย่อย **ต้อง**แปลง core role เป็น role ของตัวเองด้วยตารางที่ประกาศไว้ชัดเจน
และ **ต้อง**ประกาศตารางเดียวกันนี้ใน Subsystem Registry (`default_role_mapping`)

```ts
// ตัวอย่างจาก reference implementation
export const CORE_ROLE_TO_SUBSYSTEM_ROLE = {
  student: 'STUDENT',
  alumni:  'ALUMNI',
  staff:   'STAFF',
  admin:   'ADMIN',
} as const;
```

- ชื่อ subsystem role ตั้งเองได้ (เช่น ระบบครุภัณฑ์แมป `student → USER`)
- core role ที่ **ไม่มี**ในตาราง = เข้าระบบนี้ไม่ได้ → ตอบ **`403`** (ไม่ใช่ 401)
- **key ของ `default_role_mapping` มีผลบังคับ**: Core Hub ใช้ตรวจตั้งแต่ก่อน redirect
  ถ้าลืมใส่ role ใด ผู้ใช้ role นั้นจะโดน `403` ที่ Core Hub ทันที
- ตารางในโค้ด **ต้องตรงกับ**ทะเบียนเสมอ (ผู้รีวิวตรวจข้อนี้ด้วยตา)

---

## 4. Permission (Layer 2)

รูปแบบชื่อบังคับ:

```text
<resource>:<action>[:own|:any]

student:read:own · student:read:any · course:create · course:delete
enrollment:update:own · equipment:borrow:any
```

- `:own` = ทำได้เฉพาะข้อมูลของตัวเอง · `:any` = ทำได้กับข้อมูลของทุกคน
- นิยาม "ของตัวเอง" มาตรฐาน: **`record.core_user_id === token.sub`**
- guard ตรวจว่ามี permission อย่างน้อยหนึ่งข้อ จากนั้น **service ต้องตรวจ ownership กับข้อมูลจริงอีกชั้น**

```ts
@RequirePermissions(Permission.STUDENT_READ_ANY, Permission.STUDENT_READ_OWN)
@Get(':id')
findOne(@CurrentUser() user, @Param('id') id) {
  return this.students.findOne(user, id);   // ← service ตรวจ ownership ต่อ
}
```

---

## 5. ข้อห้าม

```text
1. ใช้ role === 'admin' เป็นสถาปัตยกรรมสิทธิ์  (ต้องมีชั้น permission จริง)
2. ตรวจ :own แค่ใน guard โดยไม่ดูข้อมูลจริงในชั้น service
3. ตอบ 401 เมื่อสิทธิ์ไม่พอ  (ต้องเป็น 403)
4. ตอบ 404 แทน 403 เพื่อ "ซ่อนข้อมูล"  (มาตรฐานนี้บังคับ 403)
5. อ่าน role จาก body / query / custom header
```

---

## 6. ตัวอย่างเมทริกซ์ (จาก reference implementation)

| Permission | STUDENT | ALUMNI | STAFF | ADMIN |
|---|:-:|:-:|:-:|:-:|
| `student:read:own` | ✅ | ✅ | ✅ | ✅ |
| `student:read:any` | — | — | ✅ | ✅ |
| `student:create` | — | — | ✅ | ✅ |
| `course:read` | ✅ | ✅ | ✅ | ✅ |
| `course:create` / `course:update` | — | — | ✅ | ✅ |
| `course:delete` | — | — | **—** | ✅ |
| `enrollment:create:own` | ✅ | — | ✅ | ✅ |
| `enrollment:update:any` | — | — | ✅ | ✅ |

แต่ละระบบย่อยกำหนดเมทริกซ์ของตัวเอง แต่ **ต้อง**เขียนไว้ในที่เดียว (`src/auth/permissions.ts`)
และ **ต้อง**มี unit test อย่างน้อย 1 เคสของ `403`

---

## 7. Subsystem Exception

กรณีต้องให้สิทธิ์พิเศษรายบุคคล (เช่น นักศึกษาคนหนึ่งเป็นผู้ช่วยแล็บ) ให้ขอผ่าน Registry
ไม่ใช่ฮาร์ดโค้ดใน subsystem — ดู [`subsystem-registry.md`](subsystem-registry.md) ข้อ 5
