# โครงสร้าง Repository

**เวอร์ชัน 1.0** · คู่กับ [`tech-stack.md`](tech-stack.md) ข้อ 2 และ [`github-workflow.md`](github-workflow.md)

---

## 1. repository ของโครงการ

| repository | หน้าที่ | หมายเหตุ |
|---|---|---|
| `csmju-core-hub` | Core Hub — identity · JWKS · Registry · SSO | **ห้ามแก้จากฝั่งระบบย่อย** |
| `csmju2030-standards` | มาตรฐาน + conformance + CI (repo นี้) | ระบบย่อยผูกเป็น submodule |
| `demo-student-subsystem` | **reference implementation** ที่ผ่าน conformance L3 | ใช้เป็นต้นแบบคัดลอกชั้น auth |
| `csmju-<subsystem>` | ระบบย่อยของแต่ละทีม | 1 ระบบ = 1 repo = 1 ฐานข้อมูล = 1 AIE |

การวางโฟลเดอร์ในเครื่อง (แนะนำให้เหมือนกันทุกคน เพื่อให้คำสั่งในเอกสารใช้ได้ตรง ๆ):

```text
csmju2030/
├── csmju-core-hub/           backend/ → รันที่ :3000
├── demo-student-subsystem/   backend/ → รันที่ :3001
├── csmju2030-standards/
└── csmju-<your-subsystem>/   backend/ → รันที่ :3002, :3003, …
```

---

## 2. โครงภายใน repo ของระบบย่อย

```text
csmju-<subsystem>/
├── .github/workflows/compliance.yml   เรียก reusable workflow ของ standards
├── .standards-version                 เวอร์ชันมาตรฐานที่ผูกอยู่ (เช่น 1.0.0)
├── standards/                         git submodule → csmju2030-standards
├── subsystem.yaml                     manifest เดียวที่ CI และ conformance อ่าน
├── pnpm-workspace.yaml                workspace ของ frontend + backend
├── docker-compose.yml
│
├── backend/                           NestJS
│   ├── src/
│   │   ├── main.ts                    setGlobalPrefix('api') + ยกเว้น GET /auth/callback
│   │   ├── app.module.ts
│   │   ├── auth/                      ⬅ คัดลอกจาก reference implementation (ห้ามแก้ตรรกะ)
│   │   │   ├── jwks.service.ts
│   │   │   ├── core-hub-token.verifier.ts
│   │   │   ├── guards/                CoreHubJwtGuard (401) · PermissionsGuard (403)
│   │   │   ├── decorators/            @Public · @RequirePermissions · @CurrentUser
│   │   │   ├── role-mapping.ts        ⬅ แก้ได้เฉพาะค่าในตาราง ให้ตรงกับทะเบียน
│   │   │   ├── permissions.ts         ⬅ permission ของโดเมนตัวเอง
│   │   │   ├── sso-callback.controller.ts
│   │   │   └── me.controller.ts
│   │   ├── common/                    response envelope · exception filter · DTO กลาง
│   │   ├── config/                    configuration + env validation
│   │   ├── prisma/                    PrismaService (Prisma 7 + PrismaPg adapter)
│   │   └── <domain>/                  โมดูลธุรกิจของทีม
│   ├── prisma/
│   │   ├── schema.prisma
│   │   ├── migrations/                ห้ามลบ ห้าม squash
│   │   └── seed.ts
│   ├── test/
│   ├── .env.example                   `.env` ห้าม commit
│   ├── Dockerfile
│   └── package.json
│
└── frontend/                          Next.js (App Router) — ถ้ามี UI
    ├── src/app/
    ├── .env.example
    └── package.json
```

---

## 3. ไฟล์ที่ต้องมีที่ราก repo

| ไฟล์ | ทำไม |
|---|---|
| `subsystem.yaml` | CI อ่าน `name`, `standards_version`, `public_endpoints` · conformance อ่าน `base_url`, `probes` |
| `.standards-version` | กฎ `GH-04` ตรวจว่าตรงกับ submodule pointer |
| `standards/` (submodule) | ดึงกฎกลางมาใช้ ไม่ต้องคัดลอกกฎเข้ามาเก็บเอง |
| `pnpm-workspace.yaml` | กฎ `QA-05` |
| `README.md` | วิธีติดตั้ง/รัน/ทดสอบ ที่คำสั่งใช้ได้จริงทุกบรรทัด |
| `REPORT.md` | ส่งพร้อมงาน (ดู [`../ai/AGENTS.md`](../ai/AGENTS.md) ข้อ 6) |

## 4. ไฟล์ที่ห้ามอยู่ใน git

```text
.env  ·  *.pem  ·  *.key  ·  node_modules/  ·  dist/  ·  generated/  ·  coverage/
package-lock.json  ·  yarn.lock        (ใช้ pnpm-lock.yaml เท่านั้น)
```

---

## 5. Branch และ commit

- branch หลักคือ `main` และต้องอยู่ในสถานะที่ conformance ผ่านเสมอ
- แตก branch: `feature/<subsystem>/<เรื่อง>` · `fix/<subsystem>/<เรื่อง>` · `refactor/<subsystem>/<เรื่อง>`
- commit ใช้ Conventional Commits: `feat(<subsystem>): …` — ชนิดที่อนุญาต `feat|fix|chore|refactor|docs|test|ci`
- รายละเอียดและกฎที่ CI ตรวจ ดู [`github-workflow.md`](github-workflow.md)
