# Authentication Contract

**เวอร์ชัน 1.1** · เจ้าของ: ทีม Core Hub · เอกสารนี้แทนที่ฉบับ OAuth2/Gateway เดิมทั้งฉบับ

> ฉบับก่อนหน้าอธิบายสถาปัตยกรรมที่ยังไม่มีจริง (API Gateway, `/oauth/token`, authorization code)
> ฉบับนี้เขียนจาก **Core Hub ที่รันได้จริง** และมี reference implementation ผ่าน conformance 69/69 ของ 1.1 รองรับ

---

## 1. ภาพรวม

CSMJU2030 ใช้ **Central Authentication / SSO** — ผู้ใช้ login ที่ Core Hub ที่เดียว

```text
User
  │  login
  ▼
Core Hub  ──────────────► ออก access token (RS256) + refresh token
  │                        เผยแพร่กุญแจสาธารณะที่ JWKS
  │  SSO handoff
  ▼
Subsystem ──► ดึง JWKS ──► ตรวจลายเซ็น + claim ──► แมป role ──► ให้เข้าใช้งาน
```

ระบบย่อย **ห้าม**มีหน้า login ของตัวเอง ห้ามเก็บรหัสผ่าน และห้ามออก JWT เอง

**การตรวจ JWT เป็นหน้าที่ของระบบย่อย** — ปัจจุบันยังไม่มี API Gateway กลาง
ระบบย่อยจึงต้องตรวจเองด้วยกุญแจสาธารณะจาก JWKS ตามขั้นตอนข้อ 4

---

## 2. ค่าคงที่ของสัญญา (ห้ามเปลี่ยน)

```text
Algorithm : RS256
Issuer    : core-hub
Audience  : csmju2030
Key ID    : core-hub-2026
JWKS      : GET  {CORE_HUB_URL}/api/v1/.well-known/jwks.json
Login     : POST {CORE_HUB_URL}/api/v1/auth/login   { email, password }
อายุ access token  : 15 นาที
อายุ refresh token : 7 วัน
```

ค่าทั้งหมดอยู่ในไฟล์ [`../contracts/jwt-contract.json`](../contracts/jwt-contract.json) — ให้โค้ดอ่านจากไฟล์/env ไม่ใช่พิมพ์ค่าเอง

---

## 3. Access Token

`access_token` เป็น JWT ลงนามด้วย RS256

**Header**

```json
{ "alg": "RS256", "typ": "JWT", "kid": "core-hub-2026" }
```

**Payload**

```json
{
  "sub": "user-002",
  "email": "student@core.local",
  "role": "student",
  "sid": "e9c0…",
  "iss": "core-hub",
  "aud": "csmju2030",
  "iat": 1789027279,
  "exp": 1789028179
}
```

| Field | Type | ความหมาย |
|---|---|---|
| `sub` | string | **Global Identity** — id ผู้ใช้ของ Core Hub · เป็นตัวตนเดียวที่ระบบย่อยเชื่อได้ |
| `email` | string | อีเมลของผู้ใช้ |
| `role` | enum | core role: `student` · `alumni` · `staff` · `admin` |
| `sid` | string | session id ของ Core Hub |
| `iss` / `aud` | string | `core-hub` / `csmju2030` |
| `iat` / `exp` | number | Unix timestamp |

ระบบย่อย **ห้าม** เปลี่ยนชื่อ/เพิ่ม/ลบ field และ **ห้าม**คาดหวัง claim ที่ไม่มีในรายการนี้
(เช่น `faculty`, `username`, `department` **ไม่ได้อยู่ใน token** — ดู [`data-dictionary.md`](data-dictionary.md) ข้อ 1)

---

## 4. การตรวจสอบ token (บังคับครบ 8 ขั้น)

ระบบย่อยต้องทำครบทุกขั้นกับทุก request ที่เข้า route ที่ต้องล็อกอิน

| # | ขั้น | ไม่ผ่าน |
|---|---|---|
| 1 | อ่าน `Authorization: Bearer <token>` (หรือคุกกี้ SSO ตามข้อ 6) | 401 |
| 2 | ถอด **header** เพื่ออ่าน `alg` และ `kid` (ยังไม่เชื่อ payload) | 401 |
| 3 | บังคับ `alg === RS256` — ปฏิเสธ `none`, `HS256` และอัลกอริทึมอื่นทั้งหมด | 401 |
| 4 | หา public key จาก JWKS ตาม `kid` | 401 |
| 5 | ตรวจลายเซ็น (ระบุ algorithm allow-list ซ้ำอีกชั้นตอน verify) | 401 |
| 6 | ตรวจ `iss` และ `aud` | 401 |
| 7 | ตรวจ `exp` (ยอมรับ clock skew ≤ 60 วินาที) | 401 |
| 8 | ต้องมี `sub` ที่ไม่ว่าง | 401 |

**ห้าม**ข้ามขั้นใดขั้นหนึ่งแม้ในโหมด development · **ห้าม**ตรวจด้วย secret/HS256 · **ห้าม**ฮาร์ดโค้ด public key
(CI กฎ `SEC-04` ตรวจข้อนี้)

### 4.1 ข้อกำหนดของ JWKS client

- **ต้อง**แคชกุญแจ ไม่ยิง Core Hub ทุก request (แนะนำ TTL 10 นาที)
- **ต้อง**เลือกกุญแจจาก `header.kid` เสมอ เพื่อรองรับการหมุนกุญแจ (`core-hub-2026` → `core-hub-2027`)
- **ต้อง**รีเฟรช JWKS **หนึ่งครั้ง**เมื่อเจอ `kid` ที่ไม่รู้จัก แล้วถ้ายังไม่เจอให้ปฏิเสธ
- **ต้อง**จำกัดอัตราการรีเฟรช (≥ 30 วินาทีต่อครั้ง) เพื่อกัน refresh loop
- **ควร**ใช้กุญแจที่แคชไว้ต่อได้เมื่อ Core Hub ล่มชั่วคราว
- **ต้อง**ปฏิเสธ JWK ที่มี private material (`d`) หรือไม่ใช่ `kty: RSA`

### 4.2 รูปแบบ JWKS

Core Hub ตอบเป็น **RFC 7517 ดิบ** — `{"keys":[...]}` ที่ระดับบนสุด ไม่มี envelope ครอบ
(endpoint นี้ถูกยกเว้นจาก response envelope ของ Core Hub โดยเจตนา เพื่อให้ library มาตรฐานทุกภาษาใช้ได้)

```json
{ "keys": [ { "kty": "RSA", "n": "...", "e": "AQAB", "kid": "core-hub-2026", "use": "sig", "alg": "RS256" } ] }
```

---

## 5. Central SSO Flow

**ทุกการเข้าสู่ระบบเริ่มที่ระบบย่อย** (`GET /auth/login`) — มีแต่ระบบย่อยที่รู้ว่าตัวเองเริ่ม
flow ไหนไว้ จึงกัน login CSRF ได้ ระบบย่อยไม่มีหน้าฟอร์มใด ๆ รหัสผ่านกรอกที่ Core Hub เท่านั้น

### เข้าจากระบบย่อย (ทางหลัก)

```text
1. เบราว์เซอร์ → ระบบย่อย  GET /auth/login?next=/courses
2. ระบบย่อยสร้าง state (สุ่ม ≥ 32 ไบต์) ตั้งคุกกี้ <ชื่อ>_sso_state = state + next
   → 302  {CORE_HUB_WEB_URL}/sso/authorize?subsystem=<ชื่อ>&state=<state>
3. เว็บ Core Hub ต่ออายุ session ให้เงียบ ๆ ถ้าทำได้ ถ้าไม่มี session พาไป /login แล้วกลับมาข้อ 3
4. เว็บ Core Hub เรียก  GET /api/v1/auth/sso/handoff?subsystem=&state=  (Bearer จากคุกกี้ของเว็บ)
       Core Hub ตรวจ: subsystem มีจริง → APPROVED → ACTIVE → core role อยู่ใน defaultRoleMapping
       ไม่ผ่าน → หน้า /sso/error ของ Core Hub (ไม่ส่งกลับระบบย่อย จึงไม่วน)
5. เว็บ Core Hub → 302 {callback_url ที่ลงทะเบียน}?access_token=…&token_type=Bearer&expires_in=900&state=<state>
6. ระบบย่อยตรวจ state กับคุกกี้ → ตรวจ token ตามข้อ 4 ครบ 8 ขั้น → แมป role
   → ตั้งคุกกี้ <ชื่อ>_access_token = token นั้น → 302 ไปหน้า next ที่เก็บไว้
```

### เข้าจาก sidebar ของ Core Hub

```text
1. ผู้ใช้กดชื่อระบบใน sidebar → เว็บ Core Hub  GET /sso/authorize?subsystem=<ชื่อ>   (ไม่มี state)
2. Core Hub ส่ง callback แบบไม่มี state
3. ระบบย่อยทิ้ง token ไม่ตั้งคุกกี้ → 302 /auth/login
4. ต่อด้วย flow ด้านบนตั้งแต่ข้อ 2 — ผู้ใช้ login อยู่แล้ว ทุกขั้นผ่านไปเองโดยไม่เห็นหน้าอะไร
```

ผู้โจมตีที่ส่งลิงก์ callback พร้อม token ของตัวเองให้เหยื่อ จึงไม่มีทางทำให้เหยื่อได้ session ของผู้โจมตี
ระบบย่อยจะทิ้ง token นั้นแล้วพาเหยื่อไป login เป็นตัวเหยื่อเอง

**endpoint ฝั่ง Core Hub**

| Method & path | ใช้ทำอะไร |
|---|---|
| **เว็บ** `GET /sso/authorize?subsystem=<ชื่อ>[&state=<s>]` | ทางเข้าของเบราว์เซอร์ · ต้อง login ก่อน · เรียก handoff แล้ว 302 ไป callback · ไม่ผ่าน → `/sso/error` · **ส่ง `state` ต่อตรงตัว ห้ามสร้างเอง** |
| **เว็บ** `GET /logout` | หน้ายืนยันออกจาก Core Hub และทุกระบบย่อย · เปิดด้วย GET ต้องไม่ออกจากระบบทันที |
| **API** `GET /api/v1/auth/sso/authorize?subsystem=<name\|id>[&callback_url=][&state=]` | เหมือนกันแต่ต้องมี Bearer ซึ่งเบราว์เซอร์แนบเองไม่ได้ · ใช้กับสคริปต์ |
| **API** `GET /api/v1/auth/sso/handoff?subsystem=…[&state=]` | ตอบ JSON (`redirect_url`, `access_token`, `expires_in`) · เว็บ Core Hub ใช้ตัวนี้ |

**endpoint ฝั่งระบบย่อย** (ทุกระบบต้องมีครบ · อยู่ **นอก** prefix `/api` · public)

| Method & path | ข้อกำหนด |
|---|---|
| `GET /auth/login?next=<path>` | สร้าง state · ตั้งคุกกี้ state · 302 ไป `{CORE_HUB_WEB_URL}/sso/authorize` · ห้ามส่ง `callback_url` ไปด้วย |
| `GET /auth/callback` | ต้องตรงกับ `callback_url` ในทะเบียน · ผลลัพธ์ตามข้อ 5.1 |
| `POST /auth/logout` | ลบคุกกี้ของตัวเองทั้งสอง → `303` ไป `{CORE_HUB_WEB_URL}/logout` |
| `GET /api/v1/me` | (อยู่ใต้ `/api` ต้องมี token) ควรคืน `session.expiresAt` (ISO 8601 จาก `exp`) ให้ frontend ต่ออายุล่วงหน้าได้ |

ทุกคำตอบของ `/auth/*` **ต้อง**มี `Cache-Control: no-store`

### 5.1 กฎของ callback

| callback มาแบบ | ต้องตอบ |
|---|---|
| ไม่มี `access_token` | `400` |
| **ไม่มี `state`** (เริ่มจาก Core Hub) | ทิ้ง token · **ไม่ตั้งคุกกี้ใด ๆ** · `302 /auth/login` · ห้ามแตะคุกกี้ state (แท็บอื่นอาจกำลังรอ callback ของตัวเอง) |
| มี `state` แต่ไม่มีคุกกี้ state หรือไม่ตรงกัน | `401` · **ห้าม redirect ซ้ำ** (เบราว์เซอร์ที่ไม่เก็บคุกกี้จะวนไม่จบ) |
| token ไม่ผ่านการตรวจข้อ 4 | `401` |
| core role ที่ระบบย่อยไม่รับ | `403` |
| ผ่านทุกข้อ | ตั้งคุกกี้ session แล้ว `302` ไปหน้า `next` ที่เก็บไว้ |

- ตั้งคุกกี้ลบ state ไว้**ก่อน**ตรวจ ทุกคำตอบที่มี `state` จึงเผาคุกกี้ state ทิ้งเสมอ (ใช้ได้ครั้งเดียว)
- ทุกกรณีที่ไม่สำเร็จ **ต้องไม่มี** `Set-Cookie` ของคุกกี้ session
- คุกกี้ session ชื่อ **`<ชื่อระบบ>_access_token`** (เปลี่ยน `-` เป็น `_` เช่น `student_service_access_token`)
  เป็น `HttpOnly` + `SameSite=Lax` + `Path=/` · `Secure` เมื่อ `NODE_ENV=production`
  ค่าคือ Core Hub token ตัวที่ verify แล้ว · อายุ `Max-Age` = `exp − ตอนนี้` (ไม่ยาวกว่า token)
- callback **ต้อง**มี `Referrer-Policy: no-referrer` เพิ่ม — URL มี token อยู่
- **ห้าม log URL เต็มของ `/auth/callback`** และห้าม log header `Cookie` ทั้งก้อน ให้ log ได้แค่ path
- ระบบย่อย **ต้องไม่**ออก token หรือ session ของตัวเอง — ไม่มีตาราง session ไม่มี session id แบบสุ่ม
  session คือ Core Hub token ที่ verify แล้วเท่านั้น

### 5.2 `GET /auth/login`

- `state` สุ่มอย่างน้อย **32 ไบต์** เข้ารหัส **base64url**
- เก็บในคุกกี้ **`<ชื่อระบบ>_sso_state`** ค่า `<state>.<next แบบ base64url>` ·
  `HttpOnly` + `SameSite=Lax` + **`Path=/auth/callback`** · `Secure` เมื่อ production · อายุ**ไม่เกิน 600 วินาที**
- เทียบ state ตอน callback ด้วยการเทียบแบบ constant-time
- ชื่อคุกกี้ขึ้นต้นด้วยชื่อระบบ เพราะตอนพัฒนาทุกระบบรันบน `localhost` และคุกกี้ไม่แยกตาม port

**กฎของ `next`** — ใช้ได้เมื่อผ่านครบทุกข้อ ไม่ผ่านให้ใช้หน้า default ของระบบย่อย

1. เป็น string ยาว 1–512 ตัวอักษร
2. ขึ้นต้นด้วย `/` แต่ไม่ขึ้นต้นด้วย `//` และไม่มี `\` (เบราว์เซอร์มองว่า `/\host` เท่ากับ `//host`)
3. ไม่มีอักขระควบคุม (รหัส 0–31 และ 127)
4. แปลงด้วย `new URL(next, origin ของตัวเอง)` แล้ว origin ต้องยังเป็นของตัวเอง
5. ไม่ใช่ `/auth` หรือ path ใต้ `/auth/`

ต้องตรวจ**ซ้ำตอนใช้งาน** — ตรวจตอน `/auth/login` แล้วตรวจอีกครั้งตอน callback ก่อน redirect
เพราะค่าที่เก็บไว้กลับมาจากคุกกี้

---

## 6. การส่ง token มาที่ระบบย่อย

รับได้ 2 ทาง และ **ตรวจเหมือนกันทั้งสองทาง**:

```http
Authorization: Bearer <access_token>                ← API / เครื่องยิงเครื่อง
Cookie: <ชื่อระบบ>_access_token=<access_token>     ← เบราว์เซอร์ที่ผ่าน SSO มาแล้ว
                                                     เช่น student_service_access_token
```

ถ้ามีทั้งคู่ ให้ `Authorization` header มาก่อน

ระบบย่อย **ห้าม**เชื่อ identity จาก request body, query string หรือ custom header
(เช่น `X-User-Id`) — ตัวตนต้องมาจาก claim ที่ผ่านการตรวจลายเซ็นแล้วเท่านั้น

ตอนพัฒนาบน `localhost` เบราว์เซอร์จะส่งคุกกี้ของเว็บ Core Hub (รวม refresh token) มาที่ระบบย่อยด้วย
ระบบย่อย **ต้องไม่**อ่านคุกกี้เหล่านั้น

---

## 7. Token หมดอายุ

- access token อายุ **15 นาที** · คุกกี้ session ของระบบย่อยหมดอายุพร้อมกัน
- เมื่อหมดอายุ API ของระบบย่อย **ต้อง**ตอบ `401` เป็น JSON พร้อม `error.code = "UNAUTHORIZED"`
  **ห้ามตอบ 302 ไป login** — `fetch` ตาม redirect ข้าม origin ไม่ได้
- refresh token **อยู่กับ Core Hub เท่านั้น** — ห้ามส่งให้ระบบย่อย ห้ามระบบย่อยเก็บหรือต่ออายุ token เอง

**Silent re-SSO** — วิธีต่ออายุโดยไม่ถามรหัสผ่านตลอดอายุ session ของ Core Hub (7 วัน)

1. API ตอบ `401` → frontend พาทั้งหน้าไป `/auth/login?next=<path และ query ปัจจุบัน>`
2. วิ่งตาม flow ข้อ 5 เว็บ Core Hub ต่ออายุด้วย refresh token ของตัวเองแล้วส่งกลับมาเอง
3. กลับมาหน้าเดิมภายในไม่ถึง 1 วินาที

กฎของ frontend

- **ต้อง**เป็น top-level navigation (`window.location`) **ห้ามใช้ `fetch`** — ตาม redirect ไป Core Hub ไม่ได้และไม่ได้คุกกี้
- หน้าที่มีฟอร์มกรอกค้าง **ห้าม redirect ทับ** ให้ถามก่อน หรือต่ออายุล่วงหน้าตอนเปลี่ยนหน้าโดยดู `session.expiresAt` จาก `/api/v1/me`
- **กันวน:** ถ้าเพิ่งกลับจาก re-SSO ไม่ถึง 30 วินาทีแล้วยังได้ 401 อีก ให้แสดงปุ่ม "เข้าสู่ระบบอีกครั้ง" แทนการ redirect ซ้ำ
- ถ้า session ของ Core Hub หมดด้วย ผู้ใช้จะเห็นหน้า login ของ Core Hub ซึ่งถูกต้องแล้ว

**ออกจากระบบ** หมายถึงออกทั้งระบบ — `POST /auth/logout` ลบคุกกี้ของระบบย่อยแล้วพาไป `/logout` ของ Core Hub
ออกแค่ระบบย่อยไม่พอ เพราะกดเข้าใหม่ Core Hub ที่ยัง login อยู่ก็จะ SSO กลับมาทันที
ระบบย่อยอื่นที่เปิดค้างยังใช้ token เดิมได้จนหมดอายุ (ไม่เกิน 15 นาที)

---

## 8. 401 กับ 403

| สถานะ | ใช้เมื่อ |
|---|---|
| **401 UNAUTHORIZED** | ไม่รู้ว่าเป็นใคร — ไม่มี token · token เสีย/หมดอายุ/ลายเซ็นผิด/`kid` ไม่รู้จัก |
| **403 FORBIDDEN** | รู้แล้วว่าเป็นใคร แต่ไม่มีสิทธิ์ — รวมถึง core role ที่ระบบย่อยไม่รับ |

**ห้าม**ตอบ 401 แทน 403 หรือ 404 แทน 403 (CI และ conformance ตรวจข้อนี้)

---

## 9. ข้อห้าม

```text
1. สร้างหน้า login หรือฟอร์มรหัสผ่าน · register · refresh ของตัวเอง — ยกเว้น /auth/login และ /auth/logout
   ที่เป็นแค่ตัว redirect ตามข้อ 5 (ต้องมี)
2. เก็บรหัสผ่าน หรือสร้างระบบยืนยันตัวตนที่สอง
3. ถือกุญแจส่วนตัวของ Core Hub หรือคัดลอกไฟล์ .pem เข้ามาใน repo
4. ออก JWT เอง หรือใช้ HS256 แทนสัญญา RS256
5. ยอมรับ alg=none หรืออัลกอริทึมอื่นนอกจาก RS256
6. ฮาร์ดโค้ด public key โดยไม่รองรับ kid
7. เชื่อ identity จาก body / query / custom header
8. ข้ามการตรวจ token เพื่อความสะดวก (แม้ใน dev)
```

---

## 10. การเปลี่ยนสัญญา

AIE ไม่มีสิทธิ์แก้เอกสารนี้เอง

```text
AIE → PL → เจ้าของ Core Hub → อนุมัติ → แก้ auth-contract.md + contracts/*.json
    → ขึ้น VERSION → อัปเดต conformance → แจ้งทุกระบบย่อย
```

จนกว่าสัญญาใหม่จะได้รับอนุมัติ **ให้ใช้สัญญาเดิม**

---

## 11. แผนการเปลี่ยนแปลง

| เวอร์ชัน | เปลี่ยนอะไร | ผลกับระบบย่อย |
|---|---|---|
| 1.0 | RS256 + JWKS + SSO ผ่าน callback_url | — |
| **1.1** (ปัจจุบัน) · ส่งมอบแล้ว | SSO เริ่มที่ระบบย่อย + `state` · Silent re-SSO · logout ทั้งระบบ · error code 9 ค่า | เพิ่ม `/auth/login` `/auth/logout` · แก้ `/auth/callback` · เปลี่ยนชื่อคุกกี้ · ดู `CHANGELOG.md` 1.1.0 |
| 1.x ถัดไป | `aud` จะผูกกับชื่อระบบย่อย | ต้องรับ audience เป็น list ระหว่างเปลี่ยนผ่าน |
| 2.0 | เปลี่ยน handoff เป็น **authorization code + PKCE** และอาจมี API Gateway | ต้องเพิ่มการแลก code ที่ token endpoint |

**ข้อจำกัดที่รู้อยู่แล้วใน 1.1:** token ยังส่งผ่าน URL query ตอน callback (2.0 จะแก้) ·
`aud` ใช้ค่าเดียวร่วมกันทุกระบบย่อย · logout ไปถึงระบบย่อยอื่นช้าสุด 15 นาที (ยังไม่มี back-channel logout) ·
ระหว่างที่ระบบย่อยบางตัวยังอยู่ที่ 1.0 การกดจาก sidebar จะออก token รอบแรกที่ถูกทิ้งไป 1 ใบ

---

## 12. Source of Truth

```text
auth-contract.md          → login / token / JWKS / SSO / callback
authorization.md          → role mapping / permission / 401-403
subsystem-registry.md     → การลงทะเบียนและ callback_url
contracts/jwt-contract.json → ค่าจริงที่โค้ดและ CI อ่าน
```

หากเอกสารขัดกัน ให้ยึด `contracts/*.json` แล้วแจ้ง PL ทันที
