#!/usr/bin/env bash
# scripts/check-submodule-pointer.sh — GH-04
# Simplified for this demo: instead of a real git submodule pointer, a
# subsystem repo declares the standards version it was built against in a
# plain file `.standards-version` at its root. This script checks that
# value against the standards repo's own VERSION file.
#
# Usage: check-submodule-pointer.sh [target_dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STANDARDS_VERSION_FILE="$SCRIPT_DIR/../VERSION"

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

if [[ ! -f "$STANDARDS_VERSION_FILE" ]]; then
  echo "✅ [GH-04] ข้ามการตรวจ (ไม่พบ VERSION ของ standards repo)"
  exit 0
fi
EXPECTED="$(tr -d '[:space:]' < "$STANDARDS_VERSION_FILE")"

if [[ ! -f ".standards-version" ]]; then
  cat <<EOF
❌ [GH-04] ไม่พบไฟล์ .standards-version ใน subsystem repo
   ต้องเป็น: มีไฟล์ .standards-version ระบุ semver ที่ตรงกับ standards repo ($EXPECTED)
   อ้างอิง: github-workflow.md ข้อ 3.6
   วิธีแก้: git submodule update --remote standards/ แล้วสร้างไฟล์ .standards-version = $EXPECTED
EOF
  exit 1
fi

FOUND="$(tr -d '[:space:]' < ".standards-version")"
if [[ "$FOUND" != "$EXPECTED" ]]; then
  cat <<EOF
❌ [GH-04] standards version ที่ subsystem ใช้ไม่ตรงกับที่ PM อนุมัติ
   พบ: $FOUND
   ต้องเป็น: $EXPECTED
   อ้างอิง: github-workflow.md ข้อ 3.6
   วิธีแก้: git submodule update --remote standards/ แล้วอัปเดต .standards-version เป็น $EXPECTED
EOF
  exit 1
fi
echo "✅ [GH-04] standards version ตรงกัน: $FOUND"
