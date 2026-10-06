# Deployment — ขึ้นระบบย่อยบน server

**เวอร์ชัน 1.1** (standards 1.8.1) · ตัวตรวจ `DEP-01..04` · image สร้างด้วย `subsystem-images.yml`

ทุกระบบย่อยจะขึ้น server กลางของรายวิชา (เครื่องเดียวกับ Core Hub `https://csmju2030.jowave.com`)
เอกสารนี้บอกว่า**ทีมต้องเตรียมอะไรใน repo** (ข้อ 3–4, 6) และ**DevOps ทำอะไรบน server** (ข้อ 5, 7)

> **สถานะ:** spec เครื่องและชื่อ subdomain (ข้อ 2) **รออาจารย์อนุมัติ** — แต่ส่วนของทีมทำได้ตั้งแต่ตอนนี้
> และ CI ตรวจ `DEP-01..04` ตั้งแต่ทีมเลื่อนเป็น 1.8.0 · ตัวอย่างที่ผ่านครบ: `demo-student-subsystem`

---

## 1. ภาพรวม

```text
ผู้ใช้ ─https─► Cloudflare ─► Apache (server) ─► <ระบบ>-web  Next.js :3000 ─► <ระบบ>-api  NestJS :4000 ─► PostgreSQL กลาง
                                                  (เปิดผ่าน Apache)            (ไม่เปิดออกนอก)              (ฐานของระบบเอง)
```

แต่ละระบบ = **2 image** ที่ GitHub Actions build จาก repo ของทีมแล้วเก็บไว้ที่ GitHub Container Registry (ghcr.io)
server แค่ดึง image ไปรัน — **ไม่ build บน server** (การ build Next.js ใช้ RAM ราว 1.2 GB ต่อครั้ง)
ฐานข้อมูลไม่ใช่ image ของทีม: DevOps สร้างฐานให้ใน PostgreSQL ตัวกลาง (ข้อ 4)

| ใคร | ทำอะไร |
|---|---|
| ทีม (AIE · PL) | `frontend/Dockerfile` · `backend/Dockerfile` · `.dockerignore` · Next.js standalone · จำกัด connection · ทดสอบด้วย `docker compose` ในเครื่อง (ข้อ 3, 4, 6) |
| DevOps | วาง `images.yml` ในทุก repo · สร้างฐาน + role · compose และ Apache บน server · token สำหรับดึง image (ข้อ 5, 7) |
| PL | ขอ admin ระบบกลางเปลี่ยน callback เป็น `https` ก่อนวันเปิดใช้ (ข้อ 2) |

---

## 2. ชื่อเว็บของแต่ละระบบ (รออนุมัติ)

- **แผน:** `https://<ชื่อในทะเบียน>.jowave.com` เช่น `https://csmju-quiz.jowave.com` — เป็นชื่อชั้นเดียว
  เพราะใบรับรอง https ของ Cloudflare ครอบแค่ `*.jowave.com` (ชื่อสองชั้นอย่าง `quiz.csmju2030.jowave.com` เบราว์เซอร์จะเตือนว่าไม่ปลอดภัย)
- **ห้ามแยกระบบด้วย path** เช่น `csmju2030.jowave.com/quiz` — `/auth/login` `/auth/callback` `/auth/logout`
  ต้องอยู่ที่รากของ origin ([auth-contract](auth-contract.md) ข้อ 5) และเบราว์เซอร์กั้นความปลอดภัยตาม origin ไม่ใช่ตาม path:
  ระบบที่อยู่ origin เดียวกันอ่านหน้าและเรียก API ของกันได้ และได้คุกกี้ของ Core Hub ไปด้วย
- ชื่อในทะเบียน (`name` · [subsystem-registry](subsystem-registry.md) ข้อ 2) จะกลายเป็น subdomain — ใช้ได้ไม่เกิน **63 ตัวอักษร**
- **ตอนเปิดใช้จริง** server ปิดโหมดก่อนเปิดใช้ callback ที่เป็น `http://localhost` ใช้ไม่ได้ทันที —
  PL ขอ admin เปลี่ยน callback เป็น `https://<ชื่อ>.jowave.com/auth/callback` ก่อนวันนั้น ([subsystem-registry](subsystem-registry.md) ข้อ 4)

---

## 3. image ของระบบ (`DEP-01..04`)

### 3.1 สองตัวต่อระบบ

| | web | api |
|---|---|---|
| Dockerfile | `frontend/Dockerfile` — copy จาก [`templates/csmju-subsystem-web/`](../templates/csmju-subsystem-web/) | `backend/Dockerfile` + `backend/docker/entrypoint.sh` — copy จาก `demo-student-subsystem` |
| build context | **รากของ repo** (`docker build -f frontend/Dockerfile .`) | **รากของ repo** (`docker build -f backend/Dockerfile .`) |
| ชื่อ service ใน compose | **`web`** | **`api`** |
| พอร์ตใน container | `3000` | `4000` (env `PORT`) |
| ผู้ใช้ | `node` | `node` |
| ตอนสตาร์ต | `node frontend/server.js` | `prisma migrate deploy` แล้ว `node dist/src/main.js` |
| health | รับการเชื่อมต่อที่ `3000` | `GET /api/health` ตอบ 200 (`API-05`) |
| ออกสู่ภายนอก | ผ่าน Apache เท่านั้น | ไม่เปิด — web ส่ง `/api/*` และ `/auth/*` มาให้ |

พอร์ต `32xx` / `42xx` ของทีมใช้ตอน dev บนเครื่องเดียวเท่านั้น ใน container ทุกระบบใช้ `3000` / `4000` เหมือนกัน
เพราะแต่ละระบบอยู่ใน network ของตัวเอง

build context เป็นรากของ repo เพราะ pnpm เก็บ `pnpm-lock.yaml` ไว้ที่ราก — Dockerfile ทั้งสองตัว copy lockfile
แล้วติดตั้งเฉพาะ package ของตัวเอง (`--filter frontend...` / `--filter backend...`)

### 3.2 `BACKEND_URL` ถูกฝังตอน build

`rewrites()` ใน `next.config.ts` ถูกคำนวณตอน `next build` แล้วฝังลงไฟล์ build —
**ตั้ง `BACKEND_URL` ตอนรัน container แล้วไม่มีผล** (ทดสอบแล้ว: image ยังส่งไปที่ค่าตอน build)

Dockerfile ของ template จึง build ด้วย `BACKEND_URL=http://api:4000` ซึ่งคือ service `api` ใน compose ของระบบเดียวกัน
**ห้ามเปลี่ยนชื่อ service `api` หรือพอร์ต `4000`** · ตอน dev ค่ายังมาจาก `.env.local` (`http://127.0.0.1:42xx`) เหมือนเดิม

หน้าที่ prerender ตอน build (หน้าที่ไม่อ่านคุกกี้) ก็ใช้ `CORE_HUB_WEB_URL` ตอน build เหมือนกัน —
Dockerfile ใส่ค่า server จริงไว้ให้แล้ว (ปุ่ม "กลับ CSMJU Portal")

### 3.3 กฎที่ CI ตรวจ

| รหัส | กฎ | ทำไม |
|---|---|---|
| `DEP-01` | มี `backend/Dockerfile` · และ `frontend/Dockerfile` เมื่อมี `frontend/package.json` | GitHub Actions build image จากไฟล์นี้ (ข้อ 5) |
| `DEP-02` | **stage สุดท้าย**ของ Dockerfile ตั้ง `USER` ที่ไม่ใช่ `root` / `0` | ถ้าโค้ดมีช่องโหว่ ผู้บุกรุกไม่ได้สิทธิ์ root ใน container · `USER` ใน stage ก่อนหน้า**ไม่ตามมา** |
| `DEP-03` | `.dockerignore` ที่รากกัน `**/.env*` (หรือ `**/.env` + `**/.env.*`) และ `**/node_modules` | `.env` มี secret — ติดใน image เท่ากับทุกคนที่ดึง image อ่านได้ · `node_modules` ของ macOS/Windows ใช้บน Linux ไม่ได้ · ต้องมี `**/` เพราะ `.env` เฉย ๆ กันแค่ที่ราก ไม่กัน `backend/.env` |
| `DEP-04` | `frontend/next.config.*` ตั้ง `output: "standalone"` | image มีแค่ server ที่ trace แล้ว (~290 MB) และ Dockerfile copy `.next/standalone` |

ข้ามทั้งหมดเมื่อ repo เพิ่ง scaffold (ยังไม่มี `package.json` ทั้งสองฝั่ง) · ระบบที่ไม่มี UI ต้องมีแค่ `backend/Dockerfile`

### 3.4 ต้องทำตามแม้ไม่มีตัวตรวจ

- **ไม่มี secret ใน Dockerfile** (`ARG` / `ENV`) — ค่าทุกอย่างมาจาก env ตอนรัน (ข้อ 4.2)
- **ระบบไฟล์ของ container อ่านอย่างเดียว** — เขียนได้แค่ `/tmp` · ไฟล์ที่ผู้ใช้อัปโหลดเก็บผ่าน Core Hub
  ([reference-data](reference-data.md) `POST /images`) · ทดสอบด้วย compose ของ demo ซึ่งล็อกแบบเดียวกับ server
- **log ออก stdout เท่านั้น** ([logging](logging.md)) — ห้ามเขียนไฟล์ log
- **ห้าม `chown -R` ทั้งโฟลเดอร์แอป** — Docker เก็บไฟล์ทุกไฟล์ซ้ำอีกชั้น image โตเท่าตัว (user `node` อ่านไฟล์ของ root ได้อยู่แล้ว)
- **ลบ store และ cache ของ pnpm ใน `RUN` เดียวกับ `pnpm install`** — ไม่งั้นติดไปใน image อีกหลายร้อย MB (ดู `backend/Dockerfile` ของ demo)
- **อย่าใส่ `--ignore-scripts` ตอนติดตั้งของ runtime** — `@prisma/engines` ต้องดาวน์โหลด engine ที่ `prisma migrate deploy` ใช้ตอนนั้น
  ถ้าข้าม container จะพยายามดาวน์โหลดตอนสตาร์ตแล้วพัง
- **ตอนสตาร์ตห้าม** `prisma migrate dev` · `prisma db push` · seed ข้อมูลตัวอย่าง — ใช้ `prisma migrate deploy` เท่านั้น
- งานตั้งเวลาต้องระบุ `timeZone: 'Asia/Bangkok'` ([tech-stack](tech-stack.md) ข้อ 1.4.1)

---

## 4. ฐานข้อมูลและ env ตอนรัน

### 4.1 ฐานข้อมูล

- **PostgreSQL 16 ตัวกลาง** บน server (แยกจากฐานของ Core Hub) — DevOps สร้าง **database + role ระบบละ 1 ชุด**
  role เป็นเจ้าของ database ของตัวเองและเข้าฐานอื่นไม่ได้ จึงยังเป็น "1 ระบบ = 1 ฐานข้อมูล" ตามเดิม
- migration รันเองตอน api สตาร์ต (`prisma migrate deploy` ใน `entrypoint.sh`) · migration ที่ขึ้น server แล้วห้ามแก้หรือลบ
- **จำกัด connection ต่อระบบ** ด้วย env `DATABASE_POOL_MAX` (ค่าเริ่มต้น `5`) — `pg` เปิดได้ 10 เส้นต่อระบบโดยค่าเริ่มต้น
  37 ระบบจะต้องใช้ 370 เส้น ซึ่งเกินที่ PostgreSQL รับได้ · ทำแบบ demo (`backend/src/prisma/prisma.service.ts`):

```ts
const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL,
  max: Number(process.env.DATABASE_POOL_MAX) || 5,
});
```

### 4.2 env ที่ server ส่งให้

**api**

| env | ค่าบน server | หมายเหตุ |
|---|---|---|
| `NODE_ENV` | `production` | คุกกี้เป็น `Secure` · backend ตรวจ env เข้มขึ้น |
| `PORT` | `4000` | |
| `DATABASE_URL` | DevOps กำหนด | ฐานของระบบเองเท่านั้น |
| `DATABASE_POOL_MAX` | `5` | ข้อ 4.1 |
| `CORE_HUB_URL` · `CORE_HUB_JWKS_URL` · `CORE_HUB_WEB_URL` | `https://csmju2030.jowave.com` (JWKS: `…/api/v1/.well-known/jwks.json`) | [connect-core-hub](connect-core-hub.md) ข้อ 4 |
| `CORE_HUB_ISSUER` · `CORE_HUB_AUDIENCE` | `core-hub` · `csmju2030` | ค่าตายตัวของสัญญา |
| `SUBSYSTEM_ID` | ชื่อในทะเบียน | |
| `TZ` | `Asia/Bangkok` | |
| ค่าของทีมเอง | ตามที่ทีมแจ้ง | ต้องมีใน `backend/.env.example` · ค่าลับส่งให้ DevOps ทางข้อความส่วนตัว ห้าม commit |

**web** — `CORE_HUB_WEB_URL` · `SUBSYSTEM_ID` · `TZ` (`BACKEND_URL` ฝังใน image แล้ว ข้อ 3.2)

DevOps ใช้ `backend/.env.example` เป็นรายการ env ของระบบ — env ที่ไม่อยู่ในไฟล์นั้นจะไม่ถูกตั้งบน server

---

## 5. image บน GitHub Container Registry

ทุกครั้งที่ push เข้า `main` workflow `.github/workflows/images.yml` ของ repo
(DevOps วางให้ ทีมแก้ไม่ได้ — `GH-03`) เรียก `subsystem-images.yml` ของ standards ซึ่ง build แล้ว push:

| image | จาก | tag |
|---|---|---|
| `ghcr.io/csmju2030/<repo>-api` | `backend/Dockerfile` | `main` · `sha-<commit 7 ตัว>` |
| `ghcr.io/csmju2030/<repo>-web` | `frontend/Dockerfile` | เหมือนกัน |

- **build เมื่อ `.standards-version` เป็น 1.8.0 ขึ้นไปเท่านั้น** — แปลว่า Dockerfile ผ่าน `DEP-01..04` แล้ว ·
  ก่อนหน้านั้น workflow แค่ตรวจเวอร์ชัน (job **Plan**) แล้วข้ามพร้อมแจ้งเตือน ไม่ตก · Dockerfile ที่เขียนก่อนมีข้อกำหนดนี้
  (พอร์ตอื่น · รันเป็น root · ไม่ใช่ standalone) จึงไม่ถูก build ไปจนกว่าทีมจะแก้แล้วเลื่อนเวอร์ชัน
- ยังไม่มี Dockerfile → ข้าม image นั้นพร้อมแจ้งเตือน ไม่ตก
- build เฉพาะ `main` (server ดึง `:main`) · branch อื่นสั่งเองได้ที่ **Actions → Images → Run workflow** ได้ tag ตามชื่อ branch
- image เป็น **private** ตาม repo · server ดึงด้วย token อ่านอย่างเดียว (ข้อ 7)
- ดูผลที่แท็บ **Actions → Images** ของ repo · build ตกให้แก้ใน repo แล้ว merge ใหม่
- **ย้อนเวอร์ชัน:** DevOps ชี้ compose ไปที่ tag `sha-…` ของ commit ก่อนหน้าแล้ว `docker compose up -d`

---

## 6. ทดสอบในเครื่องก่อนเปิด PR

ใช้ `docker-compose.yml` แบบของ demo: service `db` · `api` · `web` (ชื่อต้องตรง ข้อ 3.1) ·
web เปิดที่ `127.0.0.1:<พอร์ต frontend ของทีม>:3000` เพื่อให้ callback `http://localhost:32xx/auth/callback` ที่ลงทะเบียนไว้ยังใช้ได้ ·
api และ web ล็อกแบบเดียวกับ server (`read_only` · `cap_drop: [ALL]` · `no-new-privileges`)

```bash
docker compose up -d --build        # build ทั้งสอง image แล้วรัน db + api + web
docker compose ps                   # ทั้งสามต้อง healthy
docker compose logs api             # ต้องเห็น migration ผ่าน และ subsystem.started
docker stats --no-stream            # ดู RAM
docker compose down                 # หยุด (ข้อมูลยังอยู่ใน volume)
```

- [ ] `./standards/scripts/run-all-checks.sh .` ผ่าน รวม `DEP`
- [ ] `docker compose ps` — `db` `api` `web` เป็น `healthy` ทั้งหมด
- [ ] เปิด `http://localhost:32xx` แล้ว login ผ่าน Core Hub กลับมาได้ (ใช้ Chrome — รับคุกกี้ `Secure` บน `localhost`)
- [ ] `/api/*` ผ่าน web ไปถึง api (`curl http://localhost:32xx/api/health` ตอบ 200)
- [ ] RAM ตอนใช้งานปกติ web + api รวมไม่เกิน **~400 MB** (demo: web ~40 MB · api ~85 MB)

---

## 7. งานของ DevOps

**ครั้งเดียว**

1. ตั้งค่า org: **Settings → Packages → Package creation** ให้สร้าง package แบบ private ได้ ·
   ไม่ต้องเพิ่ม action ใน allow-list — `subsystem-images.yml` ใช้แค่ `actions/checkout` กับคำสั่ง `docker` บน runner
2. รัน `org-settings/add-image-workflow.sh v1.8.1` (dry run) → `--apply --merge`
   — วาง `images.yml` ทุก repo · repo ที่ยังไม่ถึง 1.8.0 จะไม่ build จนกว่าทีมจะเลื่อนเอง
3. บน server: token อ่าน package (classic PAT สิทธิ์ `read:packages` เท่านั้น ของบัญชีที่อ่าน repo ได้) →
   `docker login ghcr.io` · ห้ามเก็บ token ใน repo หรือ log
4. PostgreSQL ตัวกลาง: `max_connections` ไม่น้อยกว่า `จำนวนระบบ × 6 + 20` · network ภายในที่ api ทุกตัวเข้าถึงได้ · backup ด้วย `pg_dump` ทุกฐาน
5. DNS และ Apache ตามที่อาจารย์อนุมัติ (ข้อ 2)

**ต่อระบบ**

```sql
-- ชื่อ role/ฐาน = ชื่อในทะเบียน เปลี่ยน - เป็น _
CREATE ROLE csmju_quiz LOGIN PASSWORD '<สุ่มใหม่ ห้ามใช้ซ้ำ>' CONNECTION LIMIT 6;
CREATE DATABASE csmju_quiz OWNER csmju_quiz;
REVOKE ALL ON DATABASE csmju_quiz FROM PUBLIC;
```

```yaml
# /srv/subsystems/csmju-quiz/compose.yml — ตัวอย่าง (ค่าจริงอยู่ใน api.env บน server เท่านั้น)
name: csmju-quiz
x-hardening: &hardening
  read_only: true
  cap_drop: [ALL]
  security_opt: ['no-new-privileges:true']
  restart: unless-stopped
services:
  api:
    <<: *hardening
    image: ghcr.io/csmju2030/csmju-quiz-api:main
    env_file: ./api.env              # DATABASE_URL · CORE_HUB_* · SUBSYSTEM_ID · ค่าของทีม
    environment: { NODE_ENV: production, PORT: 4000, DATABASE_POOL_MAX: 5, TZ: Asia/Bangkok }
    tmpfs: ['/tmp:size=32m']
    mem_limit: 512m
    networks: [default, subsystems-db]
  web:
    <<: *hardening
    image: ghcr.io/csmju2030/csmju-quiz-web:main
    environment: { CORE_HUB_WEB_URL: 'https://csmju2030.jowave.com', SUBSYSTEM_ID: csmju-quiz, TZ: Asia/Bangkok }
    tmpfs: ['/tmp:size=32m', '/app/frontend/.next/cache:size=64m']
    depends_on: { api: { condition: service_healthy } }
    ports: ['127.0.0.1:<พอร์ตของระบบบน server>:3000']   # Apache ส่ง <ชื่อ>.jowave.com มาที่นี่
    mem_limit: 384m
networks:
  subsystems-db: { external: true }
```

- อัปเดตหลังทีม merge: `docker compose pull && docker compose up -d` (ตั้งเวลาหรือสั่งเอง) · ลบ image เก่าเป็นระยะ (`docker image prune`)
- ขนาดโดยประมาณต่อระบบ: web ~290 MB · api ~800 MB (ส่วนใหญ่คือ Prisma CLI ที่ใช้รัน migration)
