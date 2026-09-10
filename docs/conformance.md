# Conformance — เกณฑ์ตัดสินว่าผ่านหรือไม่

**เวอร์ชัน 1.0**

> การตรวจมี 2 ชั้น: **CI (static)** ตรวจซอร์สโค้ด · **conformance (runtime)** ยิงระบบที่รันอยู่จริง
> ระบบย่อยต้องผ่าน **ทั้งสองชั้น**

---

## 1. ระดับ (Level)

| Level | ครอบคลุม | เคส |
|---|---|---|
| **L1 — Identity** | `/api/health` · ไม่มี login ของตัวเอง · `/api/v1/me` · ตรวจ token ครบ 8 ขั้น · 401 ทุกกรณีลบ · role mapping · ไม่รั่วข้อมูลภายใน | ~32 |
| **L2 — Contract** | L1 + response envelope · error code · pagination · 400/403/404 · unknown route | ~47 |
| **L3 — SSO** | L2 + ทะเบียนถูกต้อง · SSO handoff · callback + session cookie · ปฏิเสธ token ปลอม · กัน open redirect | ~62 |

ระบบย่อยที่มี UI **ต้องถึง L3** · ระบบที่เป็น API อย่างเดียวอย่างน้อย **L2**

---

## 2. วิธีรัน

ต้องรัน Core Hub และระบบย่อยของตัวเองไว้ก่อน

```bash
# จากรากของ repo ระบบย่อย (มี subsystem.yaml อยู่)
node standards/conformance/run.js

# ระบุ manifest หรือ override ค่าได้
node standards/conformance/run.js --manifest subsystem.yaml --level L2
node standards/conformance/run.js --url http://localhost:3002 --subsystem csmju-equipment --level L1

# ออกรายงาน JSON สำหรับ CI
node standards/conformance/run.js --json      # → conformance-report.json
```

ผลที่ต้องได้:

```text
RESULT: 62 passed · 0 failed · 0 skipped
✅ CONFORMANT — csmju-equipment meets standard v1.0 L3
```

---

## 3. กฎการนับผล

- **0 failed** เท่านั้นจึงถือว่าผ่าน
- **SKIP ไม่นับว่าผ่าน** — แปลว่า `probes` ใน `subsystem.yaml` ประกาศไม่ครบ ให้ประกาศให้ครบแล้วรันใหม่
- ถ้าเชื่อว่าเคสใดผิดที่ตัว conformance เอง **ห้ามแก้ไฟล์ใน `standards/`** ให้บันทึกใน `REPORT.md` แล้วแจ้ง PL

---

## 4. runner ทำงานอย่างไร

- ยิงผ่าน HTTP อย่างเดียว (black-box) ไม่อ่านโค้ดภายใน
- ใช้ Node.js 20+ **ไม่มี dependency** จึงรันได้ทุกเครื่องและทุก stack
- login เข้า Core Hub ด้วยบัญชี dev เพื่อขอ token จริง (ดู [`../fixtures/dev-accounts.json`](../fixtures/dev-accounts.json))
- token ด้านลบ (หมดอายุ · iss/aud ผิด · kid ไม่รู้จัก · HS256 · alg=none · payload ถูกแก้) สร้างจาก
  **คู่กุญแจชั่วคราวที่ runner สร้างเอง** — ไม่ต้องใช้และไม่มีวันเห็นกุญแจส่วนตัวของ Core Hub

---

## 5. ความสัมพันธ์กับ CI

| | ตรวจอะไร | รันเมื่อไร |
|---|---|---|
| CI 8 jobs (`scripts/`) | ซอร์สโค้ด: naming · dependency · secret · commit · openapi sync | **ทุก PR** |
| conformance (`conformance/`) | พฤติกรรมจริงผ่าน HTTP | **nightly + ก่อน release** (ต้องมีระบบรันอยู่) |

CI ตรวจว่า "เขียนถูกกฎ" · conformance ตรวจว่า "ทำงานได้จริงตามสัญญา" — ผ่านอย่างเดียวไม่พอ
