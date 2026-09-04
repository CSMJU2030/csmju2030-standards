# ruleset-standards-repo.repo.json

ป้องกัน `main` ของ `csmju2030-standards` เอง ใช้คนละชุดกับ subsystem repo
ด้วยเหตุผลสองข้อ

**ไม่มี `required_status_checks`** — `self-test.yml` ตั้ง `paths:` ไว้เฉพาะ
`scripts/**` และ `__fixtures__/**` PR ที่แก้แค่ `docs/` จึงไม่ trigger เลย
ถ้าใส่ `Run fixture self-test` เป็น required check PR แบบนั้นจะค้างสถานะ
"expected — waiting for status" ตลอดกาล ไม่มีอะไรมารายงานให้

ทางเลือกถ้าต้องการบังคับจริง: ถอด `paths:` ออกจาก `self-test.yml` ให้ยิงทุก PR
ก่อน แล้วค่อยเพิ่ม `{ "context": "Run fixture self-test" }` เข้ามา

**`bypass_mode` เป็น `always` ไม่ใช่ `pull_request`** — ระหว่างช่วง bootstrap
org มีสมาชิกคนเดียวและยังไม่มี team ถ้าตั้งเป็น `pull_request` เจ้าของ org จะ
push ตรงเข้า main ไม่ได้เลย ซึ่งจำเป็นอยู่ตอนตั้งระบบ ทุกคนที่ไม่ใช่ org admin
ยังต้องผ่าน PR ตามปกติ

**เมื่อมีสมาชิกจริงแล้วควรรัดเป็น `pull_request`** เพื่อให้ main แก้ได้ผ่าน PR
เท่านั้น ไม่มีข้อยกเว้น
