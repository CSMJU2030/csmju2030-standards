#!/usr/bin/env bash
# scripts/check-field-aliases.sh — DD-01, DD-02
# Usage: check-field-aliases.sh [target_dir]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

# DD-01: alias ที่ห้ามใช้แทน username
FORBIDDEN_ALIASES=(
  'student_id' 'student_code' 'user_id' 'user_code'
  'std_id' 'stdId' 'studentId' 'userId' 'userCode'
)

VIOLATION=0
for ALIAS in "${FORBIDDEN_ALIASES[@]}"; do
  RESULT=$(grep -rn --word-regexp "$ALIAS" \
    frontend/src backend/src prisma/ 2>/dev/null \
    --include='*.ts' --include='*.tsx' --include='*.prisma' \
    --exclude-dir=node_modules || true)
  if [[ -n "$RESULT" ]]; then
    echo "❌ [DD-01] ใช้ชื่อ field ที่ห้ามใช้แทน username: $ALIAS"
    echo "$RESULT" | sed 's/^/   /'
    VIOLATION=1
  fi
done

# DD-02: layer1_role ต้องใช้ค่าจาก enum ที่กำหนดเท่านั้น
# ค่าตาม data-dictionary.md ข้อ 4 และ auth-contract.md ข้อ 11 ซึ่งตรงกัน:
# student | alumni | staff | admin เท่านั้น
#   - "faculty" เคยอยู่ในลิสต์นี้ผิด เพราะสับสนกับ *ฟิลด์* faculty (รหัสคณะ)
#     ที่อยู่ใน JWT ไม่ใช่ค่าของ layer1_role
#   - "guest" เป็น Layer 2 role (ตั้งใน default_role_mapping ของแต่ละระบบ)
#     ไม่ใช่ค่าของ Layer 1
ALLOWED_ROLES="student|alumni|staff|admin"
BAD_ROLES=$(grep -rnE "layer1_role\s*[:=]\s*['\"][a-zA-Z_]+['\"]" \
  frontend/src backend/src 2>/dev/null \
  --include='*.ts' --include='*.tsx' \
  | grep -vE "layer1_role\s*[:=]\s*['\"]($ALLOWED_ROLES)['\"]" || true)
if [[ -n "$BAD_ROLES" ]]; then
  echo "❌ [DD-02] layer1_role ใช้ค่านอก enum ที่กำหนด"
  echo "$BAD_ROLES" | sed 's/^/   /'
  VIOLATION=1
fi

if [[ "$VIOLATION" -eq 1 ]]; then
  cat <<EOF
   อ้างอิง: data-dictionary.md ข้อ 1
   วิธีแก้: เปลี่ยนทุกที่ให้ใช้ username แทน alias ต้องห้าม
            และให้ layer1_role ใช้ค่าจาก enum: $ALLOWED_ROLES เท่านั้น
EOF
  exit 1
fi
echo "✅ [DD-01/02] ไม่พบ forbidden alias หรือค่า layer1_role นอก enum"
