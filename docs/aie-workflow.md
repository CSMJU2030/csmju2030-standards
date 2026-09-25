# AIE Workflow — ทำระบบย่อยตั้งแต่ศูนย์จนส่งมอบ

**เวอร์ชัน 1.0**

> เอกสารนี้คือ**ลำดับขั้นตอน** ไม่ใช่เนื้อกฎ — แต่ละขั้นจะชี้ไปยังเอกสารที่มีรายละเอียดจริง
> อ่านครั้งเดียวจบก่อนเริ่มงาน แล้วเปิดค้างไว้ใช้เป็น checklist ระหว่างทำ

```text
0 เตรียมเครื่อง → 1 อ่านสัญญา → 2 สร้าง repo → 3 ลงทะเบียนกับ Core Hub
→ 4 คัดลอกชั้น auth → 5 ฐานข้อมูล → 6 API → 7 frontend
→ 8 ตรวจเอง 2 ชั้น → 9 เปิด PR → 10 ส่งมอบ
```

| ขั้น | ใครทำ | เสร็จเมื่อ |
|---|---|---|
| 0–1 | AIE | รัน Core Hub ที่ได้รับมาได้ และรู้ว่าอะไรห้ามแก้ |
| 2–3 | AIE + PM/admin | repo ขึ้น GitHub และมีทะเบียนใน Core Hub |
| 4–7 | AIE | ระบบทำงานจริงบนเครื่องตัวเอง |
| 8 | AIE | `run-all-checks` และ `conformance` เขียวทั้งคู่ |
| 9–10 | AIE + PL | PR ผ่าน CI และ PL รับงาน |

---

## ขั้น 0 — เตรียมเครื่อง

| ต้องมี | ตรวจด้วย |
|---|---|
| Node.js **22.x** | `node -v` |
| **pnpm** (ห้าม npm/yarn — กฎ `QA-05`) | `pnpm -v` · ติดตั้งด้วย `corepack enable pnpm` |
| PostgreSQL **16+** (หรือ Docker) | `psql --version` |
| Docker + docker compose | `docker compose version` |
| `gh` CLI (ใช้ตอนสร้าง repo) | `gh auth status` |

สิ่งที่ต้องขอจากทีมกลางก่อนเริ่ม:

| ขอจากใคร | ได้อะไร |
|---|---|
| ผู้ดูแล Dev Server | **`CORE_HUB_URL`** ที่ใช้งานได้จริง |
| PM / org admin | สิทธิ์สร้าง repo ในองค์กร + บัญชี admin ของ Core Hub (สำหรับลงทะเบียน) |
| PL | **ระดับ conformance เป้าหมาย** (L1 / L2 / L3) และขอบเขตงานของระบบย่อย |

ทดสอบว่าต่อ Core Hub ได้จริงก่อนเขียนโค้ดบรรทัดแรก:

```bash
curl -s $CORE_HUB_URL/api/v1/health
```

```bash
curl -s $CORE_HUB_URL/api/v1/.well-known/jwks.json
```

อันหลังต้องขึ้นต้นด้วย `{"keys":[` ตรง ๆ ถ้าเห็น `{"success":true,...}` แปลว่า Core Hub ตั้งค่าผิด — แจ้งผู้ดูแลก่อน อย่าเขียนโค้ดรับเคสนั้น

---

## ขั้น 1 — อ่านสัญญาก่อนเขียนโค้ด

อ่าน 3 ฉบับนี้ให้จบก่อน (ประมาณ 1 ชั่วโมง) ที่เหลือเปิดดูตอนต้องใช้:

| อ่านเพื่อ | ไฟล์ |
|---|---|
| ภาพรวมสถาปัตยกรรมและสถานะจริง | [`overview.md`](overview.md) |
| JWT · JWKS · SSO · callback | [`auth-contract.md`](auth-contract.md) |
| role mapping · permission · 401 vs 403 | [`authorization.md`](authorization.md) |

**สิ่งที่เปลี่ยนไม่ได้เด็ดขาด** — ระบบย่อยต้องยอมรับตามนี้:

| | ค่า |
|---|---|
| algorithm | `RS256` |
| `iss` | `core-hub` |
| `aud` | `csmju2030` |
| `kid` | `core-hub-2026` |
| อายุ access token | 15 นาที |
| core role | `student` · `alumni` · `staff` · `admin` เท่านั้น |

**สามข้อที่ทำให้ตกทันทีโดยไม่ต้องดูอย่างอื่น**

1. มีหน้า login / endpoint `login`, `register`, `refresh` ของตัวเอง (`SEC-05`)
2. ออกหรือเซ็น JWT เอง หรือใช้ `jsonwebtoken` / `passport-jwt` แทน `jose` (`SEC-04`)
3. มีตาราง `users` ของตัวเอง — เก็บได้แค่ `core_user_id` เป็น external reference (`DD-01`)

---

## ขั้น 2 — สร้าง repo ด้วยสคริปต์ (ห้ามสร้างเอง)

```bash
git clone https://github.com/CSMJU2030/csmju2030-standards.git
```

```bash
cd csmju2030-standards && ./new-subsystem.sh <slug> "<ชื่อภาษาไทย>"
```

`<slug>` เป็นตัวพิมพ์เล็ก/ตัวเลข/ขีดกลาง เช่น `equipment` → ได้ repo ชื่อ `csmju-equipment`

สคริปต์จะทำให้ครบ: สร้างไฟล์มาตรฐาน → **รัน compliance กับสิ่งที่เพิ่งสร้าง (15 ข้อ)** →
`git init -b main` + commit → `gh repo create` → เพิ่ม `standards/` เป็น submodule ที่ pin เวอร์ชันไว้ → push

สิ่งที่ได้:

```text
csmju-<slug>/
├── .github/workflows/ci.yml       เรียก reusable workflow ของ standards (ห้ามแก้)
├── .github/CODEOWNERS
├── .standards-version             เวอร์ชันมาตรฐานที่ผูกอยู่
├── standards/                     submodule (อ่านอย่างเดียว ห้ามแก้)
├── subsystem.yaml                 manifest เดียวที่ CI + conformance อ่าน
├── pnpm-workspace.yaml
├── .env.example
├── backend/src/
└── frontend/src/
```

จากนั้นแก้ `subsystem.yaml` ให้ตรงงานจริง — โดยเฉพาะ **`probes`** ซึ่ง conformance ใช้ยิงทดสอบ
(ประกาศไม่ครบ = ขึ้น `SKIP` = **ยังไม่ผ่าน**) ดู [`conformance.md`](conformance.md) ข้อ 3

> ขั้นที่ต้องให้ org admin ทำต่อ: สร้าง Team `pl-<slug>` / `aie-<slug>` และตั้ง ruleset ให้ repo

---

## ขั้น 3 — ลงทะเบียนกับ Core Hub

ระบบย่อยจะเข้าผ่าน SSO ได้ต่อเมื่อมีทะเบียนแล้ว **และ**ผ่านทั้ง approve และ activate

```bash
curl -X POST $CORE_HUB_URL/api/v1/subsystems \
  -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' \
  -d '{"name":"csmju-equipment","displayName":"ระบบครุภัณฑ์","owner":"admin","repo":"CSMJU2030/csmju-equipment","standardsVersion":"1.0.0","callbackUrl":"http://localhost:3002/auth/callback","defaultRoleMapping":{"student":"USER","staff":"STAFF","admin":"ADMIN"},"requestedExceptions":[]}'
```

แล้ว approve + activate ด้วย `POST /api/v1/subsystems/<id>/approve` และ `/activate`

**สามเรื่องที่พลาดกันบ่อย**

| | |
|---|---|
| `requestedExceptions` | เป็นฟิลด์**บังคับ** ไม่มีคำขอก็ต้องส่ง `[]` ไม่งั้นได้ 400 |
| `callbackUrl` | ต้องเป็น `https://` ยกเว้น `localhost` / `127.0.0.1` ตอน dev |
| `defaultRoleMapping` | **key = core role ที่อนุญาตให้เข้าระบบนี้** ใครไม่อยู่ใน key นี้ Core Hub ตอบ 403 ตั้งแต่ก่อน redirect |

`name` ในทะเบียนต้องตรงกับ `name` ใน `subsystem.yaml` และตรงกับ `data.service` ที่ `/api/health` ตอบ

รายละเอียด: [`subsystem-registry.md`](subsystem-registry.md)

---

## ขั้น 4 — คัดลอกชั้น auth (ห้ามเขียนเอง)

คัดลอกจาก reference implementation `demo-student-subsystem/backend/src/auth/` **โดยไม่แก้ตรรกะ**:

```text
jwks.service.ts              ดึง JWKS + cache ตาม kid
core-hub-token.verifier.ts   ตรวจ 8 ขั้นตามสัญญา
guards/                      CoreHubJwtGuard (401) · PermissionsGuard (403)
decorators/                  @Public · @RequirePermissions · @CurrentUser
sso-callback.controller.ts   GET /auth/callback (อยู่นอก /api prefix)
me.controller.ts             GET /api/v1/me
role-mapping.ts              ⬅ แก้ได้เฉพาะค่าในตาราง
permissions.ts               ⬅ permission ของโดเมนตัวเอง
```

ที่แก้ได้มีแค่สองไฟล์ท้าย:

- `role-mapping.ts` — ต้องตรงกับ `default_role_mapping` ในทะเบียน **เป๊ะ**
- `permissions.ts` — ใช้รูปแบบ `<resource>:<action>[:own|:any]` เช่น `equipment:read:own`

กฎ 401 vs 403 ที่ conformance จับแน่นอน:

| สถานการณ์ | ต้องตอบ |
|---|---|
| ไม่มี token / token ปลอม / หมดอายุ / `kid` ไม่ตรง | **401** |
| token ถูกต้องแต่สิทธิ์ไม่พอ | **403** (ห้ามตอบ 404 เพื่อ "ความปลอดภัย") |
| เจ้าของข้อมูลไม่ใช่ตัวเอง แต่มีสิทธิ์แค่ `:own` | **403** |

---

## ขั้น 5 — ฐานข้อมูลของตัวเอง

**ห้ามต่อฐานข้อมูลของ Core Hub หรือของระบบอื่นเด็ดขาด** (กฎ `ARC-01` — Database per Subsystem)

| กฎ | รายละเอียด |
|---|---|
| ตาราง/คอลัมน์ | `snake_case` ผ่าน `@@map` / `@map` · field ใน Prisma เป็น camelCase |
| อ้างถึงผู้ใช้ | คอลัมน์ `core_user_id` (field `coreUserId`) เท่านั้น — ห้าม `user_id`, `std_id` ฯลฯ |
| เงิน | integer (สตางค์) ห้าม float |
| คณะ/หลักสูตร | ห้าม hardcode — เรียกจาก Core Hub |
| migration | ห้ามลบ ห้าม squash · เปลี่ยนชื่อคอลัมน์ต้องใช้ `RENAME COLUMN` ไม่ใช่ drop+add |

Prisma ต้อง **pin 7.9.1 เป๊ะทั้งสามตัว** (`prisma`, `@prisma/client`, `@prisma/adapter-pg`)
และใช้แบบ driver adapter (`PrismaPg`) ตาม reference implementation

รายละเอียด: [`data-dictionary.md`](data-dictionary.md)

---

## ขั้น 6 — เขียน API ตามสัญญา

| หัวข้อ | กฎ |
|---|---|
| path | `/api/v1/<resources>` · พหูพจน์ · kebab-case |
| health | `GET /api/health` (อยู่นอก `/v1`) ตอบ `{status, service}` |
| callback | `GET /auth/callback` (อยู่นอก `/api`) |
| response | ห่อ envelope `{ success, data, meta? }` ทุก endpoint |
| error | `{ success:false, error:{ code, message } }` · `code` มาจาก **7 ค่าปิด** เท่านั้น |
| pagination | `?page=1&limit=20` (ห้าม `per_page`) |
| สร้างสำเร็จ | `201` · ลบสำเร็จ `200` + `{id, deleted:true}` |
| validation ผิด | **400** `VALIDATION_ERROR` (ไม่ใช่ 422) |

รายละเอียด: [`api-conventions.md`](api-conventions.md) · รายการ error code: `contracts/error-codes.json`

---

## ขั้น 7 — frontend (ถ้ามี UI)

- **Next.js App Router 15.5+** · TypeScript · Tailwind
- **ห้ามมีหน้า login ของตัวเอง** — ผู้ใช้เข้ามาผ่าน Core Hub SSO เท่านั้น
- token เก็บใน **httpOnly cookie** เท่านั้น · ห้าม `localStorage` (`SEC-03`)
- frontend **ห้าม import Prisma / `pg` / แตะ `DATABASE_URL`** (`ARC-01`)
- ใช้ class จาก design token ใน `@theme` (เช่น `bg-primary-container`) ห้ามใส่ hex ดิบ (`UI-01`)
  — หน้าตา สี ฟอนต์ component ทั้งหมดอยู่ใน [`ui-design-system.md`](ui-design-system.md)

script `typecheck` ของ frontend ต้องเป็นแบบนี้ ไม่งั้นผ่านในเครื่องแต่**ตกบน CI**:

```json
"typecheck": "next typegen && tsc --noEmit"
```

(Next.js สร้าง type ของ route/layout ตอน dev/build เท่านั้น CI ที่ checkout ใหม่จะไม่มี
ดู [`tech-stack.md`](tech-stack.md) ข้อ 1.2.1)

---

## ขั้น 8 — ตรวจเอง 2 ชั้นก่อนเปิด PR

CI ตรวจว่า "เขียนถูกกฎ" · conformance ตรวจว่า "ทำงานได้จริงตามสัญญา" — **ต้องผ่านทั้งคู่**

**ชั้นที่ 1 — static (เหมือน CI ทุกข้อ)**

```bash
./standards/scripts/run-all-checks.sh .
```

**ชั้นที่ 2 — runtime (ต้องรัน Core Hub และระบบตัวเองไว้ก่อน)**

```bash
node standards/conformance/run.js
```

ต้องได้ `0 failed` และ **`SKIP` ไม่นับว่าผ่าน**

```text
RESULT: 62 passed · 0 failed · 0 skipped
✅ CONFORMANT — csmju-equipment meets standard v1.0 L3
```

**ตรวจแบบเดียวกับ CI จริง ๆ (สำคัญ)** — CI checkout ใหม่ ไม่มีของค้างในเครื่อง:

```bash
rm -rf frontend/.next && pnpm -r lint && pnpm -r typecheck && pnpm -r test && pnpm -r build
```

ถ้าอยากชัวร์กว่านั้น clone ใหม่ลงโฟลเดอร์ว่าง แล้ว `pnpm install --frozen-lockfile` ก่อนรันชุดข้างบน
— หลายเคสที่ "ผ่านในเครื่องแต่ตกบน CI" จับได้ตรงนี้

---

## ขั้น 9 — เปิด PR

```bash
git checkout -b feature/<slug>/<เรื่องที่ทำ>
```

```bash
git commit -m "feat(<slug>): <คำอธิบาย>"
```

| กฎ | รายละเอียด |
|---|---|
| ชื่อ branch (`GH-01`) | `feature/<slug>/<เรื่อง>` ตัวพิมพ์เล็กและขีดกลางเท่านั้น |
| commit (`GH-02`) | Conventional Commits · type ได้แค่ **`feat` `fix` `chore` `refactor` `docs` `test` `ci`** (ไม่มี `build`/`perf`/`style`) |
| ห้ามแก้ (`GH-03`) | `.github/workflows/` · `CODEOWNERS` · `standards/` |
| `.standards-version` (`GH-04`) | ต้องตรงกับ `VERSION` ของ standards ที่ผูกอยู่ |
| PR | เล็กและโฟกัสเรื่องเดียว · แนบ `REPORT.md` |

PR แรกของ repo เป็นข้อยกเว้นของ `GH-03` (ต้องเพิ่มไฟล์ CI เอง) ให้ DevOps เป็นคน merge

---

## ขั้น 10 — Definition of Done

- [ ] `run-all-checks.sh` ผ่านทุกข้อ
- [ ] `conformance` ได้ `0 failed` `0 skipped` ที่ระดับที่ตกลงกับ PL
- [ ] เข้าระบบผ่าน SSO ได้จริงตั้งแต่ Core Hub login → callback → `/api/v1/me`
- [ ] ทดสอบครบ 4 role: `student` `alumni` `staff` `admin` — role ที่ไม่ได้อยู่ใน mapping ต้องโดน 403
- [ ] ไม่มี `.env` / `*.pem` / `generated/` / `dist/` ใน git
- [ ] `README.md` มีคำสั่งติดตั้ง–รัน–ทดสอบ ที่ **ใช้ได้จริงทุกบรรทัด**
- [ ] `REPORT.md` แนบผลรันจริง (ไม่ใช่ "น่าจะผ่าน") ตาม [`../ai/AGENTS.md`](../ai/AGENTS.md) ข้อ 6
- [ ] PL review และรับงาน

---

## กับดักที่เจอจริงมาแล้ว

| อาการ | สาเหตุ | ทางแก้ |
|---|---|---|
| CI ตก `Cannot find name 'LayoutProps'` ทั้งที่ในเครื่องผ่าน | `.next/types` ค้างในเครื่อง แต่ CI ไม่มี | `"typecheck": "next typegen && tsc --noEmit"` |
| `pnpm install` ล้มบน CI ที่ `prisma generate` | `prisma.config.ts` ใช้ `env('DATABASE_URL')` แต่ postinstall รันก่อนมี `.env` | แนบ `datasource` เฉพาะตอนมี env จริง |
| `pnpm test` ที่รากขึ้นเขียวแต่ไม่ได้รันเทสต์เลย | `name` ใน `package.json` ที่รากซ้ำกับของ `backend/` → `--filter` ไม่ match แล้ว exit 0 | ตั้งชื่อ workspace ไม่ให้ซ้ำ (`QA-06`) |
| ระบบย่อยขึ้น 401 ทุกคำขอ | Core Hub ห่อ JWKS ด้วย envelope / cache กุญแจเก่าไว้ | JWKS ต้องเป็น `{"keys":[...]}` ดิบ · ล้าง cache แล้ว login ใหม่ |
| ลงทะเบียนแล้วแต่เข้า SSO ไม่ได้ (403) | core role ของผู้ใช้ไม่อยู่ใน key ของ `default_role_mapping` | เพิ่ม role ในทะเบียน หรือทดสอบด้วย role ที่อนุญาต |
| `callbackUrl must use HTTPS` | Core Hub ตั้ง `NODE_ENV=production` | Dev Server ต้องเป็น `development` จึงจะรับ `http://localhost` |
| conformance ขึ้น `SKIP` หลายเคส | `probes` ใน `subsystem.yaml` ประกาศไม่ครบ | ประกาศให้ครบ — SKIP ไม่นับว่าผ่าน |

---

## ใช้ AI ช่วยเขียน

ต้องให้ AI อ่าน [`../ai/AGENTS.md`](../ai/AGENTS.md) ก่อนเสมอ แล้วสั่งงานด้วย
[`../ai/TASK_TEMPLATE.md`](../ai/TASK_TEMPLATE.md) และตรวจงานด้วย [`../ai/CHECKLIST.md`](../ai/CHECKLIST.md)

**ผลงานจาก AI ต้องผ่านเกณฑ์เดียวกับที่คนเขียน** — ขั้น 8 ไม่มีข้อยกเว้นให้ และ
"AI เขียนมาแบบนี้" ไม่ใช่เหตุผลที่รับได้ตอน review
