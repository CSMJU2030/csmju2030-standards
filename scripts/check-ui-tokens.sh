#!/usr/bin/env bash
# scripts/check-ui-tokens.sh — UI-01 (fail), UI-02/03/04 (warn)
# Usage: check-ui-tokens.sh [target_dir]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

VIOLATION=0

# UI-01 (Fail): raw hex color
RESULT=$(grep -rnE '#[0-9a-fA-F]{3,8}\b' frontend/src \
  --include='*.tsx' --include='*.ts' --include='*.css' \
  --exclude='*.config.*' --exclude-dir=node_modules 2>/dev/null || true)
if [[ -n "$RESULT" ]]; then
  cat <<EOF
❌ [UI-01] พบค่าสี hex ดิบในโค้ด frontend
$(echo "$RESULT" | sed 's/^/   /')
   อ้างอิง: ui-prompt-template.md ข้อ 1
   วิธีแก้: ใช้ CSS variable --csmju-* หรือ utility class
            จาก tailwind preset ของโครงการแทน
EOF
  VIOLATION=1
fi

# UI-02 (Warn): spacing/radius values outside the design scale
SPACING=$(grep -rnE "(margin|padding|border-radius|gap)\s*:\s*[0-9]+px" frontend/src \
  --include='*.tsx' --include='*.ts' --include='*.css' \
  --exclude-dir=node_modules 2>/dev/null || true)
if [[ -n "$SPACING" ]]; then
  echo "⚠️  [UI-02] พบค่า spacing/radius แบบ px ดิบ นอก scale ที่กำหนด"
  echo "$SPACING" | sed 's/^/   /'
fi

# UI-03 (Warn): div onClick / outline:none / !important
UI03=$(grep -rnE "(<div[^>]*onClick=|outline:\s*none|!important)" frontend/src \
  --include='*.tsx' --include='*.ts' --include='*.css' \
  --exclude-dir=node_modules 2>/dev/null || true)
if [[ -n "$UI03" ]]; then
  echo "⚠️  [UI-03] พบ div onClick / outline:none / !important"
  echo "$UI03" | sed 's/^/   /'
fi

# UI-04 (Warn): emoji in screens
UI04=$(grep -rnP "[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]" frontend/src \
  --include='*.tsx' --exclude-dir=node_modules 2>/dev/null || true)
if [[ -n "$UI04" ]]; then
  echo "⚠️  [UI-04] พบ emoji ในหน้าจอระบบ"
  echo "$UI04" | sed 's/^/   /'
fi

if [[ "$VIOLATION" -eq 1 ]]; then
  exit 1
fi
echo "✅ [UI-01] ไม่พบ hex color ดิบ (UI-02..04 เป็น warn เท่านั้น)"
