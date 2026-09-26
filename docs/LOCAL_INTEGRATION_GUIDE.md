# ทดสอบเชื่อม 3 ระบบบนเครื่องตัวเอง

**Core Hub · demo-student-subsystem · ระบบย่อยของทีมตัวเอง**

> ร่างตัวอย่าง — อ้างอิง `csmju2030-standards` v1.0.0 และ `main` ของทุก repo ณ 25 ก.ย. 2569
> ตัวอย่างทั้งเอกสารใช้ระบบย่อยชื่อ **`equipment`** (repo `csmju-equipment`) ให้เปลี่ยนเป็นชื่อของทีมตัวเอง

---

## 0. ภาพรวม — จะได้อะไรเมื่อทำจบ

```text
                     ┌──────────────────────────────┐
  เบราว์เซอร์ ──────▶│ Core Hub frontend    :3100    │
                     │ Core Hub backend     :3000    │── JWKS ──┬──────────────┐
                     └──────────────┬───────────────┘          │              │
                                    │ SSO 302 + token          ▼              ▼
                                    ├──────────────▶ demo-student-subsystem  csmju-equipment
                                    │                backend :3001           backend :3002
                                    │                     │                       │
                     PostgreSQL :5432 ── core_hub    demo_student_db         equipment_db
```

### พอร์ตที่ใช้

| พอร์ต | ระบบ | repo |
|---|---|---|
| **3000** | Core Hub backend (API · JWKS · SSO) | `csmju-core-hub/backend` |
| **3100** | Core Hub frontend (หน้า login · เมนูระบบย่อย) | `csmju-core-hub/frontend` |
| **3001** | demo-student-subsystem backend | `demo-student-subsystem/backend` |
| **3002** | ระบบย่อยของทีมตัวเอง | `csmju-equipment/backend` |
| **5432** | PostgreSQL — 3 ฐานข้อมูลแยกกัน | — |

> **3001 ห้ามให้อย่างอื่นใช้** — เป็น `callback_url` ที่ Core Hub ลงทะเบียนให้ demo ไว้ตั้งแต่ seed
> ทีมถัดไปใช้ 3003, 3004, … ตามลำดับ

ต้องเปิด **4 terminal** ค้างไว้พร้อมกัน (Core Hub backend · Core Hub frontend · demo · ระบบตัวเอง)

---

## 1. เตรียมเครื่อง

| ต้องมี | ตรวจด้วย | หมายเหตุ |
|---|---|---|
| Node.js **22.x** | `node -v` | |
| **pnpm** | `pnpm -v` | ติดตั้งด้วย `corepack enable pnpm` · ห้ามใช้ npm/yarn |
| PostgreSQL **16+** | `psql --version` | หรือใช้ Docker ก็ได้ ดูข้อ 3 |
| git | `git --version` | |
| openssl | `openssl version` | ใช้สร้างกุญแจของ Core Hub |
| `gh` (ไม่บังคับ) | `gh auth status` | ใช้ตอนสร้าง repo ของทีมในข้อ 6 |

---

## 2. Clone และจัดโครงสร้างโฟลเดอร์

มาตรฐานกำหนดให้ **ทุก repo อยู่ระดับเดียวกันในโฟลเดอร์เดียว** (`repo-structure.md` ข้อ 1)
สคริปต์หลายตัวอ้าง path แบบ `../csmju2030-standards` ถ้าวางผิดที่จะรันไม่ได้

```bash
mkdir csmju2030 && cd csmju2030
```

```bash
git clone https://github.com/CSMJU2030/csmju2030-standards.git
```

```bash
git clone https://github.com/CSMJU2030/csmju-core-hub.git
```

```bash
git clone --recurse-submodules https://github.com/CSMJU2030/demo-student-subsystem.git
```

> **`--recurse-submodules` จำเป็นสำหรับ demo** — โฟลเดอร์ `standards/` ข้างในเป็น submodule
> ถ้าลืมจะได้โฟลเดอร์ว่าง และสคริปต์ตรวจกับ conformance จะรันไม่ได้
> แก้ทีหลังได้ด้วย `git -C demo-student-subsystem submodule update --init --recursive`

ผลที่ต้องได้:

```text
csmju2030/
├── csmju2030-standards/
├── csmju-core-hub/
│   ├── backend/          :3000
│   └── frontend/         :3100
├── demo-student-subsystem/
│   ├── backend/          :3001
│   └── standards/        (submodule → v1.0.0)
└── csmju-equipment/      (สร้างในข้อ 6)
```

---

## 3. สร้างฐานข้อมูล 3 ก้อน

**หนึ่งระบบ = หนึ่งฐานข้อมูล** ห้ามใช้ร่วมกัน (กฎ `ARC-01`)

```bash
createdb core_hub && createdb demo_student_db && createdb equipment_db
```

ตรวจ:

```bash
psql -lqt | cut -d'|' -f1 | grep -E "core_hub|demo_student_db|equipment_db"
```

> ใช้ Docker แทนได้ — `demo-student-subsystem` มี `docker-compose.yml` ที่เปิด PostgreSQL ไว้ที่พอร์ต **5433**
> ถ้าใช้แบบนั้น ให้แก้ `DATABASE_URL` ของ demo ในข้อ 5 เป็น `:5433` ส่วนที่เหลือใช้ 5432 เหมือนเดิม

---

## 4. Core Hub — :3000 และ :3100

### 4.1 สร้างคู่กุญแจ RSA (ครั้งเดียว)

กุญแจส่วนตัว**ไม่ได้อยู่ใน git** ถ้าไม่สร้าง backend จะล้มตอนเปิดด้วย `ENOENT: keys/jwt-private.pem`

```bash
cd csmju-core-hub/backend && mkdir -p keys
```

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out keys/jwt-private.pem
```

```bash
openssl rsa -in keys/jwt-private.pem -pubout -out keys/jwt-public.pem
```

### 4.2 ตั้งค่า environment

```bash
cp .env.example .env
```

แก้ `DATABASE_URL` ใน `backend/.env` ให้ตรงกับ PostgreSQL ของเครื่องตัวเอง:

```bash
DATABASE_URL="postgresql://<user>:<password>@localhost:5432/core_hub"
```

**`NODE_ENV` ต้องเป็น `development`** — ถ้าเป็น `production` Core Hub จะปฏิเสธ `callback_url` ที่เป็น `http://localhost` ทุกกรณี และจะลงทะเบียนระบบย่อยในข้อ 6 ไม่ได้

```bash
cd ../frontend && cp .env.example .env
```

(ค่าในนั้นใช้ได้เลย: `BACKEND_API_URL=http://127.0.0.1:3000/api/v1` · `PORT=3100`)

### 4.3 ติดตั้ง · สร้างตาราง · ใส่ข้อมูลเริ่มต้น

```bash
cd .. && pnpm install
```

`postinstall` จะรัน `prisma generate` ให้เอง ไม่ต้องสั่ง

```bash
pnpm --filter core-api exec prisma migrate deploy
```

```bash
pnpm --filter core-api build && (cd backend && node dist/prisma/seed.js)
```

> seed ต้องรันจาก `dist/` หลัง build — อย่าใช้ `ts-node prisma/seed.ts` จะล้มด้วย `Cannot find module './internal/class.js'`

seed จะสร้างผู้ใช้ทดสอบ 4 คน และลงทะเบียน `student-service` (demo) ไว้ให้แล้ว:

| email | password | role |
|---|---|---|
| `admin@core.local` | `password1` | admin |
| `student@core.local` | `password2` | student |
| `staff@core.local` | `password3` | staff |
| `alumni@core.local` | `password4` | alumni |

บัญชีชุดนี้**ต้องตรงกับ** `csmju2030-standards/fixtures/dev-accounts.json` เพราะ conformance ใช้ login ตอนทดสอบ

### 4.4 รัน (2 terminal)

**Terminal 1 — backend :3000**

```bash
cd csmju2030/csmju-core-hub && pnpm --filter core-api start:dev
```

**Terminal 2 — frontend :3100**

```bash
cd csmju2030/csmju-core-hub && pnpm --filter frontend dev
```

### 4.5 ตรวจว่าใช้ได้

```bash
curl -s http://localhost:3000/api/v1/health
```

```bash
curl -s http://localhost:3000/api/v1/.well-known/jwks.json
```

JWKS ต้อง**ขึ้นต้นด้วย `{"keys":[`** ตรง ๆ — ถ้าเห็น `{"success":true,"data":...}` แปลว่าผิด ระบบย่อยทุกตัวจะตอบ 401

เปิด http://127.0.0.1:3100 แล้ว login ด้วย `admin@core.local` ได้ = Core Hub พร้อม

---

## 5. demo-student-subsystem — :3001

```bash
cd csmju2030/demo-student-subsystem/backend && cp .env.example .env
```

แก้ `backend/.env` สองจุด:

```bash
DATABASE_URL=postgresql://<user>:<password>@localhost:5432/demo_student_db
```

> ค่าเริ่มต้นใน `.env.example` เป็นพอร์ต **5433** (สำหรับ Docker) ถ้าใช้ PostgreSQL ในเครื่องต้องเปลี่ยนเป็น **5432**

ค่า `CORE_HUB_URL=http://localhost:3000` และ `PORT=3001` ใช้ได้เลย ไม่ต้องแก้

```bash
cd .. && pnpm install
```

```bash
pnpm --filter backend exec prisma migrate deploy
```

**Terminal 3 — demo :3001**

```bash
cd csmju2030/demo-student-subsystem && pnpm --filter backend start:dev
```

ตรวจ:

```bash
curl -s http://localhost:3001/api/health
```

ต้องได้ `"service":"student-service"` ซึ่งตรงกับชื่อในทะเบียนของ Core Hub

---

## 6. ระบบย่อยของทีมตัวเอง — :3002

### 6.1 สร้าง repo ด้วยสคริปต์ของมาตรฐาน

**รันจากโฟลเดอร์ `csmju2030/`** — สคริปต์สร้างโฟลเดอร์ใหม่ไว้ในที่ที่สั่งรัน จะได้วางถูกที่ทันที

```bash
cd csmju2030 && ./csmju2030-standards/new-subsystem.sh equipment "ระบบครุภัณฑ์"
```

สคริปต์สร้างไฟล์มาตรฐาน → **ตรวจ compliance กับสิ่งที่เพิ่งสร้าง 15 ข้อ** → `git init` + commit แรก → สร้าง repo บน GitHub → ผูก `standards/`

| มี `gh` | ไม่มี `gh` |
|---|---|
| ทำครบทุกขั้น | สคริปต์หยุดที่ `gh repo create` — ไฟล์และ commit แรกสร้างเสร็จแล้ว แต่**ยังไม่มี submodule** |

ถ้าไม่มี `gh` ให้ผูก submodule เอง (ทดสอบในเครื่องได้โดยไม่ต้องมี repo บน GitHub):

```bash
cd csmju-equipment && git submodule add https://github.com/CSMJU2030/csmju2030-standards.git standards
```

```bash
git -C standards checkout -q v1.0.0 && git add .gitmodules standards && git commit -m "chore(equipment): pin standards submodule at v1.0.0"
```

### 6.2 วางโค้ดเริ่มต้น (เร็วที่สุดสำหรับทดสอบการเชื่อมต่อ)

สคริปต์ให้แค่โครงเปล่า (`backend/src/.gitkeep`) — วิธีที่เร็วและถูกต้องตามมาตรฐานคือ**ตั้งต้นจาก demo**
เพราะชั้น auth ต้องคัดลอกจาก reference implementation อยู่แล้ว (`aie-workflow.md` ขั้น 4)

(คำสั่งในข้อนี้รันจากในโฟลเดอร์ `csmju-equipment/`)

```bash
rsync -a --exclude node_modules --exclude dist --exclude generated --exclude .env ../demo-student-subsystem/backend/ backend/
```

> ได้ทั้งโค้ด ชั้น auth และ schema ของ demo (ตาราง students) มาเป็นจุดตั้งต้น — พอทดสอบการเชื่อมต่อผ่านแล้ว
> ค่อยเปลี่ยน schema/API เป็นของโดเมนตัวเอง **โดยไม่แตะไฟล์ใน `backend/src/auth/`** ยกเว้น `role-mapping.ts` กับ `permissions.ts`

```bash
cp ../demo-student-subsystem/package.json ../demo-student-subsystem/pnpm-workspace.yaml .
```

แก้ 4 ไฟล์ให้เป็นของระบบตัวเอง:

**`package.json` (ที่ราก)** — เปลี่ยน `name` ให้ไม่ซ้ำกับ `backend` (ไม่งั้นโดนกฎ `QA-06`)

```json
"name": "csmju-equipment"
```

**`pnpm-workspace.yaml`** — ต้องมีส่วน `allowBuilds` ติดมาด้วย ไม่งั้น pnpm บล็อก postinstall ของ Prisma

**`subsystem.yaml`** — แก้เฉพาะส่วนหัว เก็บ `probes` ของ demo ไว้ (ใช้ได้เพราะโค้ดเป็นชุดเดียวกัน)

```yaml
name: csmju-equipment
base_url: http://localhost:3002
display_name: "ระบบครุภัณฑ์"
repo: github.com/CSMJU2030/csmju-equipment
```

**`backend/src/auth/role-mapping.ts`** — ต้อง**ตรงกับ** `defaultRoleMapping` ที่จะลงทะเบียนในข้อ 6.4 เป๊ะ

### 6.3 ตั้งค่า environment

```bash
cp backend/.env.example backend/.env
```

แก้ `backend/.env`:

```bash
PORT=3002
DATABASE_URL=postgresql://<user>:<password>@localhost:5432/equipment_db
SUBSYSTEM_ID=csmju-equipment
SUBSYSTEM_NAME=ระบบครุภัณฑ์
```

`SUBSYSTEM_ID` ต้องตรงกัน**สามที่**: ไฟล์นี้ · `name` ใน `subsystem.yaml` · ชื่อในทะเบียน Core Hub

```bash
pnpm install && pnpm --filter backend exec prisma migrate deploy
```

### 6.4 ลงทะเบียนกับ Core Hub

**ขอ token ของ admin:**

```bash
TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"admin@core.local","password":"password1"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])")
```

**สร้างทะเบียน** — ตัวอย่างนี้ตั้งใจ**ไม่ใส่ `alumni`** เพื่อใช้ทดสอบกรณีโดนปฏิเสธในข้อ 7

```bash
curl -s -X POST http://localhost:3000/api/v1/subsystems -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' -d '{"name":"csmju-equipment","displayName":"ระบบครุภัณฑ์","owner":"admin","repo":"CSMJU2030/csmju-equipment","standardsVersion":"1.0.0","callbackUrl":"http://localhost:3002/auth/callback","defaultRoleMapping":{"student":"STUDENT","staff":"STAFF","admin":"ADMIN"},"requestedExceptions":[]}'
```

จด `id` ที่ได้กลับมา แล้ว approve + activate:

```bash
curl -s -X POST http://localhost:3000/api/v1/subsystems/<ID>/approve -H "Authorization: Bearer $TOKEN"
```

```bash
curl -s -X POST http://localhost:3000/api/v1/subsystems/<ID>/activate -H "Authorization: Bearer $TOKEN"
```

| พลาดบ่อย | ผล |
|---|---|
| ไม่ส่ง `requestedExceptions` | 400 — ฟิลด์นี้บังคับ ไม่มีคำขอก็ต้องส่ง `[]` |
| `callbackUrl` ไม่ใช่ URL เต็ม | 400 — ต้องมี `http://` |
| ลืม approve หรือ activate | เข้า SSO ไม่ได้ และไม่ขึ้นในเมนูของ Core Hub |

> seed ของ Core Hub ลงทะเบียนให้แค่ `student-service` — ฐานข้อมูลใหม่จะไม่ชนชื่อ
> แต่ถ้าใช้ฐานข้อมูลเก่าที่เคยมีชื่อนี้อยู่ จะได้ `409 Subsystem name already exists`
> ให้แก้ของเดิมด้วย `PATCH /api/v1/subsystems/<ID>` ส่ง `{"callbackUrl":"http://localhost:3002/auth/callback"}` แทน

### 6.5 รัน

**Terminal 4 — ระบบตัวเอง :3002**

```bash
cd csmju2030/csmju-equipment && pnpm --filter backend start:dev
```

```bash
curl -s http://localhost:3002/api/health
```

ต้องได้ `"service":"csmju-equipment"`

---

## 7. ทดสอบการเชื่อมต่อ

ตั้งตัวช่วยไว้ก่อน (ใช้ต่อทุกข้อ):

```bash
login() { curl -s -X POST http://localhost:3000/api/v1/auth/login -H 'Content-Type: application/json' -d "{\"email\":\"$1@core.local\",\"password\":\"$2\"}" | python3 -c "import sys,json;print(json.load(sys.stdin)['data']['access_token'])"; }
```

```bash
ADMIN=$(login admin password1) && STUDENT=$(login student password2) && ALUMNI=$(login alumni password4)
```

### ตารางทดสอบ

| # | ทดสอบ | คำสั่ง | ผลที่ต้องได้ |
|---|---|---|---|
| T1 | JWKS เป็นรูปแบบดิบ | `curl -s localhost:3000/api/v1/.well-known/jwks.json` | ขึ้นต้น `{"keys":[` |
| T2 | demo รับ token ของ Core Hub | `curl -s localhost:3001/api/v1/me -H "Authorization: Bearer $STUDENT"` | `"subsystemRole":"STUDENT"` |
| T3 | ระบบตัวเองรับ token เดียวกัน | `curl -s localhost:3002/api/v1/me -H "Authorization: Bearer $STUDENT"` | `"subsystemRole":"STUDENT"` |
| T4 | ไม่มี token | `curl -s -o /dev/null -w '%{http_code}' localhost:3002/api/v1/me` | `401` |
| T5 | token ปลอม | `curl -s -o /dev/null -w '%{http_code}' localhost:3002/api/v1/me -H "Authorization: Bearer abc.def.ghi"` | `401` |
| T6 | SSO ไป demo | `curl -s -D - -o /dev/null "localhost:3000/api/v1/auth/sso/authorize?subsystem=student-service&state=t6" -H "Authorization: Bearer $ADMIN" \| grep -i location` | `Location: http://localhost:3001/auth/callback?...` |
| T7 | SSO ไประบบตัวเอง | เหมือน T6 แต่ `subsystem=csmju-equipment` | `Location: http://localhost:3002/auth/callback?...` |
| T8 | **บทบาทที่ไม่ได้รับอนุญาต** | เหมือน T7 แต่ใช้ `$ALUMNI` แล้วดู `%{http_code}` | **`403`** — Core Hub ปฏิเสธก่อนส่งต่อ |
| T9 | alumni ยังเข้า demo ได้ | เหมือน T6 แต่ใช้ `$ALUMNI` | `302` — เพราะ demo อนุญาต alumni |

T8 กับ T9 รวมกันคือหลักฐานว่า**สิทธิ์ถูกตัดสินที่ Core Hub ตามทะเบียน** — ผู้ใช้คนเดียวกัน เข้าระบบหนึ่งได้ อีกระบบไม่ได้

### ทดสอบผ่านหน้าเว็บ

1. เปิด http://127.0.0.1:3100 → login `admin@core.local`
2. แถบซ้ายหัวข้อ **"ระบบย่อย"** ต้องมี **CSMJU Student Service** และ **ระบบครุภัณฑ์**
3. กด **ระบบครุภัณฑ์** → เด้งไป `localhost:3002/auth/callback` และได้ `"subsystemRole":"ADMIN"`
4. ออกจากระบบ → login ใหม่เป็น `alumni@core.local`
5. แถบซ้ายต้อง**เหลือแค่ CSMJU Student Service** — ระบบครุภัณฑ์หายไปเพราะไม่ได้อนุญาต alumni

### ตรวจตามมาตรฐาน (ในโฟลเดอร์ระบบตัวเอง)

```bash
cd csmju2030/csmju-equipment && ./standards/scripts/run-all-checks.sh .
```

```bash
node standards/conformance/run.js --level L1
```

```bash
node standards/conformance/run.js
```

ผลสุดท้ายที่ต้องได้:

```text
RESULT: 62 passed · 0 failed · 0 skipped
✅ CONFORMANT — csmju-equipment meets standard v1.0 L3
```

**`SKIP` ไม่นับว่าผ่าน** — แปลว่า `probes` ใน `subsystem.yaml` ประกาศไม่ครบ

---

## 8. ปิดระบบ

กด `Ctrl-C` ในแต่ละ terminal ถ้าพอร์ตยังค้าง:

```bash
lsof -nP -iTCP:3000 -iTCP:3001 -iTCP:3002 -iTCP:3100 -sTCP:LISTEN
```

```bash
kill $(lsof -tiTCP:3002 -sTCP:LISTEN)
```

---

## 9. แก้ปัญหาที่เจอบ่อย

| อาการ | สาเหตุ | แก้ |
|---|---|---|
| `ENOENT: keys/jwt-private.pem` | ยังไม่สร้างกุญแจ | ทำข้อ 4.1 |
| `EADDRINUSE :3001` | Core Hub frontend รุ่นเก่ายังจองพอร์ต 3001 | frontend ต้องอยู่ 3100 · ปิดตัวที่ค้างด้วยคำสั่งในข้อ 8 |
| demo ต่อฐานข้อมูลไม่ได้ | `.env.example` ของ demo ชี้พอร์ต 5433 | เปลี่ยนเป็น 5432 ถ้าใช้ PostgreSQL ในเครื่อง |
| `pnpm install` ล้มที่ `prisma generate` | ใช้ repo รุ่นเก่า / ไฟล์ `prisma.config.ts` ที่ยังใช้ `env('DATABASE_URL')` | `git pull` ให้ได้ `main` ล่าสุด |
| `ERR_PNPM_IGNORED_BUILDS` | `pnpm-workspace.yaml` ไม่มี `allowBuilds` | คัดลอกส่วนนั้นจาก demo (ข้อ 6.2) |
| ระบบย่อยตอบ 401 ทุกคำขอ | JWKS ถูกห่อ envelope หรือสร้างกุญแจใหม่ทับ | ตรวจ T1 · login ใหม่ · รีสตาร์ตระบบย่อยเพื่อล้าง cache กุญแจ |
| `callbackUrl must use HTTPS` | Core Hub ตั้ง `NODE_ENV=production` | เปลี่ยนเป็น `development` |
| SSO ได้ 403 ทั้งที่ลงทะเบียนแล้ว | role ของผู้ใช้ไม่อยู่ใน `defaultRoleMapping` หรือยังไม่ approve/activate | ตรวจทะเบียนด้วย `GET /api/v1/subsystems/all` |
| ระบบย่อยไม่ขึ้นในเมนู Core Hub | เหมือนข้อบน — เมนูกรองด้วยกฎเดียวกับ SSO | เหมือนข้อบน |
| `standards/` ว่าง | clone โดยไม่ใส่ `--recurse-submodules` | `git submodule update --init --recursive` |
| conformance ขึ้น SKIP | `probes` ไม่ครบ | ประกาศให้ครบใน `subsystem.yaml` |
| `pnpm test` ที่รากผ่านแต่ไม่มีเทสต์รันเลย | `name` ของ `package.json` ที่รากซ้ำกับ `backend` | ตั้งชื่อไม่ให้ซ้ำ (กฎ `QA-06`) |

---

## 10. เช็คลิสต์ผ่าน

- [ ] โฟลเดอร์จัดตามข้อ 2 · `demo-student-subsystem/standards/` ไม่ว่าง
- [ ] 3 ฐานข้อมูลแยกกัน
- [ ] 4 พอร์ตเปิดครบ: 3000 · 3100 · 3001 · 3002
- [ ] T1–T9 ผ่านทั้งหมด
- [ ] หน้าเว็บ: admin เห็น 2 ระบบ · alumni เห็น 1 ระบบ
- [ ] `run-all-checks.sh` ผ่านทุกข้อในระบบตัวเอง
- [ ] conformance L3 ได้ `0 failed · 0 skipped`

---

**อ่านต่อ:** `csmju2030-standards/docs/aie-workflow.md` (ลำดับงานทั้งหมดจนส่งมอบ) ·
`auth-contract.md` (สัญญา JWT/SSO) · `subsystem-registry.md` (ทะเบียนฉบับละเอียด) · `conformance.md` (เกณฑ์ผ่าน)

---

## ภาคผนวก — ทำไมต้องใช้ pnpm และ npx ใช้ได้มั้ย

ทุกคำสั่งในเอกสารนี้ใช้ `pnpm` ไม่ใช่ `npm` — กฎ `QA-05` ของ CI บังคับกับทุก repo ในโครงการ
รวมถึงระบบย่อยของทุกทีม

### npm ไม่ได้แย่ — แต่ห้ามใช้ปนกัน

แต่ละตัวมีไฟล์ล็อกเวอร์ชัน (lockfile) ของตัวเอง:

| ตัว | lockfile |
|---|---|
| npm | `package-lock.json` |
| pnpm | `pnpm-lock.yaml` |

CI ติดตั้งด้วย `pnpm install --frozen-lockfile` คือ**ติดตั้งตาม `pnpm-lock.yaml` เป๊ะ ห้ามเปลี่ยน**
ถ้าใครใช้ `npm install` เพิ่ม package ไฟล์ที่เปลี่ยนคือ `package-lock.json` แต่ `pnpm-lock.yaml` ไม่เปลี่ยน
ผลคือเครื่องเขากับ CI ได้คนละเวอร์ชัน — ต้นเหตุของอาการ "เครื่องผมรันได้นะ"

ถ้าเผลอพิมพ์ `npm install` ในโปรเจกต์นี้ มันจะไม่อ่าน `pnpm-workspace.yaml` จึง**ไม่ติดตั้ง dependency ของ
`backend/` และ `frontend/` เลย** และได้ `package-lock.json` งอกออกมาให้ CI ตีตก

### ทำไมเลือก pnpm — 4 เหตุผลที่เจอจริงในโครงการนี้

**1. จับ dependency ที่ไม่ได้ประกาศไว้**

npm วาง package ทุกตัวแบนราบใน `node_modules` โค้ดจึง import สิ่งที่ไม่ได้เขียนไว้ใน `package.json` ได้โดยไม่รู้ตัว
pnpm อนุญาตเฉพาะที่ประกาศไว้จริง

> **เคสจริง:** Core Hub เคยมี `import type { SignOptions } from 'jsonwebtoken'` ทั้งที่ `jsonwebtoken` ไม่อยู่ใน
> `package.json` — npm ปล่อยผ่านเพราะ `@nestjs/jwt` ลากมาให้ พอย้ายมา pnpm typecheck พังทันที
> ถ้าไม่ย้าย วันที่ `@nestjs/jwt` เลิกใช้ `jsonwebtoken` ระบบจะพังโดยไม่มีใครรู้สาเหตุ

**2. ประหยัดดิสก์**

pnpm เก็บ package แต่ละเวอร์ชันไว้**ชุดเดียว**ใน store กลาง แล้วลิงก์เข้าแต่ละโปรเจกต์ ส่วน npm คัดลอกเต็มทุกโปรเจกต์
เอกสารนี้มี 3–4 repo ที่ใช้ dependency แทบชุดเดียวกัน ถ้าเป็น npm จะกินพื้นที่เป็นหลายเท่า

**3. บล็อกสคริปต์อันตรายตอนติดตั้ง**

pnpm 10+ ไม่ให้ dependency รันสคริปต์ตอนติดตั้ง (`postinstall`) ยกเว้นตัวที่อนุญาตไว้ใน `allowBuilds`
ของ `pnpm-workspace.yaml` เช่น `prisma` และ `bcrypt` — กันกรณี package ในสายการพึ่งพาถูกแฮ็กแล้วฝังโค้ดไว้
npm รันให้ทั้งหมดโดยไม่ถาม

error `ERR_PNPM_IGNORED_BUILDS` ในข้อ 9 คือกลไกนี้ทำงานอยู่ ไม่ใช่บั๊ก

**4. monorepo และเวอร์ชันตรงกันทุกเครื่อง**

แต่ละ repo มี `backend/` และ `frontend/` อยู่ด้วยกัน สคริปต์ทั้งมาตรฐานสร้างบน `pnpm --filter`
และ `package.json` ล็อก `"packageManager": "pnpm@12.3.4"` ไว้ — สั่ง `corepack enable pnpm` แล้วทุกคน
รวมถึง CI ได้ pnpm เวอร์ชันเดียวกัน

### แล้ว npx ล่ะ

**npx ไม่ได้ติดตั้ง dependency ของโปรเจกต์** — มันแค่**รันคำสั่ง** CLI ของ package เช่น `npx prisma generate`
จึงไม่ผิดกฎ `QA-05` (ไม่สร้าง lockfile) และในโปรเจกต์ pnpm ก็รันได้ เพราะมันหาคำสั่งใน `node_modules/.bin` ก่อน

**จุดอันตรายมีข้อเดียว:** ถ้าหาในเครื่องไม่เจอ npx จะ**ดาวน์โหลดเวอร์ชันล่าสุดมารันเงียบ ๆ**
เช่นได้ Prisma 7.10 ทั้งที่มาตรฐานล็อกไว้ 7.9.1 — แล้ว migration อาจทำงานต่างจากที่ทดสอบไว้

### ตารางคำสั่งสำหรับ dev

คอลัมน์ **npm / npx มีไว้เทียบให้คนที่คุ้นกับ npm เท่านั้น — ในโครงการนี้ใช้คอลัมน์ pnpm**
ช่องที่เป็น `—` คือคำสั่งที่ไม่เกี่ยวกับ package manager ใช้เหมือนกันทุกคน

**ชื่อที่ใช้กับ `--filter` ไม่เหมือนกันทุก repo** — ดูให้ถูกก่อนพิมพ์:

| repo | backend | frontend |
|---|---|---|
| `csmju-core-hub` | `core-api` | `frontend` |
| `demo-student-subsystem` | `backend` | — |
| `csmju-<ระบบของทีม>` | `backend` | `frontend` |

ตารางข้างล่างใช้ `backend` เป็นตัวอย่าง ถ้าทำใน Core Hub ให้เปลี่ยนเป็น `core-api`

#### เตรียมเครื่อง

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| เปิดใช้ pnpm | — | `corepack enable pnpm` | corepack มากับ Node 22 · ได้เวอร์ชันตาม `packageManager` ของ repo อัตโนมัติ |
| ดูเวอร์ชัน | `npm -v` | `pnpm -v` | ต้องได้ 12.x |
| ดูว่า store ของ pnpm อยู่ไหน | — | `pnpm store path` | |

#### ติดตั้งและจัดการ dependency

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| ติดตั้งทั้งโปรเจกต์ | `npm install` | `pnpm install` | รันที่รากของ repo · `prisma generate` รันตามให้เอง |
| ติดตั้งแบบเดียวกับ CI | `npm ci` | `pnpm install --frozen-lockfile` | ห้ามแก้ lockfile — ใช้ตรวจก่อนเปิด PR |
| เพิ่ม package | `npm install zod -w backend` | `pnpm --filter backend add zod` | ต้องอยู่ใน whitelist ไม่งั้นโดน `ARC-02` |
| เพิ่ม dev dependency | `npm install -D x -w backend` | `pnpm --filter backend add -D x` | |
| เพิ่มเครื่องมือที่ใช้ทั้ง repo | `npm install -D x` | `pnpm add -Dw x` | `-w` = ติดตั้งที่รากของ workspace |
| ลบ package | `npm uninstall x -w backend` | `pnpm --filter backend remove x` | |
| อัปเดต package ตัวเดียว | `npm update x` | `pnpm --filter backend update x` | **ห้ามอัปเดต Prisma** — ล็อก 7.9.1 เป๊ะทั้งสามตัว |
| ดูว่าอะไรตกรุ่น | `npm outdated` | `pnpm outdated -r` | |
| ดูว่าติดตั้งอะไรไว้ | `npm ls` | `pnpm list -r --depth 0` | |
| ดูว่าใครลาก package นี้มา | `npm explain x` | `pnpm why x` | ใช้ไล่ dependency ที่ไม่ได้ประกาศไว้ |
| อนุญาตให้ package รันสคริปต์ตอนติดตั้ง | — | `pnpm approve-builds` | เขียนลง `allowBuilds` ใน `pnpm-workspace.yaml` · ใช้เมื่อเจอ `ERR_PNPM_IGNORED_BUILDS` |
| ติดตั้งใหม่ทั้งหมด | `rm -rf node_modules && npm install` | `rm -rf node_modules */node_modules && pnpm install` | ใช้เมื่อ node_modules เพี้ยน |
| คืนพื้นที่ดิสก์ | — | `pnpm store prune` | ลบ package ใน store ที่ไม่มีโปรเจกต์ไหนใช้แล้ว |

#### รันระบบ

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| Core Hub backend | `npm run start:dev -w core-api` | `pnpm --filter core-api start:dev` | :3000 |
| Core Hub frontend | `npm run dev -w frontend` | `pnpm --filter frontend dev` | :3100 |
| Core Hub ทั้งสองฝั่งพร้อมกัน | — | `pnpm dev` | รันที่รากของ Core Hub · log ปนกันใน terminal เดียว |
| demo backend | `npm run start:dev -w backend` | `pnpm --filter backend start:dev` | :3001 |
| ระบบของทีม | `npm run start:dev -w backend` | `pnpm --filter backend start:dev` | :3002 |
| build ทุก workspace | `npm run build --workspaces` | `pnpm -r build` | |
| รันสคริปต์ที่รากของ repo | `npm run checks` | `pnpm checks` | สคริปต์ที่ประกาศใน `package.json` ที่ราก |

#### ตรวจคุณภาพโค้ด

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| lint | `npm run lint --workspaces` | `pnpm -r lint` | `QA-01` |
| แก้ lint อัตโนมัติ | — | `pnpm --filter core-api lint:fix` | มีเฉพาะ Core Hub · CI ไม่แก้ให้ |
| ตรวจ type | `npm run typecheck --workspaces` | `pnpm -r typecheck` | `QA-02` · frontend ต้องเป็น `next typegen && tsc --noEmit` |
| unit test | `npm test --workspaces` | `pnpm -r test` | `QA-03` |
| unit test แบบเฝ้าไฟล์ | `npm run test:watch -w backend` | `pnpm --filter backend test:watch` | รันใหม่ทุกครั้งที่บันทึกไฟล์ |
| ดู coverage | `npm run test:cov -w backend` | `pnpm --filter backend test:cov` | |
| e2e test | `npm run test:e2e -w backend` | `pnpm --filter backend test:e2e` | ต้องมีฐานข้อมูล |
| integration test ของ demo | `npm run test:integration -w backend` | `pnpm --filter backend test:integration` | ต้องเปิด Core Hub ไว้ ไม่งั้นเคสจะถูกข้าม |
| **ตรวจแบบเดียวกับ CI** | — | `rm -rf frontend/.next && pnpm -r lint && pnpm -r typecheck && pnpm -r test && pnpm -r build` | ลบของค้างก่อน ไม่งั้นผ่านหลอก |

#### Prisma และฐานข้อมูล

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| สร้างฐานข้อมูล | — | `createdb equipment_db` | ของ PostgreSQL · หนึ่งระบบหนึ่งฐานข้อมูล |
| ดูรายชื่อฐานข้อมูล | — | `psql -lqt` | |
| เข้า psql | — | `psql -d equipment_db` | |
| สร้าง Prisma client | `npx prisma generate` | `pnpm --filter backend exec prisma generate` | ปกติไม่ต้องสั่ง — `pnpm install` ทำให้แล้ว |
| สร้างตารางตาม migration ที่มี | `npx prisma migrate deploy` | `pnpm --filter backend exec prisma migrate deploy` | ใช้ตอนตั้งเครื่องใหม่ · ไม่สร้าง migration ใหม่ |
| สร้าง migration ใหม่หลังแก้ schema | `npx prisma migrate dev --name add_x` | `pnpm --filter backend exec prisma migrate dev --name add_x` | ใช้ตอน dev เท่านั้น · **เปลี่ยนชื่อคอลัมน์ต้องเขียน `RENAME COLUMN` เอง** ไม่งั้นข้อมูลหาย |
| ดูสถานะ migration | `npx prisma migrate status` | `pnpm --filter backend exec prisma migrate status` | |
| ล้างฐานข้อมูลทั้งหมด | `npx prisma migrate reset` | `pnpm --filter backend exec prisma migrate reset` | ⚠️ **ข้อมูลหายหมด** ใช้กับเครื่อง dev เท่านั้น |
| เปิดหน้าจัดการข้อมูล | `npx prisma studio` | `pnpm --filter backend exec prisma studio` | :5555 · **ห้ามเปิดออกอินเทอร์เน็ต** |
| seed ของ Core Hub | — | `pnpm --filter core-api build && (cd backend && node dist/prisma/seed.js)` | ต้อง build ก่อน · ห้ามใช้ `ts-node` |
| seed ของ demo | `npm run prisma:seed` | `pnpm prisma:seed` | ข้อมูลตัวอย่าง — ไม่จำเป็นต่อการทดสอบเชื่อมต่อ |

#### เครื่องมือที่ใช้ครั้งเดียว

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| สร้าง type ของ route (Next.js) | `npx next typegen` | `pnpm --filter frontend exec next typegen` | typecheck เรียกให้อยู่แล้ว |
| สร้างแอป Next.js ใหม่ | `npx create-next-app@latest frontend` | `pnpm dlx create-next-app@latest frontend` | ใช้ตอนเริ่ม frontend ของทีม · ต้องเป็น 15.5+ |
| สร้าง backend ใหม่ด้วย Nest CLI | `npx @nestjs/cli new backend` | `pnpm dlx @nestjs/cli new backend` | **ไม่แนะนำ** — ตั้งต้นจาก demo แทน (ข้อ 6.2) เพราะชั้น auth ต้องคัดลอกอยู่แล้ว |

#### มาตรฐานและ conformance

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| สร้าง repo ระบบย่อยใหม่ | — | `./csmju2030-standards/new-subsystem.sh <slug> "<ชื่อ>"` | รันจากโฟลเดอร์ `csmju2030/` |
| ตรวจตามกฎทั้งหมด (ระบบย่อย) | — | `./standards/scripts/run-all-checks.sh .` | ตัวเดียวกับที่ CI ใช้ |
| ตรวจตามกฎของ Core Hub | — | `pnpm checks` | รันที่รากของ Core Hub · ต้องมี `csmju2030-standards` อยู่ข้าง ๆ |
| conformance ระดับเดียว | — | `node standards/conformance/run.js --level L1` | ไล่ทีละระดับ L1 → L2 → L3 |
| conformance ตามที่ประกาศไว้ | — | `node standards/conformance/run.js` | อ่านระดับจาก `subsystem.yaml` |
| conformance ออกเป็นไฟล์ | — | `node standards/conformance/run.js --json` | ได้ `conformance-report.json` แนบ PR |
| ดึง submodule `standards/` | — | `git submodule update --init --recursive` | ใช้เมื่อโฟลเดอร์ `standards/` ว่าง |
| ดูว่าผูกมาตรฐานเวอร์ชันไหน | — | `git submodule status` | ต้องตรงกับ `.standards-version` |

#### git ตามมาตรฐาน

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| แตก branch ใหม่ | — | `git checkout -b feature/<slug>/<เรื่อง>` | `GH-01` · ตัวพิมพ์เล็กและขีดกลางเท่านั้น |
| commit | — | `git commit -m "feat(<slug>): <คำอธิบาย>"` | `GH-02` · type ได้แค่ `feat` `fix` `chore` `refactor` `docs` `test` `ci` |
| ดึงของใหม่จาก main | — | `git fetch origin && git merge origin/main` | ทำก่อนเปิด PR ทุกครั้ง |
| push branch | — | `git push -u origin feature/<slug>/<เรื่อง>` | แล้วเปิด PR บน GitHub |

#### พอร์ตและ process

| อยากทำอะไร | npm / npx | pnpm | หมายเหตุ |
|---|---|---|---|
| ดูว่าพอร์ตไหนเปิดอยู่ | — | `lsof -nP -iTCP -sTCP:LISTEN` | macOS / Linux |
| ดูว่าใครใช้พอร์ตนี้ | — | `lsof -nP -iTCP:3002 -sTCP:LISTEN` | |
| ปิด process ที่ค้างพอร์ต | — | `kill $(lsof -tiTCP:3002 -sTCP:LISTEN)` | ดูก่อนว่าใช่ตัวที่ตั้งใจจะปิด |
| ดูพอร์ตบน Windows | — | `netstat -ano \| findstr :3002` | |

**หลักจำ:** เครื่องมือในโปรเจกต์ → `pnpm exec` (ไม่มีก็ error ไม่แอบดาวน์โหลด) ·
เครื่องมือใช้ครั้งเดียว → `pnpm dlx` · `npx` ใช้ได้แต่ต้องรู้ว่าอาจดึงเวอร์ชันอื่นมา

> ถ้าเห็น `npx prisma migrate deploy` ใน `backend/docker/entrypoint.sh` ของบาง repo ไม่ต้องตกใจ —
> ใน Docker image ติดตั้ง prisma เวอร์ชันที่ล็อกไว้แล้ว npx จึงใช้ตัวในเครื่องเสมอ
> แต่ในเครื่องตัวเองให้ใช้ `pnpm exec` ตามตารางข้างบน
