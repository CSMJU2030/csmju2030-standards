# Logging

**เวอร์ชัน 1.0** · บังคับกับทุกระบบย่อย

ระบบย่อยต้อง log เหตุการณ์ด้านการยืนยันตัวตนและสิทธิ์เป็น **structured log** (JSON บรรทัดเดียว)
เพื่อให้ตรวจสอบย้อนหลังและหาสาเหตุร่วมกันได้ทุกระบบ

ชื่อ event ที่ใช้ได้เป็นรายการปิด อยู่ใน [`../contracts/log-events.json`](../contracts/log-events.json)

---

## 1. Event ที่ต้องมี

| event | เมื่อไร | field ที่ต้องมี |
|---|---|---|
| `subsystem.started` | ตอนบูต | `subsystem`, `port`, `coreHubUrl`, `jwksUrl`, `issuer`, `audience` |
| `jwks.refresh` | ดึง JWKS สำเร็จ | `reason`, `keyCount`, `kids` |
| `jwks.refresh.failure` | ดึง JWKS ไม่สำเร็จ | `reason`, `cachedKeyCount` |
| `jwks.unknown_kid` | `kid` ไม่อยู่ในชุดที่แคชไว้ | `kid`, `knownKids` |
| `jwt.verification.success` | ตรวจ token ผ่าน | `sub`, `coreRole`, `subsystemRole` |
| `jwt.verification.failure` | ตรวจ token ไม่ผ่าน | `reason`, `kid`, `path` |
| `authorization.role_mapping_failed` | core role ที่แมปไม่ได้ | `sub`, `coreRole` |
| `authorization.denied` | สิทธิ์ไม่พอ | `sub`, `subsystemRole`, `required`, `reason`, `path` |

ตัวอย่าง:

```json
{"event":"jwt.verification.failure","reason":"expired","kid":"core-hub-2026","path":"/api/v1/me","at":"2026-09-11T05:00:00.000Z"}
```

## 2. `reason` ที่ใช้ได้ (รายการปิด)

```text
missing_token · malformed_token · unsupported_algorithm · missing_kid · unknown_kid
jwks_unavailable · invalid_signature · expired · invalid_issuer · invalid_audience · invalid_claims
```

## 3. ห้าม log เด็ดขาด

```text
access token · refresh token · Authorization header · รหัสผ่าน · กุญแจส่วนตัว
```

ถ้าต้องอ้างถึง token ให้ log เฉพาะ `kid` และ `sub` เท่านั้น

## 4. ตรวจอย่างไร

```bash
# ยิงทั้งเคสสำเร็จและเคสล้มเหลว แล้วค้นใน log ต้องไม่พบสตริงที่ขึ้นต้นด้วย eyJ
docker compose logs backend | grep -iE "eyJ|authorization:" | head
```
