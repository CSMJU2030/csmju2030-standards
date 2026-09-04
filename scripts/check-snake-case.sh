#!/usr/bin/env bash
# scripts/check-snake-case.sh — DD-03
# Heuristic: flags camelCase field names declared in DTO/Entity/Response
# type files under backend/src — API response fields must be snake_case.
# Usage: check-snake-case.sh [target_dir]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

FILES=$(find backend/src -type f \( -iname '*dto*.ts' -o -iname '*entity*.ts' -o -iname '*response*.ts' \) \
  -not -path '*/node_modules/*' 2>/dev/null || true)

VIOLATION=0
for f in $FILES; do
  RESULT=$(grep -nE '^\s*[a-z][a-zA-Z0-9]*[A-Z][a-zA-Z0-9]*\s*[?]?\s*:' "$f" 2>/dev/null || true)
  if [[ -n "$RESULT" ]]; then
    echo "❌ [DD-03] พบ field ชื่อ camelCase (ต้องเป็น snake_case) ใน $f"
    echo "$RESULT" | sed 's/^/   /'
    VIOLATION=1
  fi
done

if [[ "$VIOLATION" -eq 1 ]]; then
  cat <<EOF
   อ้างอิง: api-conventions.md ข้อ 6
   วิธีแก้: เปลี่ยนชื่อ field ทั้งหมดใน DTO/Entity/Response ให้เป็น snake_case
EOF
  exit 1
fi
echo "✅ [DD-03] Field ทั้งหมดเป็น snake_case"
