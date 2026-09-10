# ภาพรวมสถาปัตยกรรม CSMJU2030

**เวอร์ชันมาตรฐาน:** 1.0 · เอกสารนี้เป็นจุดเริ่มต้น อ่านก่อนไฟล์อื่น

---

## 1. ระบบประกอบด้วยอะไร

```text
                 ┌──────────────────────────────┐
   User ── login │          CORE HUB            │  csmju-core-hub
                 │  Authentication · Session    │
                 │  Core roles · RS256 JWT      │
                 │  JWKS · Subsystem Registry   │
                 │  Central SSO                 │
                 └───────────────┬──────────────┘
                                 │ access token (RS256) + JWKS
              ┌──────────────────┼──────────────────┐
              ▼                  ▼                  ▼
      ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
      │  subsystem A  │  │  subsystem B  │  │  subsystem C  │
      │ ตรวจ JWT เอง   │  │               │  │               │
      │ authz ของตัวเอง│  │               │  │               │
      │ DB ของตัวเอง   │  │               │  │               │
      └───────────────┘  └───────────────┘  └───────────────┘
```

- **1 ระบบย่อย = 1 repository = 1 ฐานข้อมูล = 1 AIE รับผิดชอบ**
- ผู้ใช้ **login ครั้งเดียว**ที่ Core Hub แล้วเข้าได้ทุกระบบย่อยที่มีสิทธิ์

---

## 2. การแบ่งความรับผิดชอบ

| Core Hub เป็นเจ้าของ | ระบบย่อยเป็นเจ้าของ |
|---|---|
| การพิสูจน์ตัวตน (login / password / session / refresh) | business domain และฐานข้อมูลของตัวเอง |
| core role ของผู้ใช้ | subsystem role และ permission ของตัวเอง |
| กุญแจเซ็น JWT และ JWKS | การ **ตรวจสอบ** JWT |
| ทะเบียนระบบย่อย + `callback_url` | API และกฎธุรกิจของตัวเอง |
| **ใครมีสิทธิ์เข้าระบบไหน** | **เข้ามาแล้วทำอะไรได้บ้าง** |

> บรรทัดสุดท้ายคือเส้นแบ่งที่สำคัญที่สุดของมาตรฐานนี้

---

## 3. สถานะสถาปัตยกรรมปัจจุบัน (v1.0)

มาตรฐานนี้อธิบาย **ระบบที่มีอยู่จริงและทดสอบแล้ว** ไม่ใช่ระบบที่วางแผนไว้

| องค์ประกอบ | สถานะ |
|---|---|
| Core Hub (login · JWKS · Registry · SSO) | ✅ ใช้งานได้ |
| ระบบย่อยตรวจ JWT เองผ่าน JWKS | ✅ ใช้งานได้ (reference implementation ผ่าน 62/62) |
| API Gateway ที่ตรวจ JWT แทนระบบย่อย | ❌ **ยังไม่มี** — อย่าออกแบบโดยสมมติว่ามี |
| OAuth2 authorization code + token endpoint | ❌ ยังไม่มี (อยู่ในแผน v2.0) |
| Frontend กลาง / หน้า login แบบเว็บ | ❌ ยังไม่มี (อยู่ในแผน v1.1) |

หากเอกสารใดขัดกับสภาพจริงข้างต้น ให้ยึด **สภาพจริง** และแจ้ง PL เพื่อแก้เอกสาร

---

## 4. อ่านต่อที่ไหน

| ต้องการรู้ | ไฟล์ |
|---|---|
| stack ที่บังคับใช้ + เวอร์ชัน | [`tech-stack.md`](tech-stack.md) |
| โครง repo · branch · commit | [`repo-structure.md`](repo-structure.md) · [`github-workflow.md`](github-workflow.md) |
| JWT · JWKS · SSO · callback | [`auth-contract.md`](auth-contract.md) |
| role mapping · permission · 401/403 | [`authorization.md`](authorization.md) |
| ลงทะเบียนระบบย่อยกับ Core Hub | [`subsystem-registry.md`](subsystem-registry.md) |
| รูปแบบ API · envelope · error code | [`api-conventions.md`](api-conventions.md) |
| ชื่อ field · ชื่อตาราง · migration | [`data-dictionary.md`](data-dictionary.md) |
| log ที่ต้องมี | [`logging.md`](logging.md) |
| เกณฑ์ผ่าน/ไม่ผ่าน และวิธีรัน | [`conformance.md`](conformance.md) |
| ให้ AI ช่วยเขียนโค้ด | [`../ai/AGENTS.md`](../ai/AGENTS.md) |
