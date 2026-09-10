# Authentication Contract

**เวอร์ชัน 1.0** · เจ้าของ: ทีม Core Hub · เอกสารนี้แทนที่ฉบับ OAuth2/Gateway เดิมทั้งฉบับ

> ฉบับก่อนหน้าอธิบายสถาปัตยกรรมที่ยังไม่มีจริง (API Gateway, `/oauth/token`, authorization code)
> ฉบับนี้เขียนจาก **Core Hub ที่รันได้จริง** และมี reference implementation ผ่านการทดสอบ 62/62 รองรับ

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

```text
1. ผู้ใช้เข้าระบบย่อย แต่ยังไม่มี session
2. ระบบย่อยพาไป Core Hub เพื่อ login
3. ผู้ใช้ login ที่ Core Hub (ได้ access token)
4. เรียก  GET {CORE_HUB}/api/v1/auth/sso/authorize?subsystem=<name>   (Bearer token)
       Core Hub ตรวจ: subsystem มีจริง → APPROVED → ACTIVE → core role เข้าได้ → callback ตรงทะเบียน
5. Core Hub ตอบ 302 ไปยัง callback_url ที่ลงทะเบียนไว้
       {SUBSYSTEM}/auth/callback?access_token=…&token_type=Bearer&expires_in=900[&state=…]
6. ระบบย่อยตรวจ token ตามข้อ 4 ทุกขั้น แล้วแมป role
7. ระบบย่อยตั้ง session ของตัวเอง (คุกกี้ HttpOnly ที่เก็บ Core Hub token)
8. ผู้ใช้ใช้งาน API ของระบบย่อยได้โดยไม่ต้อง login ซ้ำ
```

**endpoint ฝั่ง Core Hub**

| Method & path | ใช้ทำอะไร |
|---|---|
| `GET /api/v1/auth/sso/authorize?subsystem=<name\|id>[&callback_url=][&state=]` | เริ่ม SSO → 302 |
| `GET /api/v1/auth/sso/handoff?subsystem=…` | เหมือนกันแต่ตอบ JSON (`redirect_url`, `access_token`, `expires_in`) สำหรับ frontend/สคริปต์ |

**endpoint ฝั่งระบบย่อย**

| Method & path | ข้อกำหนด |
|---|---|
| `GET /auth/callback` | public · อยู่ **นอก** prefix `/api` · ต้องตรงกับ `callback_url` ในทะเบียน |

### 5.1 กฎของ callback

- ระบบย่อย **ต้อง**ตรวจ token ก่อนตั้ง session เสมอ — token ที่ไม่ผ่าน **ต้อง**ตอบ `401` และ **ต้องไม่**มี `Set-Cookie`
- คุกกี้ session **ต้อง**เป็น `HttpOnly` + `SameSite=Lax` และเป็น `Secure` เมื่อ `NODE_ENV=production`
- คุกกี้ **ต้องไม่**มีอายุยาวกว่า `exp` ของ token
- ชื่อคุกกี้มาตรฐาน: `core_hub_access_token`
- ถ้ามี `state` ส่งมา **ควร**ส่งกลับให้ client ตรวจได้
- ระบบย่อย **ต้องไม่**ออก token ของตัวเอง — session คือ Core Hub token ที่ verify แล้วเท่านั้น

---

## 6. การส่ง token มาที่ระบบย่อย

รับได้ 2 ทาง และ **ตรวจเหมือนกันทั้งสองทาง**:

```http
Authorization: Bearer <access_token>          ← API / เครื่องยิงเครื่อง
Cookie: core_hub_access_token=<access_token>  ← เบราว์เซอร์ที่ผ่าน SSO มาแล้ว
```

ถ้ามีทั้งคู่ ให้ `Authorization` header มาก่อน

ระบบย่อย **ห้าม**เชื่อ identity จาก request body, query string หรือ custom header
(เช่น `X-User-Id`) — ตัวตนต้องมาจาก claim ที่ผ่านการตรวจลายเซ็นแล้วเท่านั้น

---

## 7. Token หมดอายุ

- access token อายุ **15 นาที**
- เมื่อหมดอายุ ระบบย่อย **ต้อง**ตอบ `401` พร้อม `error.code = "UNAUTHORIZED"`
- refresh token **อยู่กับ Core Hub เท่านั้น** — ห้ามส่งให้ระบบย่อย ห้ามระบบย่อยเก็บ
- การต่ออายุใน v1.0: ให้วิ่ง SSO ใหม่ (`sso/authorize`) อีกครั้ง
  แผน v1.1 จะรองรับ **silent re-SSO** เมื่อ Core Hub มี browser session แล้ว

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
1. สร้าง /login, /register, /logout, /refresh ของตัวเอง
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
| **1.0** (ปัจจุบัน) | RS256 + JWKS + SSO ผ่าน callback_url | — |
| 1.1 | `aud` จะผูกกับชื่อระบบย่อย · บังคับเข้าผ่าน SSO เท่านั้น · silent re-SSO | ต้องรับ audience เป็น list ระหว่างเปลี่ยนผ่าน |
| 2.0 | เปลี่ยน handoff เป็น **authorization code + PKCE** และอาจมี API Gateway | ต้องเพิ่มการแลก code ที่ token endpoint |

**ข้อจำกัดที่รู้อยู่แล้วใน 1.0:** token ส่งผ่าน URL query ตอน callback · `aud` ใช้ค่าเดียวร่วมกันทุกระบบย่อย ·
ยังไม่มี SSO logout (logout ที่ Core Hub แล้ว token ที่ระบบย่อยถืออยู่ยังใช้ได้จนหมดอายุ)

---

## 12. Source of Truth

```text
auth-contract.md          → login / token / JWKS / SSO / callback
authorization.md          → role mapping / permission / 401-403
subsystem-registry.md     → การลงทะเบียนและ callback_url
contracts/jwt-contract.json → ค่าจริงที่โค้ดและ CI อ่าน
```

หากเอกสารขัดกัน ให้ยึด `contracts/*.json` แล้วแจ้ง PL ทันที
