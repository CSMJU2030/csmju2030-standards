# มาตรฐาน GitHub Workflow
**โครงการ:** CSMJU2030 (ระบบ MIS สาขาวิชาวิทยาการคอมพิวเตอร์)
**ดูแลโดย:** ทีม Infrastructure & DevOps

เอกสารฉบับนี้คือข้อกำหนดด้านการจัดการซอร์สโค้ด บังคับใช้กับทุกระบบย่อย (Subsystem) โดยอ้างอิงจากแผนสถาปัตยกรรมระบบและการบริหารจัดการทีมพัฒนา (CSMJU2030-PM)

---

## 1. GitHub Workflow และการทำงานร่วมกัน

เพื่อให้ AIE และ PL ทำงานร่วมกันได้อย่างเป็นระบบและโค้ดไม่พัง ให้ปฏิบัติตามกฎและลำดับการทำงาน (Flow) จากส่วนกลางอย่างเคร่งครัด:

### 1.1 กฎเหล็กของ Workflow
1. **Branch Protection:** ไม่ push ตรงเข้า `main`/`production` เด็ดขาด
2. **Reviewer:** กำหนด CODEOWNERS ให้ PL (Project Lead) เป็น required reviewer ของ `main` เสมอ
3. **Feature Branch:** AIE ต้องทำงานใน feature branch เท่านั้น
4. **Naming Convention:** ใช้ branch naming รูปแบบ `feature/<subsystem>/<เรื่องที่ทำ>`
5. **CI/CD:** CI จะรัน automated compliance ทุกครั้งที่เปิด PR

### 1.2 ขั้นตอนการทำงานจริง (Git Commands สำหรับ AIE)
เมื่อเริ่มต้นพัฒนาฟีเจอร์ใหม่ ให้ทำตามลำดับคำสั่งนี้:

**ขั้นตอนที่ 1:** แตก Branch ใหม่สำหรับทำงาน (ใช้ naming convention ตามข้อ 1.1 ข้อ 4)
```bash
git checkout -b feature/equipment/add-borrow-return
```

**ขั้นตอนที่ 2:** อัปเดตมาตรฐานส่วนกลางก่อนเขียนโค้ดเสมอ (เพื่อดึง `csmju2030-standards` ล่าสุด)
```bash
git submodule update --remote standards/
```

**ขั้นตอนที่ 3:** พัฒนาโค้ด เมื่อเสร็จแล้วให้เพิ่มไฟล์และ Commit
```bash
git add .
git commit -m "feat(equipment): add borrow-return flow"
```

**ขั้นตอนที่ 4:** Push ขึ้น Repository 
```bash
git push origin feature/equipment/add-borrow-return
```

**ขั้นตอนที่ 5:** เปิด Pull Request (PR) ให้ PL ตรวจสอบ (ผ่าน GitHub UI หรือ gh cli)
```bash
gh pr create --base main --title "feat(equipment): add borrow-return flow"
```

> **หมายเหตุ:** ชื่อ commit และ PR title ต้องตาม Commit Convention ในข้อ 1.3

---

### 1.3 Commit Message Convention

บังคับใช้รูปแบบ [Conventional Commits](https://www.conventionalcommits.org/) เพื่อให้ generate changelog อัตโนมัติได้ และเพื่อให้ PL scan ประวัติงานได้เร็ว:

```
<type>(<subsystem-scope>): <คำอธิบายสั้นๆ ภาษาอังกฤษหรือไทยก็ได้>
```

**Type ที่อนุญาต:**
| Type | ใช้เมื่อ |
|---|---|
| `feat` | เพิ่มฟีเจอร์ใหม่ |
| `fix` | แก้บั๊ก |
| `chore` | งานเบื้องหลัง (อัปเดต dependency, config) |
| `refactor` | ปรับโครงสร้างโค้ดโดยไม่เปลี่ยนพฤติกรรม |
| `docs` | แก้เอกสาร |
| `test` | เพิ่ม/แก้ test |
| `ci` | แก้ CI/CD pipeline (ยกเว้นแก้ไฟล์ใน `.github/workflows/` ตรงๆ ซึ่งห้ามตามข้อ 5) |

**ตัวอย่าง:**
```
feat(equipment): add borrow-return flow
fix(equipment): correct due-date calculation timezone bug
```

**PR ควรเล็กและโฟกัสเรื่องเดียว** — ถ้า PR แตะทั้ง frontend และ backend logic ที่ไม่เกี่ยวกัน ให้แยกเป็นคนละ PR เพื่อให้ PL review ได้ไวและ diff อ่านง่าย

---

### 1.4 แนวทางทำงานเดี่ยวต่อ Subsystem

แต่ละ subsystem มี AIE รับผิดชอบ 1 คน (1 คน = 1 ระบบย่อย) จึงไม่มี concurrent conflict ภายใน repo เดียวกัน แต่ยังต้องรักษาวินัยดังนี้:

1. **Sync กับ standards กลางสม่ำเสมอ:** ก่อนเริ่มงานแต่ละวัน ให้ `git fetch origin` และ `git submodule update --remote standards/` เพื่อไม่ให้ตกรุ่นจากมาตรฐานกลางที่อาจถูกอัปเดตโดยทีมอื่น
2. **Branch อายุสั้น:** feature branch ไม่ควรค้างเกิน 2-3 วัน เพื่อให้ PL review ทัน และลดความเสี่ยงที่ `main` เปลี่ยนไปมากจนต้อง resolve conflict ตอน merge
3. **Merge strategy:** ใช้ **Squash and merge** เข้า `main` เท่านั้น เพื่อให้ 1 PR = 1 commit ใน history ของ main
4. **Cross-subsystem dependency:** ถ้างานต้องพึ่งพา API ของ subsystem อื่น ให้ประสานผ่าน `openapi.json` ของ subsystem นั้น (ดูข้อ 3 ใน tech-stack.md) แทนการเข้าไปแก้ repo อื่นเอง

---

## 2. Monorepo Tooling ภายใน 1 Subsystem

เนื่องจากแต่ละ repo บรรจุทั้ง `frontend/` และ `backend/` ไว้ด้วยกัน (monorepo ระดับ subsystem) ต้องมีเครื่องมือจัดการเพื่อไม่ให้ CI ช้าและ dependency ปนกัน:

*   **Package manager:** ใช้ **pnpm** พร้อม `pnpm-workspace.yaml` แยก workspace ระหว่าง `frontend` และ `backend` (ห้ามใช้ `npm install` เดี่ยวๆ ที่ root)
*   **Task runner:** ใช้ `pnpm -r <script>` และ `pnpm --filter <workspace> <script>` เป็นพื้นฐาน — ทั้ง Core Hub และ
    reference implementation ใช้แค่นี้ **Turborepo ใช้ได้แต่ไม่บังคับ** (อยู่ใน whitelist) เพิ่มเมื่อ repo โตจนเวลา CI เป็นปัญหาจริง
*   **ชื่อ workspace ต้องไม่ซ้ำกัน** — ถ้า `name` ใน `package.json` ที่รากซ้ำกับของ `backend/`
    `pnpm --filter backend test` จะไม่ match อะไรเลยแล้วคืน exit 0 (กฎ `QA-06` ดู [`repo-structure.md`](repo-structure.md) ข้อ 3)

---

## 3. CI Compliance Checklist (`.github/workflows/`)

เพื่อให้ CI pipeline มาตรฐานตรวจอย่างน้อยดังนี้ทุก PR ที่เข้า `main`:

1. **Lint & Format:** ESLint + Prettier ผ่านทั้ง `frontend/` และ `backend/`
2. **Type Check:** `tsc --noEmit` ผ่านทั้งสองฝั่ง 
3. **Unit Test:** รัน test suite ของ workspace ที่ถูกแก้ (ผ่าน coverage ขั้นต่ำที่ทีมกำหนด)
4. **Stack Compliance Scan:** สคริปต์ตรวจ `package.json` ว่าไม่มี dependency นอกเหนือจาก Next.js/NestJS/Prisma stack ที่อนุญาต
5. **Secret/DB-Isolation Scan:** grep หา connection string หรือ `pg`/`prisma client` import ใน `frontend/` — ถ้าเจอ ให้ CI fail ทันที
6. **Submodule Check:** ตรวจว่า `standards/` submodule pointer ตรงกับ commit ล่าสุดที่ PL อนุมัติ 
7. **Build:** `next build` และ `nest build` ต้องผ่านทั้งคู่ก่อน merge ได้

> **PR แรกของ repo (bootstrap) เป็นข้อยกเว้นของกฎ `GH-03`**
> PR ที่ติดตั้งมาตรฐานครั้งแรกจำเป็นต้องเพิ่ม `.github/workflows/ci.yml`, `CODEOWNERS` และ submodule
> `standards/` ซึ่งเป็นไฟล์ที่ `GH-03` ห้ามแตะ — PR นี้จึงต้องให้ DevOps เป็นผู้ merge โดย override
> ผลของ `GH-03` หลังจากนั้นกฎบังคับเต็มตามปกติ ไม่มีข้อยกเว้นอีก

---

## 4. Secrets & Environment Management

*   ห้าม commit ไฟล์ `.env`, `.env.local` เข้า repo เด็ดขาด (ต้องอยู่ใน `.gitignore` ตั้งแต่ scaffold แรก)
*   ใช้ `.env.example` เป็น template ระบุชื่อ key ที่ต้องมี (ไม่ใส่ค่าจริง) ให้ AIE คนใหม่ copy ไปตั้งค่าเอง
*   Secret สำหรับ CI/CD (เช่น DB URL ของ staging) เก็บใน **GitHub Actions Secrets** ระดับ repo เท่านั้น ห้าม hardcode ในไฟล์ workflow
*   Backend เป็นจุดเดียวที่ถือ DB connection string จริง 

---

## 5. System Prompt สำหรับ AI (GitHub Workflow)

*สำหรับป้อนให้ AI Agent ก่อนเริ่มเขียนโค้ด เพื่อให้ AI ปฏิบัติตามมาตรฐานโปรเจกต์:*

```text
คุณคือ AI Assistant สำหรับเขียนโค้ดในโครงการ CSMJU2030 (1 ระบบย่อย = 1 Repo) กรุณาปฏิบัติตามกฎต่อไปนี้อย่างเคร่งครัด:

1. GitHub Actions:
   - ห้ามแก้ไขไฟล์ในโฟลเดอร์ `.github/workflows/`
2. Monorepo Tooling:
   - ใช้ pnpm workspace เท่านั้นสำหรับจัดการ frontend/backend ภายใน repo เดียวกัน ห้ามใช้ npm/yarn (กฎ `QA-05`)
   - ตั้งชื่อ `name` ใน package.json ของแต่ละ workspace ไม่ให้ซ้ำกัน (กฎ `QA-06`)
3. Commit Convention:
   - ทุก commit และ PR title ต้องตาม Conventional Commits รูปแบบ `<type>(<subsystem-scope>): <คำอธิบาย>` เช่น `feat(equipment): add borrow-return flow`
4. Secrets:
   - ห้าม hardcode connection string, API key หรือค่าลับใดๆ ในโค้ด ต้องอ่านจาก environment variable เท่านั้น และห้ามสร้าง/แก้ไฟล์ .env ที่มีค่าจริงเข้า repo
```
