#!/usr/bin/env bash
# scripts/check-api-conventions.sh — API-02, API-03, API-04, API-05, API-06
# Heuristic static checks (no running backend required).
# Usage: check-api-conventions.sh [target_dir]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

VIOLATION=0

# ยิงเฉพาะเมื่อมีไฟล์ .ts จริงใน backend/src — repo ที่ scaffold ใหม่มีแต่
# โฟลเดอร์เปล่า ถ้าเช็คแค่ว่ามีโฟลเดอร์ API-03/API-05 จะตีตกทันทีก่อนที่
# ใครจะได้เขียนโค้ด ซึ่งขัดกับสคริปต์ตัวอื่นที่ยึดหลัก "ไม่มีไฟล์ = ข้าม"
BACKEND_TS=$(find backend/src -name '*.ts' -not -path '*/node_modules/*' 2>/dev/null | head -1)
if [[ -d backend/src && -n "$BACKEND_TS" ]]; then
  # API-02: route segments must be kebab-case (no camelCase / underscores),
  # and a /v1 global prefix must be declared somewhere in main.ts.
  BAD_ROUTES=$(grep -rnE "@(Controller|Get|Post|Put|Patch|Delete)\(['\"][^'\"]*[A-Z_][^'\"]*['\"]" \
    backend/src --include='*.ts' 2>/dev/null || true)
  if [[ -n "$BAD_ROUTES" ]]; then
    echo "❌ [API-02] Route path ไม่ใช่ kebab-case"
    echo "$BAD_ROUTES" | sed 's/^/   /'
    VIOLATION=1
  fi
  # api-conventions.md ข้อ 1 กำหนด URL เป็น /api/<resource> พร้อม prefix /api/v1
  # จึงต้องรับทั้ง setGlobalPrefix('api/v1') และรูปสั้น setGlobalPrefix('v1')
  # และไม่ปิดท้ายที่ ")" เพราะ Nest มักส่ง option ตัวที่สองมาด้วย เช่น
  #   setGlobalPrefix('api/v1', { exclude: ['health'] })
  # ซึ่งจำเป็น เพราะ /health ต้องอยู่นอก prefix ตามข้อ 8
  if [[ -f backend/src/main.ts ]] && ! grep -qE "setGlobalPrefix\(\s*['\"](api/)?v1['\"]" backend/src/main.ts; then
    echo "❌ [API-02] ไม่พบการตั้ง global prefix 'api/v1' (หรือ 'v1') ใน backend/src/main.ts"
    VIOLATION=1
  fi

  # API-03: response envelope { success, data/error, meta }
  ENVELOPE=$(grep -rlE "success\s*:\s*(true|false)" backend/src --include='*.ts' 2>/dev/null || true)
  if [[ -z "$ENVELOPE" ]]; then
    echo "❌ [API-03] ไม่พบ response envelope { success, data/error, meta } ใน backend/src"
    VIOLATION=1
  fi

  # API-04: error.code must be one of the 6 standard values
  ALLOWED_CODES="VALIDATION_ERROR|NOT_FOUND|UNAUTHORIZED|FORBIDDEN|CONFLICT|INTERNAL_ERROR"
  BAD_CODES=$(grep -rnE "code\s*:\s*['\"][A-Z_]+['\"]" backend/src --include='*.ts' 2>/dev/null \
    | grep -vE "code\s*:\s*['\"]($ALLOWED_CODES)['\"]" || true)
  if [[ -n "$BAD_CODES" ]]; then
    echo "❌ [API-04] error.code ไม่อยู่ในรายการมาตรฐาน 6 ค่า ($ALLOWED_CODES)"
    echo "$BAD_CODES" | sed 's/^/   /'
    VIOLATION=1
  fi

  # API-05: GET /health endpoint must exist
  if ! grep -rqE "@Get\(['\"]health['\"]\)" backend/src --include='*.ts' 2>/dev/null; then
    echo "❌ [API-05] ไม่พบ endpoint GET /health"
    VIOLATION=1
  fi
fi

# API-06 (Warn only): public_endpoints declared in subsystem.yaml
if [[ -f subsystem.yaml ]] && ! grep -q "^public_endpoints:" subsystem.yaml; then
  echo "⚠️  [API-06] ไม่พบการประกาศ public_endpoints ใน subsystem.yaml"
fi

if [[ "$VIOLATION" -eq 1 ]]; then
  cat <<EOF
   อ้างอิง: api-conventions.md ข้อ 1, 3, 4, 8
   วิธีแก้: ปรับ route ให้เป็น kebab-case พหูพจน์ใต้ /api/v1/, ห่อ response ด้วย envelope มาตรฐาน,
            ใช้ error.code จากรายการที่กำหนด, และเพิ่ม endpoint GET /health
EOF
  exit 1
fi
echo "✅ [API-02..06] ผ่านการตรวจ API conventions"
