# มาตรฐาน Tech Stack
**โครงการ:** CSMJU2030 (ระบบ MIS สาขาวิชาวิทยาการคอมพิวเตอร์)
**ดูแลโดย:** ทีม Infrastructure & DevOps

เอกสารฉบับนี้คือข้อกำหนดด้านสถาปัตยกรรมเทคโนโลยี บังคับใช้กับทุกระบบย่อย (Subsystem) โดยอ้างอิงจากแผนสถาปัตยกรรมระบบและการบริหารจัดการทีมพัฒนา (CSMJU2030-PM)

---

## 1. Tech Stack มาตรฐาน (Authorized Technology Stack)

ไม่อนุญาตให้ติดตั้ง Framework นอกเหนือจากนี้:

### 1.1 Frontend Stack
*   **Core Framework:** **Next.js** (App Router)
*   **Language:** **TypeScript**
*   **Styling:** **Tailwind CSS** (ใช้งานร่วมกับ `@csmju2030/design-system` ของ Core)
*   **State / Data Fetching:** Zustand, React Context, Axios หรือ React Query

### 1.2 Backend Stack
*   **Core Framework:** **NestJS**
*   **Language:** **TypeScript**
*   **Database:** **PostgreSQL** (Frontend ห้ามเชื่อมต่อ Database ตรงเด็ดขาด ต้องผ่าน API Gateway และ Backend)
*   **ORM:** **Prisma** 

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
└── subsystem.yaml
```

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
4. API Contract:
   - เมื่อแก้ backend endpoint ต้องอัปเดต openapi.json ให้ตรงกับโค้ดเสมอ และฝั่ง frontend ต้องใช้ type ที่ generate จาก openapi.json นั้น ห้าม define type ของ API response เอง
```
