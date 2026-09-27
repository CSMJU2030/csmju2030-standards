# Changelog

รูปแบบเวอร์ชัน: เอกสารมาตรฐานใช้ `MAJOR.MINOR` (เช่น `1.0`) · repo และ git tag ใช้ semver (`1.0.0`)
ค่า `standards_version` ใน `subsystem.yaml` ของทุกระบบย่อยต้องตรงกับ `VERSION` ของ repo นี้

---

## ยังไม่ออกเวอร์ชัน

- `scripts/lib/allowed-deps.json` — เพิ่ม `sharp` ใน `allowed_core_hub` สำหรับบริการเก็บรูปกลางของ Core Hub
  (ตรวจ ย่อ และแปลงรูปเป็น WebP) · เพิ่มเฉพาะ profile `core-hub` ระบบย่อยยังใช้ไม่ได้ ต้องเก็บรูปผ่าน Core Hub
- `docs/core-hub-rules.md` §6 (ใหม่) — `GET /api/v1/images/:id/file` ส่งไฟล์ดิบไม่ห่อ envelope และไม่ต้องมี JWT
  เพราะ `<img>` แนบ token ไม่ได้ พร้อมเงื่อนไขที่ต้องคงไว้ · หัวข้อเดิม §6–§8 เลื่อนเป็น §7–§9
- fixture `__fixtures__/PROFILE-CORE-HUB-SHARP` + assertion ใน `scripts/self-test.sh` ยืนยันว่า `sharp`
  ผ่านเฉพาะ profile `core-hub` และยังถูกตีตกใน profile `subsystem`

การ**เพิ่ม**ข้อยกเว้นเป็น minor ตาม §8 ของ `core-hub-rules.md` · **ระบบย่อยไม่ต้องทำอะไร** ·
Core Hub ต้องเลื่อน pin ใน `ci.yml` เป็นเวอร์ชันที่ออกรายการนี้

---

## 1.1.1 — 2026-09-27

- `scripts/check-api-conventions.sh` (`API-02`..`API-07`) และ `scripts/check-no-jwt-verify.sh` (`SEC-04`/`SEC-05`) —
  หาไฟล์ `.ts` ตัวแรกด้วย `find … -print -quit` แทน `find … | head -1`
  ภายใต้ `set -o pipefail` ถ้า `head` ปิดท่อก่อน `find` เขียนเสร็จ `find` จะโดน SIGPIPE (exit 141)
  แล้ว `set -e` ทำให้สคริปต์จบเงียบ ๆ โดยไม่พิมพ์ว่าตกเพราะอะไร · เจอจริงบน CI ของ Core Hub
  (PR `feature/core-hub/rate-limit` ตกที่ "API Contract" หลังรายชื่อไฟล์ใน `backend/src` ยาวเกิน buffer ของ Linux ราว 7 KB)
  ผลเป็นแบบสุ่ม ผ่านบ้างตกบ้าง และบน Mac แทบไม่เจอ ระบบย่อยทุกตัวจะเจอเมื่อโค้ดโตขึ้น
- `self-test.sh` เพิ่ม 2 กรณีที่สร้าง backend 1,800 ไฟล์ตอนรัน ให้รายชื่อยาวเกินความจุของท่อ — สคริปต์เดิมตก exit 141 ทุกครั้ง

**ใครต้องทำอะไร:** ไม่มีกฎเปลี่ยน · repo ที่ CI ตกที่ "API Contract" หรือ "Security & Stack Scan" โดยไม่มีข้อความ ❌
(log จบที่ `exit code 141`) ให้เลื่อน pin ใน `ci.yml` และ `.standards-version` เป็น 1.1.1 · ระหว่างรอ กด Re-run failed jobs ได้

---

## 1.1.0 — 2026-09-27

Central SSO ที่ใช้ได้จริงจากเบราว์เซอร์ · Silent re-SSO · error code 9 ค่า — ตาม `SSO_FIX_HANDOFF.md` ข้อ 7
และกติกา branch `develop` เป็นที่รวมงานก่อนขึ้น `main` — `docs/github-workflow.md` ข้อ 1.5

**ทำไม:** ใน 1.0 ระบบย่อยส่งเบราว์เซอร์ไป `sso/authorize` ของ **API** ซึ่งต้องมี Bearer ที่เบราว์เซอร์แนบไม่ได้
จึงได้ 401 เสมอ · callback ที่ Core Hub เริ่มเองกัน login CSRF ไม่ได้ · token อายุ 15 นาทีทำให้ผู้ใช้หลุดบ่อย
จนมีระบบย่อยไปทำ session ของตัวเอง (ขัดข้อ 5.1 และทำให้ถอนสิทธิ์ช้าถึง 8 ชั่วโมง) ·
และระบบที่ต้องตอบ 429/503 ไม่มี error code ให้ใช้

### สัญญา

- `docs/auth-contract.md` ข้อ 5 เขียนใหม่ — **ทุก sign-in เริ่มที่ `GET /auth/login` ของระบบย่อย**
  ซึ่งสร้าง `state` แล้วส่งไป**เว็บ**ของ Core Hub `/sso/authorize` · flow จาก sidebar · endpoint ทั้งสองฝั่ง
- ข้อ 5.1 — callback 3 แบบ: ไม่มี state → ทิ้ง token แล้ว `302 /auth/login` · state ไม่ตรง → `401` ไม่ redirect ·
  ผ่าน → คุกกี้ session แล้วไปหน้า `next` · ไม่สำเร็จต้องไม่มีคุกกี้ session · `no-store` · `no-referrer` ·
  ห้าม log URL เต็มของ callback
- ข้อ 5.2 (ใหม่) — state ≥ 32 ไบต์ base64url · คุกกี้ `<ชื่อ>_sso_state` `Path=/auth/callback` ไม่เกิน 600 วินาที ·
  กฎของ `next` 5 ข้อ ตรวจซ้ำตอนใช้
- ข้อ 6 — คุกกี้ session ชื่อ `<ชื่อ>_access_token` (เดิม `core_hub_access_token` ที่ชนกันบน localhost)
- ข้อ 7 — Silent re-SSO: API ตอบ 401 JSON · frontend navigate ทั้งหน้าไป `/auth/login?next=` ·
  ห้าม redirect ทับฟอร์ม · กันวน 30 วินาที · logout หมายถึงออกทั้งระบบ
- ข้อ 9 — `/auth/login` และ `/auth/logout` เป็นข้อยกเว้นที่ต้องมี (redirect เท่านั้น ไม่มีฟอร์ม)
- ข้อ 11 — 1.1 ส่งมอบแล้ว · `aud` แยกตามระบบย่อยย้ายไปเวอร์ชันถัดไป
- `contracts/error-codes.json` — เพิ่ม `TOO_MANY_REQUESTS` (429) และ `SERVICE_UNAVAILABLE` (503)
  ทั้งคู่ต้องมี `Retry-After` · 503 ใช้เมื่อสิ่งที่พึ่งพาไม่พร้อมชั่วคราว ห้ามใช้แทน 500 ของบั๊ก
  (`docs/api-conventions.md` ข้อ 4 · endpoint นอก `/api/v1` เป็น 4 path)
- `contracts/jwt-contract.json` ก้อน `sso` (path ทั้งหมด · suffix ของคุกกี้ · `stateTtlMaxSec`)
- `contracts/openapi.yaml` — `/auth/login` · `/auth/logout` · callback ตอบ 302/400/401/403 ·
  `session.expiresAt` ใน `/api/v1/me` · error enum 9 ค่า
- `contracts/log-events.json` — reason `sso_restart_without_state` `sso_state_missing` `sso_state_mismatch` ·
  เพิ่ม URL เต็มของ callback และ header `Cookie` ทั้งก้อนเข้า `mustNeverLog`
- `schemas/subsystem.schema.json` — `core_hub_web_url` (ไม่บังคับ แต่ L3-16 ต้องใช้)

### ตัวตรวจ

- `API-04` (`scripts/check-api-conventions.sh`) — อ่านรายการจาก `contracts/error-codes.json` แทนการเขียนไว้ในสคริปต์ ·
  ตรวจค่าที่ประกาศใน `ErrorCode` (object · enum · type) ด้วย ไม่ใช่แค่รูป `code: '…'` ·
  ถ้าไม่มี node จะอ่านรายการด้วย grep และข้ามเฉพาะส่วน `ErrorCode` · fixture ใหม่ `__fixtures__/API-04`
- `API-04` **เลิกตรวจไฟล์ทดสอบ** (`*.spec.ts` · `test/`) — ค่า `code:` ในไฟล์ทดสอบเป็นข้อมูลตัวอย่าง
  เช่น `code: 'SCI'` ของ reference data ไม่ใช่ error contract (เดิมตีตก false positive จนระบบที่ทำถูกต้อง
  merge ไม่ได้) · fixture pass เพิ่ม `rooms.service.spec.ts` เป็น regression
- ตัวสแกน `ErrorCode` ย้ายไปเป็นไฟล์ `scripts/lib/api04-errorcode-scan.js` — heredoc ที่ซ้อนใน
  command substitution ทำให้ **bash 3.2 ของ macOS parse ทั้งสคริปต์ไม่ผ่าน** ทีมที่ใช้ Mac
  จะรันตัวตรวจในเครื่องไม่ได้เลย (CI บน Linux ไม่เจอ)

### conformance

- L3 เริ่มที่ `/auth/login` แล้วเล่นบทเว็บของ Core Hub · ข้อใหม่ **L3-16 – L3-22**
  (login → เว็บ Core Hub · คุกกี้ state · callback ไม่มี state · state ไม่มีคุกกี้ · state สลับกัน ·
  `next=//evil` · logout) · รวม **62 → 69 ข้อ** · รายละเอียดใน `docs/conformance.md`
- อ่าน `Set-Cookie` ทุกตัวแล้วหาตามชื่อ (callback ตั้ง 2 คุกกี้) · รับ `--core-hub-web`
- เจอ `429` ที่ `Retry-After` ≤ 5 วินาที รอแล้วลองใหม่ 1 ครั้ง · บรรทัดสรุปแสดง `retries: N`
- สถานะ `WARN` ที่ไม่ทำให้ตก · error code นอก `error-codes.json` เป็น WARN (เวอร์ชันถัดไปเป็น FAIL)
- ตัวอ่าน `subsystem.yaml` รับ CRLF — เดิมบน Windows ที่ `core.autocrlf=true` คอมเมนต์บรรทัดแรกทำให้ runner หยุดทันที
- ผลกับ reference implementation (demo-student-subsystem `feature/student-service/silent-sso`):
  `RESULT: 69 passed · 0 failed · 0 skipped · 0 warnings · retries: 0` ด้วยค่า rate limit แบบ default ·
  ส่วน demo `main` (มาตรฐาน 1.0) ตก 9 ข้อที่ L3 ชุดใหม่ ตามที่ควรเป็น

### เอกสารอื่น

- `docs/reference-data.md` (ใหม่) — สารบัญชุดข้อมูลอ้างอิงกลาง + สัญญากลางโดยย่อ + เส้นแบ่งชัดว่า
  ข้อมูลบุคคล (`/api/v1/people`) ไม่ใช่ reference data ห้าม cache (หน้าที่ค้างจาก `SHARED_DATA_HANDOFF` ข้อ 7.1)
- `docs/LOCAL_INTEGRATION_GUIDE.md` — แทนฉบับเก่าด้วยร่างล่าสุดของ PL (25 ก.ย.) จะตามแก้ส่วน SSO
  เมื่องานฝั่ง demo ส่งมอบ

- `ai/AGENTS.md` เพิ่ม 4 ข้อใน "สิ่งที่ agent มักทำผิด" · `docs/subsystem-registry.md` หมายเหตุเรื่อง `callback_url` ·
  `templates/subsystem.yaml` · `docs/repo-structure.md` · ข้อความที่ยังเขียนว่า "7 ค่า"

### branch `develop`

- `docs/github-workflow.md` ข้อ 1.5 (ใหม่) — repo ที่มีหลายคนทำพร้อมกันหรือมี dev server ใช้ branch หลัก 2 ตัว
  คือ `develop` รวมงานแล้วทดสอบบน dev server และ `main` เป็น production · Core Hub ต้องใช้ · ระบบย่อยเลือกใช้ได้ ·
  repo มาตรฐานไม่ใช้เพราะ tag ทำหน้าที่เป็น release อยู่แล้ว
  feature PR เข้า `develop` แบบ squash · PR `develop` → `main` และ `main` → `develop` ใช้ merge commit
  เพราะถ้า squash แล้ว `main` กับ `develop` จะแยกประวัติกัน · ข้อ 1.1, 1.2, 1.4, 3 และ system prompt ข้อ 5 ปรับให้ตรงกัน
- `GH-01` (`scripts/check-branch-name.sh`) — ยอมรับ PR `develop` → `main` และ `main` → `develop`
  โดยดู base จาก `GITHUB_BASE_REF` (หรือ argument ที่ 3) ส่วนชื่ออื่นยังต้องเป็น `feature/<subsystem>/<เรื่อง>`
  และการตรวจในเครื่องที่ไม่มี base ยังให้ `develop` กับ `main` ไม่ผ่านเหมือนเดิม · `self-test.sh` เพิ่ม 6 กรณี
- `templates/ci.yml` · ตัวอย่างใน `ci-compliance-spec.md` ข้อ 6.2 และ `core-hub-rules.md` ข้อ 6 — รัน CI กับ PR ที่เข้า `develop` ด้วย
  (repo ที่ไม่มี `develop` ไม่มีผลอะไร)
- `ci-compliance-spec.md` ข้อ 4.1–4.2 และ `org-settings/` — เลิกบังคับ linear history บน `main` ของระบบย่อย เพราะ PR release ต้องเป็น merge commit
  ส่วน feature PR ยังเป็น squash โดยคุมที่ merge method ของ repo · repo ที่ใช้ `develop` ต้องเปิด merge commit
  และตั้ง `develop` เป็น default branch ก่อน merge PR release ครั้งแรก (ไม่งั้น "Automatically delete head branches" จะลบ `develop`)
  · ruleset ชื่อ branch ยกเว้น `refs/heads/develop` เพิ่มจาก `refs/heads/main` · `apply-rulesets.sh` ยอมรับ default branch เป็น `develop`

### ที่ค้างจาก `main` และออกพร้อมเวอร์ชันนี้

- `scripts/check-ui-tokens.sh` (`UI-01`..`UI-04`) — สแกนทั้ง `frontend/` แทน `frontend/src`
  เดิมถ้า Next.js วาง `app/` ไว้ที่ราก `frontend/` สคริปต์จะไม่เจอไฟล์ไหนเลยแล้วผ่านเฉย ๆ
  (fixture ใหม่ `__fixtures__/UI-01-NOSRC`) · ยกเว้นไฟล์ token กลาง `globals.css` และ `csmju/`
  จาก template ซึ่งประกาศสีเป็น hex โดยตั้งใจ — เดิม `globals.css` ใต้ `src/` ทำให้ `UI-01` ตกเอง
- ข้อความ `UI-01` และ `SEC-03` ชี้ไป `ui-design-system.md` แทน `ui-prompt-template.md`
  ที่ถูกรวมเข้าไปแล้ว (เช่นเดียวกับตารางกฎใน `ci-compliance-spec.md` ข้อ 7)
- ชื่อ token: เลิกใช้ `--csmju-*` ใน `aie-workflow.md`, `ci-compliance-spec.md`,
  `templates/pull_request_template.md` ให้ตรงกับ `ui-design-system.md` ข้อ 3
  (Tailwind v4 `@theme` เช่น `bg-primary-container`)
- `ui-design-system.md` ข้อ 16.1 — ใช้ `frontend/` + `backend/` ตาม `repo-structure.md`
  (เดิมเขียน `web/` + `api/`) · ข้อ 17.0 — ระบุว่า template `csmju-subsystem-web` อยู่ใน repo
  `csmju-core-hub` และให้ copy ลง `frontend/` ด้วย `pnpm` แทนการแยก repo `-web` ด้วย `npm`

### ระบบย่อยต้องทำอะไรเมื่อเลื่อนมา 1.1

1. เพิ่ม `GET /auth/login` · แก้ `GET /auth/callback` ตาม auth-contract ข้อ 5.1 · เพิ่ม `POST /auth/logout`
   (คัดลอกจาก demo-student-subsystem ได้) · ถ้ามี session ของตัวเองให้เลิกใช้
2. เปลี่ยนชื่อคุกกี้เป็น `<ชื่อ>_access_token` (และคุกกี้ state `<ชื่อ>_sso_state`)
3. เพิ่ม `CORE_HUB_WEB_URL` ใน `.env` และ `core_hub_web_url` ใน `subsystem.yaml` ·
   เพิ่ม `/auth/login` `/auth/logout` ใน `public_endpoints`
4. frontend: ใช้ตัวจับ 401 และ re-SSO จาก template (`SSO_FIX_HANDOFF.md` ข้อ 8)
5. ถ้าตอบ 429 หรือ 503 ให้ใช้ code ใหม่พร้อม `Retry-After`
6. ขอ PL เลื่อน submodule · pin ใน `ci.yml` · `.standards-version` · `standards_version` เป็น `1.1.0`
7. `UI-01`..`UI-04` ตรวจทั้ง `frontend/` แล้ว ถ้ามีสี hex นอก `globals.css` และ `csmju/` จะตก ต้องเปลี่ยนเป็น token ก่อนเลื่อน
   (Core Hub ยกเว้น `UI-01`..`UI-04` อยู่แล้ว)
8. ถ้าจะใช้ `develop` ให้ทำ "ตั้งค่าครั้งแรก" ใน github-workflow.md ข้อ 1.5 · Core Hub ต้องเลื่อนเป็น 1.1.0 ก่อนเปิด PR release ครั้งแรก
   ไม่งั้น `GH-01` ของ 1.0.x จะตีตก PR `develop` → `main`
9. repo ที่มี ruleset อยู่แล้วจะยังใช้ชุดเดิม เพราะ sweep สร้างเฉพาะตัวที่ขาดและไม่ทับของเดิม (org-settings-checklist.md)
   DevOps ต้องรัน `org-settings/apply-rulesets.sh repo <ชื่อ repo>` ให้แต่ละ repo ที่จะใช้ `develop`

Core Hub ยังรับระบบย่อย 1.0 อยู่ (กดจาก sidebar แล้วเข้าได้เหมือนเดิม) แต่ละทีมจึงเลื่อนตามจังหวะของตัวเองได้

---

## 1.0.1 — 2026-09-26

- `scripts/lib/allowed-deps.json` — เพิ่ม `@nestjs/schedule` ใน `allowed_backend` สำหรับงานตั้งเวลา (scheduled job)
  มาจากคำขอของทีม CampusShare ที่มีงานตั้งเวลา 3 งาน (ยกเลิกคำขอยืมที่เจ้าของไม่ตอบ · ติดธงคำขอที่เกินกำหนดคืน ·
  เก็บ listing ที่ไม่มีความเคลื่อนไหวเกิน 180 วัน) เลือกเพิ่มเข้า whitelist แทนการทำ exception รายทีม
  เพราะเป็นแพ็กเกจทางการของ NestJS และระบบย่อยอื่นน่าจะต้องใช้งานแบบเดียวกัน
- `docs/tech-stack.md` ข้อ 1.4.1 (ใหม่) — กติกาของงานตั้งเวลา 3 ข้อ: รันซ้ำได้โดยไม่เสียหาย · ระบุ time zone ·
  ถ้ารันหลาย instance ให้ใช้ advisory lock ของ PostgreSQL
- fixture `__fixtures__/ARC-02-03/pass` ใช้ `@nestjs/schedule` เพื่อพิสูจน์ว่า `ARC-02` ยอมรับ

ออกจาก tag `v1.0.0` โดยตรง จึง**ไม่รวม**งานที่ค้างอยู่บน `main` หลัง 1.0.0 (เช่น `UI-01`..`UI-04` ที่ตรวจทั้ง `frontend/`)
งานเหล่านั้นจะออกในเวอร์ชันถัดไป

**ระบบย่อยต้องทำอะไร:** ถ้าต้องใช้ `@nestjs/schedule` ให้ขอ PL เลื่อนเป็น 1.0.1 ได้แก่ pin ใน `ci.yml` · submodule `standards` ·
`.standards-version` · `standards_version` ใน `subsystem.yaml` · ระบบย่อยอื่นไม่ต้องทำอะไร

---

## Errata ของ 1.0.0 — 2026-09-23

แก้เอกสารเท่านั้น ไม่มีการเปลี่ยนกฎหรือสคริปต์ตรวจ จึงไม่ขึ้นเวอร์ชัน
(`VERSION` ยังเป็น `1.0.0` ระบบย่อยไม่ต้องเลื่อน `.standards-version`)

- `tech-stack.md` ข้อ 1.2.1 (ใหม่) — `typecheck` ของ frontend ต้องเป็น
  `next typegen && tsc --noEmit` ไม่ใช่ `tsc --noEmit` เฉย ๆ
  Next.js สร้าง type ของ route/layout (`LayoutProps`, `PageProps`) ตอน dev/build
  เท่านั้น สคริปต์แบบเดิมจึงผ่านในเครื่อง (มี `.next/` ค้าง) แต่ตกบน CI ที่ checkout
  ใหม่ด้วย `TS2304: Cannot find name 'LayoutProps'` — เจอจริงตอนทำ frontend ของ Core Hub
- `tech-stack.md` ข้อ 1.2 — ระบุ Next.js เป็น `15.5+` เพราะ `next typegen` เพิ่งมีในเวอร์ชันนั้น
- `ai/AGENTS.md` — เพิ่มลงตาราง "สิ่งที่ agent มักทำผิด" และเพิ่มคำสั่ง
  `rm -rf frontend/.next && pnpm -r typecheck` ในชุดคำสั่งที่ต้องรันก่อนส่งงาน

---

## 1.0.0 — 2026-09-11

**เวอร์ชันแรกที่ประกาศใช้จริง** — เริ่มนับใหม่ที่ 1.0.0

> เวอร์ชัน 1.0.0–1.3.0 ก่อนหน้านี้เป็นช่วงเตรียมการ ยังไม่เคยส่งมอบให้ทีม AIE ทีมใดใช้งาน
> และยังไม่มีระบบย่อยใดผูกอยู่ จึงยกเลิกประวัติเดิมทั้งหมดแล้วเริ่มนับใหม่
> ไม่ถือเป็น breaking change เพราะไม่มีผู้ใช้เดิม

### ที่มาของเนื้อหา

มาตรฐานฉบับนี้เขียนจาก **ระบบที่ทำงานได้จริงและผ่านการทดสอบแล้ว** ไม่ใช่จากการออกแบบล่วงหน้า:

| อ้างอิงจาก | สถานะ |
|---|---|
| `csmju-core-hub` | Core Hub จริง — login · RS256 · JWKS · Subsystem Registry · Central SSO (unit 35 เคส) |
| `demo-student-subsystem` | reference implementation — unit 77 · e2e 70 · integration 13 · conformance 62/62 |

ทุกข้อกำหนดในเอกสารนี้มีโค้ดที่ทำได้จริงรองรับ และมีชุดทดสอบที่ยิงระบบจริงเป็นตัวพิสูจน์

### สัญญาการยืนยันตัวตน (`docs/auth-contract.md` — เขียนใหม่ทั้งฉบับ)

- Core Hub ออก JWT **RS256** · `iss=core-hub` · `aud=csmju2030` · `kid=core-hub-2026` · อายุ 15 นาที
- เผยแพร่กุญแจสาธารณะที่ `/api/v1/.well-known/jwks.json` แบบ **RFC 7517 ดิบ**
- **ระบบย่อยเป็นผู้ตรวจ JWT เอง** ผ่าน JWKS (8 ขั้น) — ยังไม่มี API Gateway ในสถาปัตยกรรมปัจจุบัน
- Central SSO: `GET /api/v1/auth/sso/authorize` → 302 ไปยัง `callback_url` ที่ลงทะเบียนไว้เท่านั้น
- ระบบย่อยรับที่ `GET /auth/callback` แล้วตั้งคุกกี้ HttpOnly ของตัวเอง

### สิทธิ์ (`docs/authorization.md` — ใหม่)

- Core Hub ตัดสิน *ใครเข้าระบบไหนได้* (ตรวจ core role กับ `default_role_mapping` ก่อน redirect)
- ระบบย่อยตัดสิน *เข้ามาแล้วทำอะไรได้* ผ่านชั้น permission `resource:action[:own|:any]`
- แยก `401` (ไม่รู้ว่าใคร) กับ `403` (รู้แล้วแต่สิทธิ์ไม่พอ) อย่างเคร่งครัด

### สัญญา API (`docs/api-conventions.md`)

- pagination เป็น `?page=1&limit=20` (จากเดิม `per_page`)
- `VALIDATION_ERROR` คืน **400** (จากเดิม 422) ให้ตรงกับพฤติกรรม `ValidationPipe` ของ NestJS
- field ใน JSON เป็น `camelCase` · ฐานข้อมูลเป็น `snake_case` (แยกชั้นกันชัดเจน)
- เพิ่มกฎ URL: resource เป็นพหูพจน์ `kebab-case` · `POST`→201 · `DELETE`→200 + `{id, deleted:true}`

### ฐานข้อมูล (`docs/data-dictionary.md`)

- ตาราง/คอลัมน์เป็น `snake_case` ผ่าน `@map`/`@@map` · field ใน Prisma เป็น `camelCase`
- ห้ามลบหรือ squash migration · เปลี่ยนชื่อคอลัมน์ต้องใช้ `RENAME COLUMN` ไม่ใช่ drop+add

### Tech stack (`docs/tech-stack.md`)

- ระบุเวอร์ชันที่ใช้จริง: Node 22 · NestJS 11 · TypeScript 5.9 · **Prisma 7.9.1 (pin)** · PostgreSQL 16+
- แก้ whitelist ที่ทำให้ Prisma 7 ใช้ไม่ได้ — เพิ่ม `@prisma/adapter-pg`, `pg`, `jose`, `dotenv`

### เครื่องมือใหม่

- `conformance/` — ชุดทดสอบ **runtime** แบบ black-box ไม่มี dependency (L1 32 · L2 47 · L3 62 เคส)
- `contracts/` — สัญญาที่เครื่องอ่านได้ (JWT · error code · vocabulary · log event · OpenAPI)
- `ai/` — `AGENTS.md`, `TASK_TEMPLATE.md`, `CHECKLIST.md` สำหรับสั่งงาน AI ให้ได้ผลตรงกันข้ามโมเดล

### Profile `core-hub` (`docs/core-hub-rules.md` — ใหม่)

- `csmju-core-hub` ไม่ใช่ระบบย่อย จึงมี workflow แยก `core-hub-compliance.yml` ที่ตั้ง `CSMJU_PROFILE=core-hub`
- ยกเว้นเฉพาะกฎที่ขัดกับหน้าที่ของมันเอง: `SEC-04` `SEC-05` `GH-03` `GH-04` `API-01` `API-06` `UI-01..04`
  · `DD-01` ถูกข้ามในสคริปต์ · `ARC-02` ขยาย whitelist ด้วยคีย์ `allowed_core_hub`
- กฎที่เหลือ 19 ข้อยังบังคับเต็มเหมือนระบบย่อย และมี 3 ข้อที่เข้มกว่า (JWKS ดิบ · สัญญา JWT ห้ามเปลี่ยน · ตรวจ `callback_url`)
- self-test ยืนยันทั้งสองทิศทาง: fixture เดียวกันต้องตกใน profile `subsystem` และผ่านใน `core-hub`
  รวมถึงยืนยันว่าค่าเริ่มต้นคือ `subsystem` และ workflow ของระบบย่อยไม่ส่ง profile นี้ (45 assertions)

### กฎใหม่

- `QA-06` — ชื่อ package ในแต่ละ workspace ต้องไม่ซ้ำ และ `--filter <name>` ใน script ที่รากต้องชี้ไปยัง
  package ที่มีอยู่จริง มิฉะนั้น pnpm จะไม่รันอะไรเลยแต่คืน exit 0 ทำให้ script ที่รากดูเหมือนผ่าน
  (พบจริงใน `demo-student-subsystem` — root กับ backend ตั้งชื่อซ้ำกัน `pnpm test` ที่รากจึงไม่ได้รันเทสต์)

### แก้บั๊กในเครื่องมือตรวจเอง

- `API-02` เคยตีตกชื่อ path parameter แบบ camelCase (`:exceptionId`) ทั้งที่ URL จริงยังเป็น kebab-case
- `pnpm/action-setup` ฮาร์ดโค้ด `version: 9` ซึ่งชนกับ `packageManager` ใน `package.json` ของ repo ที่เรียก
- `node_version` ค่าเริ่มต้นเป็น `20` ทั้งที่ `tech-stack.md` ล็อก Node 22
- `run-all-checks.sh` ใช้ associative array ซึ่ง bash 3.2 (ค่าเริ่มต้นของ macOS) ไม่รองรับ

### กฎ CI ที่แก้ให้ตรงกับสถาปัตยกรรมจริง

| รหัส | เดิม | ใหม่ |
|---|---|---|
| `SEC-04` | ห้ามระบบย่อย verify JWT เอง | **ต้อง** verify ด้วย JWKS + `kid` · ห้าม HS256 / secret / กุญแจฮาร์ดโค้ด |
| `DD-03` | บังคับ `snake_case` กับ field ใน TypeScript | บังคับกับ **ฐานข้อมูล** เท่านั้น (`@map`) · JSON/TS ยังเป็น camelCase |
| `ARC-02` | whitelist ไม่มี dependency ที่ Prisma 7 ต้องใช้ | เพิ่มให้ครบ |
| `API-*` | `per_page` · `VALIDATION_ERROR` = 422 | `limit` · 400 |
