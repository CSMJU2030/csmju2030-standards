# Standards Versioning — เลือกและเลื่อนเวอร์ชัน standards ของระบบย่อย

**ใช้ตั้งแต่ standards 1.5.1**

> ทีมเลื่อนเวอร์ชัน standards ของ repo ตัวเองได้ด้วย PR ธรรมดา ให้ PL ของทีม approve แล้ว merge
> โดยไม่ต้องรอ DevOps หรือ PM · แต่ละทีมอยู่คนละเวอร์ชันได้ ไม่มีใครถูกบังคับให้ขึ้นพร้อมกัน

---

## 1. ภาพรวม

ใน repo ระบบย่อยมีไฟล์ 3 ตัวที่เกี่ยวกับเวอร์ชัน standards

| ไฟล์ | ทำหน้าที่ | ใครแก้ |
|---|---|---|
| `.github/workflows/ci.yml` | ปักหมุด**ตัวกลาง**ของ CI (`subsystem-compliance.yml@v1.5.1`) · ตัวกลางเป็นตัวที่อ่าน `.standards-version` และตรวจกฎ `GH-03` `GH-04` | DevOps เท่านั้น (ไม่ต้องแก้ตอน bump) |
| `.standards-version` | บอกว่า CI ต้องตรวจด้วยชุดตรวจของเวอร์ชันไหน เช่น `1.5.1` | ทีม (PL approve) |
| `standards/` (submodule) | สำเนาเอกสารมาตรฐานให้ AIE อ่านในเครื่อง ต้องชี้ tag เดียวกับ `.standards-version` | ทีม (PL approve) |

สิ่งที่เกิดขึ้นในทุก job ของ CI

1. ดึงตัวกลางตามเวอร์ชันที่ `ci.yml` ปักหมุดไว้ พร้อม tag ทั้งหมดของ standards
2. `scripts/select-standards-version.sh` (`GH-04`) อ่าน `.standards-version` ตรวจว่าใช้ได้ แล้วสลับชุดตรวจไปที่ tag นั้น
3. `scripts/run-job.sh` รันเช็คของ job นั้นจากชุดตรวจที่เลือก (รายการเช็คอยู่ใน `scripts/lib/jobs.tsv`)
   · เช็คที่เวอร์ชันนั้นยังไม่มีจะขึ้นว่า "ข้าม"
   · `GH-03` (ห้ามแก้ไฟล์ CI) และ `GH-04` มาจากตัวกลางเสมอ ไม่ว่าจะเลือกเวอร์ชันไหน จึงเลือกเวอร์ชันเก่าเพื่อเลี่ยงกฎสองข้อนี้ไม่ได้

---

## 2. เลื่อนเวอร์ชันเอง (PL / AIE)

### 2.1 ก่อนเลื่อน

- **ดูว่า repo ย้ายแล้วหรือยัง** — เปิด `.github/workflows/ci.yml` ถ้ายังเป็น `@v1.0.0` แปลว่ายังไม่ย้าย
  ให้รอ DevOps ย้ายตามข้อ 4 ก่อน (ถ้าเลื่อนตอนนี้ CI จะตก `GH-03` และ `GH-04`)
- **อ่าน [`CHANGELOG.md`](../CHANGELOG.md)** ของทุกเวอร์ชันที่ข้ามไป เพราะเวอร์ชันใหม่อาจมีเช็คเพิ่ม
  เช่น 1.5.0 เพิ่ม `ARC-04` (ต้องมี backend NestJS) ถ้าโค้ดยังไม่ผ่าน PR เลื่อนเวอร์ชันจะไม่ผ่านไปด้วย
- ไม่ต้องขึ้นเวอร์ชันล่าสุดเสมอไป เลือกเวอร์ชันที่ทีมพร้อมได้ แต่ต้องไม่ต่ำกว่า `MIN_VERSION` (ข้อ 5.3)

### 2.2 คำสั่ง

ตัวอย่างเลื่อนไป `1.5.1` (แทน `<slug>` ด้วยชื่อระบบ เช่น `quiz` · repo ที่มี `develop` ให้แตกจาก `develop`)

```bash
git switch main && git pull
git switch -c feature/<slug>/bump-standards-v1-5-1

git submodule update --init standards      # ครั้งแรกในเครื่องนี้
git -C standards fetch --tags
git -C standards checkout v1.5.1
echo 1.5.1 > .standards-version

git add .standards-version standards
git commit -m "chore(<slug>): bump standards to v1.5.1"
git push -u origin feature/<slug>/bump-standards-v1-5-1
```

- ชื่อ branch ใช้ตัวพิมพ์เล็กกับขีดกลางเท่านั้น (`GH-01`) จึงเขียน `v1-5-1` ไม่ใช่ `v1.5.1`
- ใน `.standards-version` เขียนแค่ตัวเลข `1.5.1` **ไม่มี `v` นำหน้า**
- ใช้ PowerShell ได้เหมือนกัน (ไฟล์ที่ PowerShell เขียนเป็น UTF-16 หรือ CRLF CI ก็อ่านได้)
- **PR นี้แก้แค่ 2 อย่าง คือ `.standards-version` กับ `standards`** ห้ามแก้ `ci.yml` และไม่ต้องแก้ `subsystem.yaml`

### 2.3 เปิด PR และ merge

1. เปิด PR เข้า `main` (หรือ `develop`) — CI จะตรวจ PR นี้ด้วยชุดตรวจของ**เวอร์ชันใหม่**ทันที
2. ถ้าเช็คผ่านครบ PL ของทีมกด approve แล้ว **Squash and merge** ได้เลย ไม่ต้องรอ DevOps หรือ PM
3. หลัง merge ให้เพื่อนในทีมรัน `git pull && git submodule update --init standards` เพื่อให้ `standards/` ในเครื่องตรงกัน
4. PR อื่นที่เปิดค้างอยู่จะถูกตรวจด้วยเวอร์ชันใหม่เมื่อ CI รันรอบถัดไป เพราะ CI ตรวจผลที่ merge กับ branch ปลายทางแล้ว

### 2.4 ถ้าเช็คของเวอร์ชันใหม่ไม่ผ่าน

- แก้โค้ดใน PR เดียวกันให้ผ่าน หรือ
- ปิด PR นี้ไว้ก่อน ไปแก้โค้ดใน PR อื่นแล้วค่อยกลับมาเลื่อน หรือ
- เลือกเวอร์ชันที่ต่ำกว่าแต่ยังสูงกว่าเดิม
- ถ้าเป็นข้อที่ทีมทำตามไม่ได้จริง ให้ขอข้อยกเว้นผ่าน `.compliance-exceptions.yml` ตามปกติ (DevOps approve)

---

## 3. `GH-04` ตรวจอะไร

ตรวจทุก job ก่อนรันเช็คอื่น ถ้าไม่ผ่านจะตกทุก job

| ตรวจว่า | ข้อความที่เห็น | วิธีแก้ |
|---|---|---|
| มีไฟล์ `.standards-version` | `ไม่พบไฟล์ .standards-version` | `echo 1.5.1 > .standards-version` แล้ว commit |
| เป็นตัวเลข `X.Y.Z` ล้วน | `.standards-version ต้องเป็นเลขเวอร์ชันล้วน` | เอา `v` หรือข้อความอื่นออก |
| มี tag `v<เวอร์ชัน>` จริงใน standards | `ไม่มี tag vX.Y.Z` | ใช้เลขที่มีในหน้า Tags ของ standards |
| ไม่ต่ำกว่า `MIN_VERSION` | `ต่ำกว่าเวอร์ชันขั้นต่ำที่ DevOps กำหนด` | เลื่อนขึ้นตามข้อ 2 |
| ไม่ต่ำกว่าที่ branch ปลายทางใช้อยู่ | `ห้ามถอย standards เป็นเวอร์ชันที่เก่ากว่า branch ปลายทาง` | คงเลขเดิมไว้ · ถ้าจำเป็นต้องถอยจริงให้เปิด issue ขอ DevOps |
| submodule `standards` ชี้ commit ของ tag เดียวกัน | `submodule standards ไม่ได้ชี้ที่ vX.Y.Z` | `git -C standards fetch --tags && git -C standards checkout vX.Y.Z && git add standards` |

repo ที่ไม่มี submodule `standards` ตรวจแค่เลขเวอร์ชัน

อย่ารัน `git submodule update --remote standards/` แล้ว commit เพราะคำสั่งนี้เลื่อน submodule ไปที่ `main` ของ standards
ซึ่งไม่ใช่ tag ที่ `.standards-version` ระบุ ทำให้ตก `GH-04` · ใช้ `git submodule update --init standards/` แทน

---

## 4. ย้าย repo เดิมมาใช้ระบบนี้ (DevOps ทำครั้งเดียว)

repo ที่สร้างก่อน 1.5.1 ยังปัก `ci.yml` ไว้ที่ `@v1.0.0` ซึ่ง `GH-03` ห้ามแก้ submodule และ CODEOWNERS ให้ DevOps เป็นเจ้าของ `/standards`
จึงต้องย้ายทีละ repo หนึ่งครั้ง ด้วย [`org-settings/migrate-ci-entry.sh`](../org-settings/migrate-ci-entry.sh)
(ต้องติด tag `v1.5.1` ก่อน และ login `gh` เป็น org admin หรือสมาชิก team `devops`)

```bash
./org-settings/migrate-ci-entry.sh v1.5.1                    # dry run: แสดงว่าจะแก้ repo ไหน ไม่แตะอะไร
./org-settings/migrate-ci-entry.sh v1.5.1 --apply csmju-quiz # ลองก่อน 1 repo
./org-settings/migrate-ci-entry.sh v1.5.1 --apply            # เปิด PR ทุก repo ที่ยังไม่ย้าย
./org-settings/migrate-ci-entry.sh v1.5.1 --apply --merge    # เปิด PR แล้ว merge แบบ admin ทันที
```

PR ที่สคริปต์เปิดแก้แค่ 2 อย่าง

- `ci.yml` — เปลี่ยนจาก `@v1.0.0` เป็น `@v1.5.1`
- `.github/CODEOWNERS` — ลบบรรทัด `/standards @csmju2030/devops`

`.standards-version` กับ submodule **ไม่เปลี่ยน** ทุกทีมจึงถูกตรวจด้วยชุดเดิม (1.0.0) จนกว่าจะเลื่อนเอง

PR นี้ตก `GH-03` โดยตั้งใจ เพราะแก้ไฟล์ที่มีแต่ DevOps แก้ได้ ต้อง merge แบบ bypass (org admin หรือ team `devops`)

PR ที่เปิดค้างและแก้ `ci.yml` อยู่แล้ว (เช่น PR bump เดิมที่แก้ `@v1.0.0` เอง) จะ conflict หลังย้าย ให้ปิด PR นั้น แล้วเลื่อนใหม่ตามข้อ 2

---

## 5. งานของเจ้าของ standards และ DevOps

### 5.1 ออกเวอร์ชันใหม่

ทำตาม [README หัวข้อ "จะแก้กฎหรือเอกสาร ทำอย่างไร"](../README.md#จะแก้กฎหรือเอกสาร-ทำอย่างไร) (self-test ผ่าน → bump `VERSION` → เขียน `CHANGELOG.md` → ติด tag ใหม่)

- **ติด tag ใหม่ทุกครั้ง ห้ามย้ายหรือลบ tag ที่ปล่อยไปแล้ว** เพราะ repo ที่เลือกเวอร์ชันนั้นอยู่จะถูกเปลี่ยนชุดตรวจโดยไม่รู้ตัว
  และเครื่องที่ fetch tag ไปแล้วจะไม่ตรงกับบน GitHub
- ทีมเลื่อนเองตามข้อ 2 ไม่ต้องไล่แก้ทุก repo

### 5.2 เพิ่มเช็คใหม่

เพิ่มบรรทัดใน `scripts/lib/jobs.tsv` ของเวอร์ชันใหม่ ไม่ต้องแก้ `subsystem-compliance.yml`
ทีมที่ยังอยู่เวอร์ชันเก่าจะยังไม่โดนเช็คใหม่จนกว่าจะเลื่อน

ถ้าเพิ่ม **job ใหม่** (ชื่อ check ใหม่) ต้องแก้ workflow และเพิ่มชื่อ check ใน ruleset ด้วย ซึ่งเป็นการเปลี่ยนตัวกลางตามข้อ 5.4

### 5.3 บังคับเวอร์ชันขั้นต่ำ (`MIN_VERSION`)

`MIN_VERSION` บน `main` ของ standards คือเวอร์ชันต่ำสุดที่ยอมให้ใช้ (ตอนนี้ `1.0.0`)
ยกเลขผ่าน PR ใน standards เมื่อต้องการให้ทุกทีมขึ้นอย่างน้อยถึงเวอร์ชันนั้น เช่นเวอร์ชันเก่ามีช่องโหว่

> ⚠️ มีผลทันทีที่ merge: repo ที่ต่ำกว่าจะตก**ทุก job ในทุก PR** จนกว่าจะเลื่อน
> ประกาศให้ทีมเลื่อนก่อน แล้วค่อยยกเลข

### 5.4 เปลี่ยนตัวกลาง

ตัวกลางคือส่วนที่มาจากเวอร์ชันที่ `ci.yml` ปักหมุด ได้แก่ `subsystem-compliance.yml`, `select-standards-version.sh`,
`run-job.sh`, `check-ci-untouched.sh` (`GH-03`) และ `check-submodule-pointer.sh` (`GH-04`)
ถ้าต้องแก้ส่วนนี้ ให้ออก tag ใหม่แล้วรัน `migrate-ci-entry.sh <tag ใหม่>` ซ้ำเพื่อย้าย `ci.yml` ทุก repo
ถ้าแก้แค่เช็คอื่น ไม่ต้องย้าย

---

## 6. คำถามที่พบบ่อย

**ทำไม `ci.yml` ยังต้องให้ DevOps approve**
GitHub รัน CI ของ PR จาก `ci.yml` ในตัว PR เอง ถ้าใครก็แก้ได้ ก็เขียน `ci.yml` ใหม่ให้ขึ้นเขียวทุกเช็คแล้ว merge อะไรก็ได้
การล็อก `ci.yml` ไว้จึงเป็นตัวกันของทั้งระบบ เราเลยย้ายเลขเวอร์ชันออกมาไว้ใน `.standards-version` แทน

**ทำไมเลื่อน submodule เองได้แล้ว**
CI ไม่ได้รันอะไรจาก submodule เพราะชุดตรวจมาจาก repo standards โดยตรง submodule มีไว้ให้คนอ่าน `GH-04` จึงตรวจแค่ว่าชี้ tag เดียวกับ `.standards-version`

**ช่อง `standards_version` ใน `subsystem.yaml` ยังต้องใส่ไหม**
ไม่ต้อง ตั้งแต่ 1.5.1 ไม่มีเช็คไหนอ่านช่องนี้ repo เดิมจะคงไว้ก็ได้ (schema ยังรับ)
ถ้าจะลบ ต้องทำใน PR ที่ DevOps หรือ PM approve เพราะ CODEOWNERS กำหนดเจ้าของ `subsystem.yaml` ไว้

**ถอยเวอร์ชันได้ไหม**
ไม่ได้ เพื่อกันการถอยไปใช้เวอร์ชันที่ตรวจหลวมกว่า ถ้าเวอร์ชันใหม่มีบั๊กจริง ให้เปิด issue ใน standards ให้ออกเวอร์ชันแก้

**เวอร์ชันที่เลือกได้มีอะไรบ้าง**
ทุก tag ในหน้า Tags ของ `csmju2030-standards` ที่ไม่ต่ำกว่า `MIN_VERSION`
