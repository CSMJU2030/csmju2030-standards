#!/usr/bin/env bash
# scripts/check-no-jwt-verify.sh — SEC-04, SEC-05
# Usage: check-no-jwt-verify.sh [target_dir]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

VIOLATION=0

# SEC-04: no self-rolled JWT signature verification
JWT_RESULT=$(grep -rnE "(jwt\.verify\(|jsonwebtoken|require\(['\"]jose['\"]\)|from ['\"]jose['\"]|passport-jwt)" \
  backend 2>/dev/null \
  --include='*.ts' --include='*.js' \
  --exclude-dir=node_modules --exclude-dir=dist || true)
if [[ -n "$JWT_RESULT" ]]; then
  echo "❌ [SEC-04] พบโค้ด verify JWT signature เองใน subsystem"
  echo "$JWT_RESULT" | sed 's/^/   /'
  VIOLATION=1
fi

# SEC-05: no self-rolled login page / username-password form
LOGIN_RESULT=$(grep -rniE "(type=[\"']password[\"']|<form[^>]*login)" \
  frontend 2>/dev/null \
  --include='*.tsx' --include='*.jsx' \
  --exclude-dir=node_modules --exclude-dir=.next || true)
if [[ -n "$LOGIN_RESULT" ]]; then
  echo "❌ [SEC-05] พบหน้า login / form username-password ในระบบย่อย"
  echo "$LOGIN_RESULT" | sed 's/^/   /'
  VIOLATION=1
fi

if [[ "$VIOLATION" -eq 1 ]]; then
  cat <<EOF
   อ้างอิง: auth-contract.md ข้อ 1, 3
   วิธีแก้: ใช้ session/identity จาก gateway กลาง (CSMJU_LOGIN_URL) แทนการ implement เอง
EOF
  exit 1
fi
echo "✅ [SEC-04/05] ไม่พบ JWT verify หรือ login form ที่ implement เอง"
