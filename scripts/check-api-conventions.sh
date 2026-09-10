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
  # ชื่อ path parameter (:exceptionId) เป็นตัวแปรใน TypeScript ไม่ใช่ส่วนของ URL
  # จริง — NestJS ใช้ camelCase ตามปกติ จึงตัด :param ออกก่อนตรวจ kebab-case
  ROUTE_HITS=$(grep -rnE "@(Controller|Get|Post|Put|Patch|Delete)\(\s*['\"][^'\"]*['\"]" \
    backend/src --include='*.ts' 2>/dev/null || true)
  BAD_ROUTES=""
  while IFS= read -r LINE; do
    [[ -z "$LINE" ]] && continue
    PATH_LITERAL=$(echo "$LINE" \
      | sed -E "s/.*@(Controller|Get|Post|Put|Patch|Delete)\(\s*['\"]([^'\"]*)['\"].*/\2/")
    STRIPPED=$(echo "$PATH_LITERAL" | sed -E 's/:[A-Za-z0-9_]+//g')
    if echo "$STRIPPED" | grep -qE '[A-Z_]'; then
      BAD_ROUTES="${BAD_ROUTES}${LINE}
"
    fi
  done <<< "$ROUTE_HITS"
  if [[ -n "$BAD_ROUTES" ]]; then
    echo "❌ [API-02] Route path ไม่ใช่ kebab-case"
    echo "$BAD_ROUTES" | sed 's/^/   /'
    VIOLATION=1
  fi
  # api-conventions.md ข้อ 1: endpoint ธุรกิจอยู่ใต้ /api/v1 ส่วน /api/health และ
  # /auth/callback อยู่นอก v1 จึงรับได้ 3 รูปแบบ
  #   setGlobalPrefix('api/v1', ...)          เวอร์ชันอยู่ใน prefix
  #   setGlobalPrefix('api', ...) + @Controller('v1/...')   เวอร์ชันอยู่ใน controller
  #   setGlobalPrefix('api', ...) + enableVersioning(...)   เวอร์ชันแบบ Nest
  if [[ -f backend/src/main.ts ]]; then
    HAS_PREFIX=$(grep -cE "setGlobalPrefix\(\s*['\"](api(/v1)?|v1)['\"]" backend/src/main.ts || true)
    HAS_V1=$(grep -rlE "setGlobalPrefix\(\s*['\"]api/v1['\"]|enableVersioning\(|@Controller\(\s*['\"]v1/" \
      backend/src --include='*.ts' 2>/dev/null || true)
    if [[ "$HAS_PREFIX" -eq 0 ]]; then
      echo "❌ [API-02] ไม่พบการตั้ง global prefix 'api' หรือ 'api/v1' ใน backend/src/main.ts"
      VIOLATION=1
    elif [[ -z "$HAS_V1" ]]; then
      echo "❌ [API-02] ไม่พบเวอร์ชัน v1 — endpoint ธุรกิจต้องอยู่ใต้ /api/v1"
      VIOLATION=1
    fi
  fi

  # API-03: response envelope { success, data/error, meta }
  ENVELOPE=$(grep -rlE "success\s*:\s*(true|false)" backend/src --include='*.ts' 2>/dev/null || true)
  if [[ -z "$ENVELOPE" ]]; then
    echo "❌ [API-03] ไม่พบ response envelope { success, data/error, meta } ใน backend/src"
    VIOLATION=1
  fi

  # API-04: error.code must be one of the 6 standard values
  ALLOWED_CODES="BAD_REQUEST|VALIDATION_ERROR|NOT_FOUND|UNAUTHORIZED|FORBIDDEN|CONFLICT|INTERNAL_ERROR"
  BAD_CODES=$(grep -rnE "code\s*:\s*['\"][A-Z_]+['\"]" backend/src --include='*.ts' 2>/dev/null \
    | grep -vE "code\s*:\s*['\"]($ALLOWED_CODES)['\"]" || true)
  if [[ -n "$BAD_CODES" ]]; then
    echo "❌ [API-04] error.code ไม่อยู่ในรายการมาตรฐาน 7 ค่า ($ALLOWED_CODES)"
    echo "$BAD_CODES" | sed 's/^/   /'
    VIOLATION=1
  fi

  # API-05: ต้องมี GET /api/health (public) — รับทั้ง @Get('health')
  # และ @Controller('health') + @Get()
  if ! grep -rqE "@Get\(\s*['\"]health['\"]\s*\)|@Controller\(\s*['\"]health['\"]|@Controller\(\s*\{[^}]*path:\s*['\"]health['\"]" \
    backend/src --include='*.ts' 2>/dev/null; then
    echo "❌ [API-05] ไม่พบ endpoint GET /api/health"
    VIOLATION=1
  fi

  # API-07: pagination ต้องใช้ page/limit ไม่ใช่ per_page (api-conventions.md ข้อ 5)
  PER_PAGE=$(grep -rnE "\bper_page\b|\bperPage\b" backend/src --include='*.ts' \
    --exclude-dir=node_modules 2>/dev/null || true)
  if [[ -n "$PER_PAGE" ]]; then
    echo "❌ [API-07] pagination ต้องใช้ ?page= และ ?limit= ไม่ใช่ per_page/perPage"
    echo "$PER_PAGE" | sed 's/^/   /'
    VIOLATION=1
  fi
fi

# API-06 (Warn only): public_endpoints declared in subsystem.yaml
if [[ -f subsystem.yaml ]] && ! grep -q "^public_endpoints:" subsystem.yaml; then
  echo "⚠️  [API-06] ไม่พบการประกาศ public_endpoints ใน subsystem.yaml"
fi

if [[ "$VIOLATION" -eq 1 ]]; then
  cat <<EOF
   อ้างอิง: api-conventions.md ข้อ 1, 2, 3, 4, 5, 8
   วิธีแก้: ปรับ route ให้เป็น kebab-case พหูพจน์ใต้ /api/v1/, ห่อ response ด้วย envelope มาตรฐาน,
            ใช้ error.code จากรายการ 7 ค่า, ใช้ page/limit สำหรับ pagination
            และเพิ่ม endpoint GET /api/health
EOF
  exit 1
fi
echo "✅ [API-02..07] ผ่านการตรวจ API conventions"
