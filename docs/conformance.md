# Conformance — เกณฑ์ตัดสินว่าผ่านหรือไม่

**เวอร์ชัน 1.1**

> การตรวจมี 2 ชั้น: **CI (static)** ตรวจซอร์สโค้ด · **conformance (runtime)** ยิงระบบที่รันอยู่จริง
> ระบบย่อยต้องผ่าน **ทั้งสองชั้น**

---

## 1. ระดับ (Level)

| Level | ครอบคลุม | เคส |
|---|---|---|
| **L1 — Identity** | `/api/health` · ไม่มี login ของตัวเอง · `/api/v1/me` · ตรวจ token ครบ 8 ขั้น · 401 ทุกกรณีลบ · role mapping · ไม่รั่วข้อมูลภายใน | ~32 |
| **L2 — Contract** | L1 + response envelope · error code · pagination · 400/403/404 · unknown route | ~47 |
| **L3 — SSO** | L2 + ทะเบียนถูกต้อง · sign-in เริ่มที่ `/auth/login` · callback 3 แบบตาม state · session cookie · ปฏิเสธ token ปลอม · กัน login CSRF และ open redirect · logout | ~69 |

ระบบย่อยที่มี UI **ต้องถึง L3** · ระบบที่เป็น API อย่างเดียวอย่างน้อย **L2**

จำนวนจริงขึ้นกับจำนวนบัญชีทดสอบที่ login ได้ (L1-28/L1-29 นับแยกต่อ role) ให้ยึดตัวเลขจากผลรัน

### รายการ L3

L3 เล่นบทเว็บของ Core Hub เอง: เริ่มที่ `/auth/login` ของระบบย่อย → อ่าน `state` จาก `Location`
และคุกกี้ `<ชื่อ>_sso_state` → เรียก `sso/authorize` ของ API ด้วย Bearer และ state แบบที่เว็บ Core Hub
ทำด้วยคุกกี้ของตัวเอง → เรียก callback พร้อมคุกกี้ state

| ข้อ | ตรวจอะไร |
|---|---|
| L3-01 – L3-05 | ลงทะเบียนแล้ว · `APPROVED` · `ACTIVE` · `callback_url` ตรงกับระบบที่รันอยู่ · มี `defaultRoleMapping` |
| L3-06 · L3-07 | `sso/authorize` (ส่ง state) → 302 ไป callback ที่ลงทะเบียน และส่ง state กลับมาตรงตัว |
| L3-08 | callback ที่ state ตรงกับคุกกี้ → 302 |
| L3-09 | ได้คุกกี้ `<ชื่อ>_access_token` แบบ `HttpOnly` (หาตามชื่อ ไม่ใช่คุกกี้ตัวแรก) |
| L3-10 · L3-11 | คุกกี้อย่างเดียวเรียก `/api/v1/me` ได้ และได้ `sub` ตรงกับ token |
| L3-12 · L3-13 | token ปลอม (ส่ง state และคุกกี้ที่ถูกต้องไปด้วย เพื่อให้ถึงขั้นตรวจ token) → 401 และไม่มีคุกกี้ session |
| L3-14 | callback ที่ไม่มี token → 400 หรือ 401 |
| L3-15 | Core Hub ปฏิเสธ `callback_url` ที่ไม่ตรงทะเบียน → 400 |
| L3-16 | `/auth/login` → 302 ไป `{core_hub_web_url}/sso/authorize` ที่มี `subsystem` และ `state` · ไม่ส่ง `callback_url` |
| L3-17 | `/auth/login` ตั้งคุกกี้ `<ชื่อ>_sso_state` แบบ `HttpOnly` อายุไม่เกิน 600 วินาที |
| L3-18 | callback ที่ token ถูกแต่ไม่มี state (แบบกดจาก sidebar) → 302 ไป `/auth/login` และไม่มีคุกกี้ session |
| L3-19 | callback ที่มี state แต่ไม่ส่งคุกกี้ state → 401 และไม่มีคุกกี้ session |
| L3-20 | state จาก `/auth/login` รอบหนึ่งกับคุกกี้ของอีกรอบ → 401 |
| L3-21 | flow ครบด้วย `next=//evil.example.com` แล้ว `Location` สุดท้ายต้องอยู่ใน origin ของระบบย่อย |
| L3-22 | `POST /auth/logout` → 303 ไป `{core_hub_web_url}/logout` และคุกกี้ session ถูกตั้ง `Max-Age=0` |

L3-16 ต้องใช้ `core_hub_web_url` ใน `subsystem.yaml` (หรือ `--core-hub-web`) ถ้าไม่มีจะตกพร้อมข้อความ
"manifest ไม่มี core_hub_web_url"

---

## 2. วิธีรัน

ต้องรัน Core Hub ทั้ง API และเว็บ และระบบย่อยของตัวเองไว้ก่อน

```bash
# จากรากของ repo ระบบย่อย (มี subsystem.yaml อยู่)
node standards/conformance/run.js

# ระบุ manifest หรือ override ค่าได้
node standards/conformance/run.js --manifest subsystem.yaml --level L2
node standards/conformance/run.js --url http://localhost:3002 --subsystem csmju-equipment --level L1
node standards/conformance/run.js --core-hub-web http://localhost:3100

# ออกรายงาน JSON สำหรับ CI
node standards/conformance/run.js --json      # → conformance-report.json
```

ผลที่ต้องได้:

```text
RESULT: 69 passed · 0 failed · 0 skipped · 0 warnings · retries: 0
✅ CONFORMANT — csmju-equipment meets standard v1.1 L3
```

---

## 3. กฎการนับผล

- **0 failed** เท่านั้นจึงถือว่าผ่าน
- **SKIP ไม่นับว่าผ่าน** — แปลว่า `probes` ใน `subsystem.yaml` ประกาศไม่ครบ ให้ประกาศให้ครบแล้วรันใหม่
- **WARN ไม่ทำให้ตก** แต่ต้องอ่าน:
  - `W-RETRY` — มีคำขอโดน `429` แล้ว runner รอตาม `Retry-After` (ไม่เกิน 5 วินาที) และลองใหม่ 1 ครั้ง
    บรรทัดสรุปแสดง `retries: N` · ค่า rate limit แบบ default ของระบบย่อยต้องผ่านได้โดย `retries: 0`
    **ห้ามผ่อนค่า rate limit เพื่อให้ผ่าน**
  - `W-CODE` — มี error response ที่ `error.code` ไม่อยู่ใน `contracts/error-codes.json`
    **เวอร์ชันถัดไปจะเปลี่ยนเป็น FAIL**
- ถ้าเชื่อว่าเคสใดผิดที่ตัว conformance เอง **ห้ามแก้ไฟล์ใน `standards/`** ให้บันทึกใน `REPORT.md` แล้วแจ้ง PL

---

## 4. runner ทำงานอย่างไร

- ยิงผ่าน HTTP อย่างเดียว (black-box) ไม่อ่านโค้ดภายใน
- ใช้ Node.js 20+ **ไม่มี dependency** จึงรันได้ทุกเครื่องและทุก stack
- login เข้า Core Hub ด้วยบัญชี dev เพื่อขอ token จริง (ดู [`../fixtures/dev-accounts.json`](../fixtures/dev-accounts.json))
- token ด้านลบ (หมดอายุ · iss/aud ผิด · kid ไม่รู้จัก · HS256 · alg=none · payload ถูกแก้) สร้างจาก
  **คู่กุญแจชั่วคราวที่ runner สร้างเอง** — ไม่ต้องใช้และไม่มีวันเห็นกุญแจส่วนตัวของ Core Hub
- อ่าน `Set-Cookie` ทุกตัว (callback ของ 1.1 ตั้ง 2 คุกกี้: ลบ state และตั้ง session) แล้วหาตามชื่อ
- log ไม่พิมพ์ access token — `Location` ที่มี token ถูกตัดเป็น `access_token=<token>`

---

## 5. ความสัมพันธ์กับ CI

| | ตรวจอะไร | รันเมื่อไร |
|---|---|---|
| CI 8 jobs (`scripts/`) | ซอร์สโค้ด: naming · dependency · secret · commit · openapi sync | **ทุก PR** |
| conformance (`conformance/`) | พฤติกรรมจริงผ่าน HTTP | **nightly + ก่อน release** (ต้องมีระบบรันอยู่) |

CI ตรวจว่า "เขียนถูกกฎ" · conformance ตรวจว่า "ทำงานได้จริงตามสัญญา" — ผ่านอย่างเดียวไม่พอ
