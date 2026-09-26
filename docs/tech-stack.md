# มาตรฐาน Tech Stack
**โครงการ:** CSMJU2030 (ระบบ MIS สาขาวิชาวิทยาการคอมพิวเตอร์)
**ดูแลโดย:** ทีม Infrastructure & DevOps

เอกสารฉบับนี้คือข้อกำหนดด้านสถาปัตยกรรมเทคโนโลยี บังคับใช้กับทุกระบบย่อย (Subsystem) โดยอ้างอิงจากแผนสถาปัตยกรรมระบบและการบริหารจัดการทีมพัฒนา (CSMJU2030-PM)

---

## 1. Tech Stack มาตรฐาน (Authorized Technology Stack)

ไม่อนุญาตให้ติดตั้ง Framework นอกเหนือจากนี้:

เวอร์ชันด้านล่างคือเวอร์ชันที่ Core Hub และ reference implementation ใช้จริงและทดสอบผ่านแล้ว

### 1.1 Runtime และเครื่องมือร่วม

| รายการ | เวอร์ชัน | หมายเหตุ |
|---|---|---|
| **Node.js** | `22.x` | ตรงกับ Core Hub |
| **TypeScript** | `^5.9` | เปิด `strictNullChecks` อย่างน้อย |
| **package manager** | **pnpm** | ต้อง commit `pnpm-lock.yaml` · ห้ามมี `package-lock.json` / `yarn.lock` (กฎ `QA-05`) |
| **Docker + docker compose** | — | ต้องมี `Dockerfile` และ `docker-compose.yml` |

### 1.2 Frontend Stack
*   **Core Framework:** **Next.js** (App Router) — `15+`
*   **Language:** **TypeScript**
*   **Styling:** **Tailwind CSS** (ใช้งานร่วมกับ `@csmju2030/design-system` ของ Core)
*   **State / Data Fetching:** Zustand, React Context, Axios หรือ React Query
*   ห้ามมีหน้า login ของตัวเอง — ต้องเข้าผ่าน Core Hub SSO (`auth-contract.md` ข้อ 5)

### 1.3 Backend Stack

| รายการ | เวอร์ชัน | หมายเหตุ |
|---|---|---|
| **NestJS** | `^11` | `@nestjs/common`, `@nestjs/core`, `@nestjs/platform-express` |
| **@nestjs/config** | `^4.0.4` | |
| **Prisma** | **`7.9.1` (pin เป๊ะ ห้ามใส่ `^`)** | `prisma`, `@prisma/client`, `@prisma/adapter-pg` ต้องเป็นเลขเดียวกันทั้งสามตัว |
| **pg** | `^8.23` | driver ที่ `@prisma/adapter-pg` ต้องใช้ |
| **PostgreSQL** | `16+` | ห้ามใช้ MySQL / MongoDB / SQLite |
| **class-validator / class-transformer** | `^0.15.1` / `^0.5.1` | ใช้กับ `ValidationPipe` |
| **jose** | `^5.10` | ตรวจ JWT ผ่าน JWKS — **ห้ามใช้ `passport-jwt` ในระบบย่อย** เพราะไม่รองรับ JWKS + `kid` ตามสัญญา |
| **Jest / ts-jest / supertest** | `^30` / `^29.4` / `^7` | |

*   **Database:** Frontend ห้ามเชื่อมต่อ PostgreSQL ตรงเด็ดขาด ต้องผ่าน Backend ของระบบย่อยเท่านั้น (กฎ `ARC-01`)
*   **ORM:** ใช้ Prisma 7 แบบ **driver adapter** (`PrismaPg`) ตาม reference implementation

---

### 1.4 Dependency whitelist

CI (`ARC-02`) ตรวจ dependency ทุกตัวกับรายการที่อนุญาตใน
[`../scripts/lib/allowed-deps.json`](../scripts/lib/allowed-deps.json)

ต้องการไลบรารีนอกรายการ → เปิด issue ขอเพิ่ม พร้อมเหตุผลว่าแก้ปัญหาอะไร
**ห้าม**แก้ไฟล์ whitelist เองใน PR ของระบบย่อย

#### 1.4.1 งานตั้งเวลา (scheduled job)

งานที่ต้องรันเองตามเวลา เช่น ยกเลิกคำขอที่ค้างเกินกำหนด หรือติดธงรายการที่เกินกำหนดคืน ให้ใช้ `@nestjs/schedule` (อนุญาตตั้งแต่ 1.0.1)
ไลบรารีตั้งเวลาตัวอื่น (`node-cron` · `cron` · `agenda` · `bull`) ยังไม่อนุญาต ให้ใช้ตัวเดียวกันทั้ง platform

ทุกงานต้องทำตาม 3 ข้อนี้

1. **รันซ้ำได้โดยไม่เสียหาย (idempotent)** — ใส่เงื่อนไขทั้งหมดไว้ใน `WHERE` ของคำสั่งเดียว
   เช่น `UPDATE … SET status = 'EXPIRED' WHERE status = 'PENDING' AND expires_at < now()`
   ห้ามดึงรายการออกมาก่อนแล้วค่อยวนแก้ทีละแถว เพราะถ้ามีสอง instance รันพร้อมกัน งานจะถูกทำซ้ำ
2. **ระบุ time zone ทุกครั้ง** — `@Cron('0 2 * * *', { timeZone: 'Asia/Bangkok' })`
   ระบบที่รันใน Docker มักใช้เวลา UTC ถ้าไม่ระบุ งานที่ตั้งไว้ตีสองจะไปรันตอนเก้าโมงเช้าเวลาไทย
3. **ถ้าวันหนึ่งต้องรันหลาย instance** — ครอบงานด้วย `pg_try_advisory_xact_lock` ภายใน `prisma.$transaction`
   เพื่อให้มีแค่ instance เดียวที่ทำงานรอบนั้น ทำได้ทันทีโดยไม่ต้องเพิ่ม dependency และไม่ต้องย้ายไป scheduler กลาง
   (ตอนนี้ระบบย่อยรัน instance เดียว และมาตรฐานยังไม่มี scheduler กลาง)

```ts
await this.prisma.$transaction(async (tx) => {
  // เลขประจำงาน ต้องไม่ซ้ำกับงานอื่นในระบบเดียวกัน
  const [{ locked }] = await tx.$queryRaw<{ locked: boolean }[]>`SELECT pg_try_advisory_xact_lock(4201) AS locked`;
  if (!locked) return; // instance อื่นกำลังทำงานนี้อยู่
  await tx.$executeRaw`UPDATE borrow_requests SET status = 'EXPIRED' WHERE status = 'PENDING' AND expires_at < now()`;
});
```

### 1.5 ข้อยกเว้นของ Core Hub

`csmju-core-hub` **ไม่ใช่**ระบบย่อย จึงไม่อยู่ใต้กฎบางข้อ เพราะเป็นผู้ให้ identity เอง:

| กฎ | Core Hub |
|---|---|
| `SEC-04` ห้ามตรวจ/ออก JWT เอง | ยกเว้น — Core Hub เป็นผู้ออก token และถือกุญแจส่วนตัว |
| `SEC-05` ห้ามมีหน้า login | ยกเว้น — Core Hub คือหน้า login กลาง |
| health path | ใช้ `/api/v1/health` (มีเวอร์ชัน) ต่างจากระบบย่อยที่ใช้ `/api/health` |

---

## 2. นโยบาย Repository (1 ระบบย่อย = 1 Repo)

ตามแผนภาพรวมของโครงการ กำหนดให้ **แต่ละระบบย่อย = 1 repo แยก และมี AIE รับผิดชอบ 1 คนต่อ 1 ระบบย่อย** ดังนั้นโค้ดของระบบย่อยหนึ่งๆ จะรวมอยู่ใน Repository เดียวกัน โดยแบ่งโฟลเดอร์ให้ชัดเจน (ดูแนวทาง Git workflow แบบเจ้าของคนเดียวใน `github-workflow.md` ข้อ 1.4)

**ตัวอย่างโครงสร้าง (เช่น `csmju-equipment`):**
```text
csmju-<subsystem-name>/
├── .github/
│   └── workflows/                    # CI รัน automated compliance ทุกครั้งที่เปิด PR
├── frontend/                         # โค้ด Next.js
├── backend/                          # โค้ด NestJS
├── standards/                        # Git Submodule ดึงไฟล์มาตรฐาน (csmju2030-standards)
├── subsystem.yaml                    # manifest: name · standards_version · callback · probes
├── .standards-version                # เวอร์ชันมาตรฐานที่ผูกอยู่
└── docker-compose.yml
```

รายละเอียดโครงภายใน `backend/` และกฎ branch/commit ดู [`repo-structure.md`](repo-structure.md)

---

## 3. API Contract ระหว่าง Frontend–Backend

เพื่อไม่ให้ frontend/backend หลุดจากกันเมื่อพัฒนาคนละคน:

*   Backend (NestJS) ต้อง generate **OpenAPI/Swagger spec** อัตโนมัติจาก decorator (`@nestjs/swagger`) และ export เป็น `openapi.json` ไว้ใน repo
*   Frontend ห้ามเขียน type ของ API response เอง ให้ generate TypeScript type จาก `openapi.json` (เช่นด้วย `openapi-typescript`) เพื่อให้ type ตรงกับ backend เสมอ
*   ทุกครั้งที่ backend เปลี่ยน endpoint ต้องอัปเดต `openapi.json` ใน PR เดียวกัน — CI ตรวจว่าไฟล์นี้ sync กับโค้ดจริงก่อน merge

---

## 4. System Prompt สำหรับ AI (Tech Stack)

*สำหรับป้อนให้ AI Agent ก่อนเริ่มเขียนโค้ด เพื่อให้ AI ปฏิบัติตามมาตรฐานโปรเจกต์:*

```text
คุณคือ AI Assistant สำหรับเขียนโค้ดในโครงการ CSMJU2030 (1 ระบบย่อย = 1 Repo) กรุณาปฏิบัติตามกฎต่อไปนี้อย่างเคร่งครัด:

1. Tech Stack: 
   - Frontend: บังคับใช้ Next.js (App Router) เท่านั้น ห้ามใช้ Framework อื่น
   - Backend: บังคับใช้ NestJS และ PostgreSQL (ผ่าน Prisma) เท่านั้น
2. Database Isolation: 
   - โค้ดฝั่ง Frontend ห้ามมี Connection String หรือเชื่อมต่อ PostgreSQL ตรงเด็ดขาด
3. Git Submodule: 
   - รับทราบว่าโฟลเดอร์ `standards/` เป็น Submodule ห้าม AI แนะนำให้แก้ไขไฟล์ในนั้นเด็ดขาด
   - ห้ามแก้ไฟล์ใน standards/conformance/ และ standards/contracts/ เพื่อให้ผ่านการตรวจ
5. Authentication:
   - ระบบย่อยต้องตรวจ JWT เองผ่าน JWKS ของ Core Hub ด้วย jose (ยังไม่มี API Gateway)
   - ห้ามสร้าง login/register/refresh ของตัวเอง และห้ามใช้ HS256 หรือกุญแจฮาร์ดโค้ด
   - ให้คัดลอกชั้น auth จาก reference implementation ตาม ai/AGENTS.md ข้อ 2
4. API Contract:
   - เมื่อแก้ backend endpoint ต้องอัปเดต openapi.json ให้ตรงกับโค้ดเสมอ และฝั่ง frontend ต้องใช้ type ที่ generate จาก openapi.json นั้น ห้าม define type ของ API response เอง
```
