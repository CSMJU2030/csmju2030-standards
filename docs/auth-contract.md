# auth-contract.md

**Version:** 1.0.0  
**Owner:** PM2 (Auth & Authorization)  
**Applies to:** ทุก Subsystem ที่เชื่อมต่อกับ CSMJU2030 Core

> เอกสารนี้คือ Authentication Contract กลางของ CSMJU2030 ทุก Subsystem ต้องใช้ Authentication Flow, Token และ JWT Payload ตามเอกสารนี้เท่านั้น ห้ามออกแบบ Login/Token Flow ของตนเอง

---

# 1. Authentication Overview

CSMJU2030 ใช้ **Central Authentication / Single Sign-On (SSO)**

ทุก Subsystem ใช้ Login ของ Core ร่วมกัน

```text
User
  |
  v
Subsystem
  |
  | ยังไม่มี Session
  v
Core Login
  |
  | Authentication สำเร็จ
  v
Authorization Code
  |
  v
Subsystem Callback
  |
  v
Token Endpoint
  |
  v
Access Token + Refresh Token
```

Core Login:

```text
https://login.csmju2030.ac.th
```

Token Endpoint:

```text
https://auth.csmju2030.ac.th/oauth/token
```

Subsystem **ห้ามมีหน้า Login ของตัวเอง** และห้ามตรวจสอบ `username/password` เอง ตาม Core Architecture ของโครงการ

---

# 2. Login Flow

เมื่อ User เข้า Subsystem และยังไม่มี Authentication Session:

```text
1. User เข้า Subsystem
2. Subsystem ตรวจว่ามี Session หรือไม่
3. ถ้าไม่มี Session → Redirect ไป Core Login
4. User Login ที่ Core
5. Core ตรวจสอบ Authentication
6. Core สร้าง Authorization Code
7. Core Redirect กลับ Subsystem Callback
8. Subsystem นำ Authorization Code ไปแลก Token
9. Core ส่ง Access Token + Refresh Token กลับมา
10. Subsystem สร้าง Session สำหรับ User
```

Subsystem ต้องใช้:

```text
Authorization Code Flow
```

---

# 3. Authorization Code

หลัง Login สำเร็จ Core จะส่ง Authorization Code กลับมายัง Callback ของ Subsystem

ตัวอย่าง:

```text
https://<subsystem-domain>/auth/callback?code=xxxx
```

Authorization Code:

- ใช้สำหรับแลก Token
- ใช้ได้ครั้งเดียว
- ต้องส่งต่อไปยัง Token Endpoint
- ไม่ใช่ Access Token
- ไม่ควรนำไปใช้เรียก API

---

# 4. Token Endpoint

ทุก Subsystem ต้องใช้ Token Endpoint เดียวกัน:

```http
POST https://auth.csmju2030.ac.th/oauth/token
Content-Type: application/json
```

Request:

```json
{
  "grant_type": "authorization_code",
  "code": "xxxx",
  "redirect_uri": "https://<subsystem-domain>/auth/callback",
  "client_id": "<subsystem-client-id>"
}
```

Field:

| Field | Type | Required | Description |
|---|---|---:|---|
| `grant_type` | string | Yes | ต้องเป็น `authorization_code` |
| `code` | string | Yes | Authorization Code ที่ได้จาก Core |
| `redirect_uri` | string | Yes | Callback URI ของ Subsystem |
| `client_id` | string | Yes | Client ID ของ Subsystem |

ห้าม Subsystem เปลี่ยนชื่อ Field หรือสร้าง Token Endpoint ของตัวเอง

---

# 5. Token Response

เมื่อแลก Authorization Code สำเร็จ Core ต้องตอบ:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "def502...xxxx"
}
```

Field ต้องเป็นดังนี้:

| Field | Type | Required | Description |
|---|---|---:|---|
| `access_token` | string | Yes | Token สำหรับเรียก Protected API |
| `token_type` | string | Yes | ต้องเป็น `Bearer` |
| `expires_in` | integer | Yes | อายุ Access Token เป็นวินาที |
| `refresh_token` | string | Yes | Token สำหรับขอ Access Token ใหม่ |

Access Token ตาม Contract ปัจจุบันมีอายุ:

```text
3600 seconds
= 1 hour
```

ข้อมูลนี้ตรงกับ Auth Contract ปัจจุบัน

---

# 6. Token Error Response

หากแลก Token ไม่สำเร็จ ให้ใช้ OAuth Error Format:

```json
{
  "error": "invalid_grant",
  "error_description": "Authorization code หมดอายุหรือไม่ถูกต้อง"
}
```

ตัวอย่าง Error:

```text
invalid_grant
```

หมายถึง Authorization Code ไม่ถูกต้องหรือหมดอายุ

---

# 7. Access Token Usage

ทุก Protected Request ต้องส่ง Access Token ผ่าน HTTP Header:

```http
Authorization: Bearer <access_token>
```

ตัวอย่าง:

```http
GET /api/v1/equipment-items
Authorization: Bearer eyJhbGciOi...
```

ห้ามส่ง Access Token ผ่าน:

```text
URL Query Parameter
Request Body
Cookie ที่ไม่ได้กำหนดโดย Core Contract
```

---

# 8. Protected Endpoint

Endpoint ที่ต้องรู้ Identity หรือ Permission ของ User ต้องมี Access Token

ตัวอย่าง:

```text
GET    /api/v1/equipment-items
POST   /api/v1/equipment-items
PATCH  /api/v1/equipment-items/123
DELETE /api/v1/equipment-items/123
```

Endpoint ที่ไม่ได้ประกาศเป็น Public ถือเป็น Protected โดย Default ตาม API Convention

---

# 9. Public Endpoint

Endpoint ที่ไม่ต้อง Authentication ต้องประกาศใน `subsystem.yaml`

ตัวอย่าง:

```yaml
public_endpoints:
  - "GET /api/v1/announcements"
  - "GET /health"
```

หากไม่ได้ประกาศ:

```text
Protected by Default
```



---

# 10. JWT Payload

`access_token` เป็น JWT

Payload ต้องมี Field ต่อไปนี้ **เท่านั้น**

```text
sub
username
layer1_role
faculty
iat
exp
```

ห้าม Subsystem:

- เปลี่ยนชื่อ Field
- ลบ Field
- เพิ่ม Field
- เปลี่ยน Type
- สร้าง JWT Format ของตัวเอง

หากต้องการเพิ่ม Field ต้องเสนอ PM2 และแก้ `auth-contract.md` ก่อน

---

# 11. JWT Payload Schema

```json
{
  "sub": "64xxxxxxx",
  "username": "64xxxxxxx",
  "layer1_role": "student",
  "faculty": "science",
  "iat": 1754896400,
  "exp": 1754900000
}
```

Field Definition:

| Field | Type | Required | Description |
|---|---|---:|---|
| `sub` | string | Yes | ต้องมีค่าเท่ากับ `username` |
| `username` | string | Yes | Identity กลางของ User |
| `layer1_role` | enum | Yes | Role ระดับองค์กร |
| `faculty` | string | Yes | รหัสคณะ |
| `iat` | number | Yes | เวลาที่ออก Token เป็น Unix Timestamp |
| `exp` | number | Yes | เวลาที่ Token หมดอายุ เป็น Unix Timestamp |

`username` ต้องใช้ตาม Data Dictionary และห้ามเปลี่ยนเป็น `student_id`, `user_code`, `stdId` หรือชื่ออื่น

---

# 12. Layer 1 Role

`layer1_role` ต้องเป็นค่าใดค่าหนึ่งเท่านั้น:

```text
student
alumni
staff
admin
```

ห้าม Subsystem สร้าง Layer 1 Role ใหม่

ตัวอย่างที่ห้าม:

```text
teacher
lecturer
asset_admin
student_admin
```

Role เหล่านี้ถ้าเป็นสิทธิ์เฉพาะระบบ ต้องอยู่ใน Layer 2 ของ Subsystem

Data Dictionary กำหนด Layer 1 Role เป็น `student | alumni | staff | admin` เท่านั้น

---

# 13. Username

`username` คือ Identity กลางของ CSMJU2030

ตัวอย่าง:

```json
{
  "username": "64123456"
}
```

กฎ:

```text
JWT.sub       = JWT.username
```

และทั้งสองค่าต้องตรงกับ `username` ใน Core

ห้ามใช้:

```text
student_id
user_code
stdId
email
```

แทน `username`

---

# 14. Faculty

`faculty` ต้องใช้ชื่อและ Type ตาม Data Dictionary

ตัวอย่าง:

```json
{
  "faculty": "science"
}
```

ค่าของ Faculty เป็นรหัสมาตรฐานจาก Core

Subsystem ห้ามสร้างรายการ Faculty เองหรือ Hardcode รายการใหม่

---

# 15. JWT Verification

การ Verify JWT Signature เป็นหน้าที่ของ:

```text
API Gateway
```

ไม่ใช่ Subsystem

Flow:

```text
Client
  |
  | Bearer Token
  v
API Gateway
  |
  | Verify JWT
  v
Subsystem Backend
```

เมื่อ Gateway Verify สำเร็จ จะส่ง Identity Context ต่อไปยัง Subsystem

---

# 16. Identity Headers

Gateway จะส่งข้อมูล Identity ให้ Subsystem:

```http
X-User-Id: 64xxxxxxx
X-Layer1-Role: student
X-Faculty: science
```

Mapping:

```text
X-User-Id
    ↓
username

X-Layer1-Role
    ↓
layer1_role

X-Faculty
    ↓
faculty
```

Subsystem ใช้ข้อมูลเหล่านี้ในการทำ Authorization ของ Layer 2 ตาม Auth Contract ปัจจุบัน

---

# 17. Token Expiration

เมื่อ `access_token` หมดอายุ:

```text
API Gateway
     |
     v
HTTP 401 Unauthorized
```

ตาม Auth Contract ปัจจุบัน:

```json
{
  "error": "token_expired"
}
```

อย่างไรก็ตาม API Error Code กลางกำหนดว่า HTTP 401 ใช้:

```text
UNAUTHORIZED
```

และ HTTP 403 ใช้:

```text
FORBIDDEN
```

ดังนั้น `token_expired` ใช้เป็นรายละเอียดของ Authentication Failure ไม่ใช่การสร้าง HTTP Status ใหม่

---

# 18. Refresh Token Flow

ทุก Subsystem ต้องใช้ Refresh Flow เดียวกัน

```text
User
  |
  v
Subsystem
  |
  | Access Token
  v
API Gateway
  |
  | Token Expired
  v
401 Unauthorized
  |
  v
Subsystem Frontend
  |
  | Refresh Token
  v
POST /oauth/token
  |
  v
New Access Token
  |
  v
Retry Original Request
```

---

# 19. Refresh Request

เมื่อได้รับ:

```text
HTTP 401 Unauthorized
```

Subsystem ต้องเรียก:

```http
POST https://auth.csmju2030.ac.th/oauth/token
Content-Type: application/json
```

ด้วย:

```json
{
  "grant_type": "refresh_token",
  "refresh_token": "<refresh_token>"
}
```

`grant_type` ต้องเป็น:

```text
refresh_token
```

---

# 20. Refresh Success

เมื่อ Refresh สำเร็จ Core จะส่ง Access Token ใหม่กลับมา

```json
{
  "access_token": "NEW_ACCESS_TOKEN",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "NEW_REFRESH_TOKEN"
}
```

Subsystem ต้อง:

```text
1. เก็บ Token ใหม่
2. ใช้ Access Token ใหม่
3. Request เดิมซ้ำ
```

Flow:

```text
Request A
   |
   v
401
   |
   v
Refresh
   |
   v
New Token
   |
   v
Retry Request A
   |
   v
Response
```

Auth Contract กำหนดให้ Refresh สำเร็จแล้วลอง Request เดิมซ้ำด้วย Token ใหม่

---

# 21. Refresh Failure

หาก Refresh Token:

```text
หมดอายุ
ถูก Revoke
ไม่ถูกต้อง
Invalid
```

ให้ถือว่า Authentication Session สิ้นสุด

Flow:

```text
Request
  |
  v
401
  |
  v
Refresh
  |
  v
FAILED
  |
  v
Clear Session
  |
  v
Redirect
  |
  v
Core Login
```

User ต้อง Login ใหม่

ตาม Contract ปัจจุบัน หาก Refresh ไม่สำเร็จต้อง Redirect กลับหน้า Login ของ Core

---

# 22. Refresh Flow ต้องเหมือนกันทุก Subsystem

ทุก Subsystem ต้องใช้ Flow นี้:

```text
401
 ↓
Refresh Token
 ↓
Success?
 ├── YES → Update Token → Retry Request
 │
 └── NO  → Clear Session → Core Login
```

ห้ามแต่ละ AIE ออกแบบ Refresh Flow เอง

เหตุผลคือ Core ต้องการให้ทุกระบบมีพฤติกรรม Authentication เหมือนกันและลดช่องโหว่จากการ Implement แตกต่างกัน

---

# 23. Retry Rule

Request เดิมให้ Retry หลัง Refresh สำเร็จเท่านั้น

```text
Original Request
       |
       v
      401
       |
       v
   Refresh
       |
       v
 New Access Token
       |
       v
 Retry Original Request
```

หาก Request ที่ Retry แล้วยังได้รับ:

```text
401
```

ให้หยุด Retry และกลับไป Core Login

ห้ามทำ:

```text
401
 ↓
Refresh
 ↓
401
 ↓
Refresh
 ↓
401
 ↓
Refresh
```

เพื่อป้องกัน Infinite Refresh Loop

---

# 24. 401 และ 403

Authentication และ Authorization ต้องแยกกัน

### 401 Unauthorized

หมายถึง:

```text
ไม่มี Token
Token หมดอายุ
Token ใช้งานไม่ได้
```

API Convention กำหนด:

```text
401 → UNAUTHORIZED
```

### 403 Forbidden

หมายถึง:

```text
มี Token
Authentication สำเร็จ
แต่ไม่มี Permission
```

API Convention กำหนด:

```text
403 → FORBIDDEN
```



---

# 25. Authentication vs Layer 2 Authorization

```text
Authentication
    |
    | "คุณคือใคร?"
    v
Core / Gateway
    |
    v
Identity
    |
    | "คุณมีสิทธิ์ทำอะไร?"
    v
Subsystem
    |
    v
Layer 2 Authorization
```

ดังนั้น:

```text
JWT
  → Identity / Layer 1

Subsystem
  → Layer 2 Permission
```

Subsystem สามารถกำหนด `layer2_role`, `default_role_mapping` และ `role_exceptions` ของตัวเองได้ตาม Data Dictionary โดย `role_exceptions` ต้องผ่าน PM อนุมัติ

---

# 26. Client ID / Client Secret

`client_id` และ `client_secret` เป็น Credential ของ Subsystem ไม่ใช่ของ User

ใช้สำหรับ:

```text
Subsystem → Core API
```

ไม่ใช่:

```text
User → Subsystem API
```

ตัวอย่าง:

```text
Access Token
→ ระบุตัวตน User

Client ID / Secret
→ ระบุ Subsystem
```

Auth Contract ปัจจุบันแยกสอง Credential นี้ไว้อย่างชัดเจน

---

# 27. Authentication Contract Rules

ทุก Subsystem ต้องปฏิบัติตามกฎต่อไปนี้:

```text
1. ใช้ Core Login เท่านั้น

2. ห้ามสร้างหน้า Login เอง

3. ใช้ Authorization Code Flow

4. ใช้ Token Endpoint ของ Core

5. ใช้ Access Token จาก Core

6. ใช้ Refresh Token จาก Core

7. ใช้ JWT Payload ตาม Schema ที่กำหนด

8. ห้ามเปลี่ยนชื่อ JWT Field

9. ห้ามเพิ่ม/ลด JWT Field เอง

10. username ต้องใช้ตาม data-dictionary.md

11. layer1_role ต้องใช้ค่ามาตรฐานเท่านั้น

12. ส่ง Access Token ด้วย Authorization: Bearer

13. Gateway เป็นผู้ Verify JWT

14. Subsystem ใช้ Identity ที่ Gateway ส่งให้

15. 401 → Refresh Token

16. Refresh สำเร็จ → Retry Request เดิม

17. Refresh ไม่สำเร็จ → Core Login

18. ห้ามเกิด Infinite Refresh Loop

19. ห้ามสร้าง Authentication Flow ใหม่เอง

20. หากต้องการเปลี่ยน Contract ต้องเสนอ PM2
```

---

# 28. AIE Implementation Checklist

ก่อนส่งระบบให้ PL Review:

```text
- [ ] ใช้ Core Login
- [ ] ไม่มี Login ของตัวเอง
- [ ] ใช้ Authorization Code
- [ ] ใช้ /oauth/token
- [ ] Token Response ตรง Contract
- [ ] JWT Payload ตรง Contract
- [ ] username ตรง data-dictionary.md
- [ ] layer1_role ตรง enum
- [ ] faculty ตรง data-dictionary.md
- [ ] Authorization ใช้ Bearer Token
- [ ] รองรับ 401
- [ ] เรียก Refresh Token เมื่อ Access Token หมดอายุ
- [ ] Refresh สำเร็จ → Retry Request
- [ ] Refresh ล้มเหลว → Redirect Core Login
- [ ] ไม่มี Infinite Refresh Loop
- [ ] ไม่สร้าง JWT เอง
- [ ] ไม่สร้าง Login เอง
- [ ] ไม่ Verify JWT เองที่ Subsystem
```

---

# 29. Contract Change

AIE ไม่มีสิทธิ์แก้ Authentication Contract โดยตรง

หากต้องการ:

```text
เพิ่ม JWT Field
เปลี่ยน JWT Field
เปลี่ยน Token Lifetime
เพิ่ม Grant Type
เปลี่ยน Refresh Flow
เปลี่ยน Login Flow
```

ให้ดำเนินการ:

```text
AIE
 ↓
PL
 ↓
PM2
 ↓
พิจารณา Contract Change
 ↓
แก้ auth-contract.md
 ↓
เพิ่ม Version
 ↓
แจ้งทุก Subsystem
```

จนกว่า Contract ใหม่จะได้รับการอนุมัติ:

> **ให้ใช้ Contract เดิม**

---

# 30. Final Authentication Flow

```text
                         USER
                           |
                           v
                    SUBSYSTEM
                           |
                    No Session
                           |
                           v
                    CORE LOGIN
                           |
                    Authentication
                           |
                           v
                  Authorization Code
                           |
                           v
                 SUBSYSTEM CALLBACK
                           |
                           v
                   POST /oauth/token
                  grant_type=authorization_code
                           |
                           v
             +---------------------------+
             | access_token              |
             | refresh_token             |
             | token_type = Bearer       |
             | expires_in = 3600         |
             +-------------+-------------+
                           |
                           v
                    API GATEWAY
                           |
                     Verify JWT
                           |
                           v
                  SUBSYSTEM BACKEND
                           |
                      Layer 2
                     Permission
                           |
                    +------+------+
                    |             |
                  ALLOW         DENY
                    |             |
                    v             v
                 200/etc        403
                           
เมื่อ Access Token หมดอายุ:

                    API REQUEST
                         |
                         v
                       401
                         |
                         v
                POST /oauth/token
                grant_type=refresh_token
                         |
                 +-------+-------+
                 |               |
               SUCCESS         FAILED
                 |               |
                 v               v
           New Access Token   Clear Session
                 |               |
                 v               v
          Retry Request      Core Login
```

---

# 31. Source of Truth

Authentication Contract ของทุก Subsystem ให้ยึด:

```text
auth-contract.md
        +
data-dictionary.md
        +
api-conventions.md
```

โดย:

```text
auth-contract.md
→ Login / Token / JWT / Refresh

data-dictionary.md
→ username / layer1_role / faculty / field naming

api-conventions.md
→ API path / HTTP status / API error / Public-Protected
```

หากพบความขัดแย้ง:

```text
ห้าม AIE แก้เอง
       ↓
แจ้ง PL
       ↓
PM เจ้าของ Contract พิจารณา
       ↓
แก้ Source of Truth
       ↓
เพิ่ม Version
```

**End of auth-contract.md**