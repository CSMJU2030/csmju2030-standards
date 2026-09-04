#!/usr/bin/env bash
# scripts/check-branch-name.sh — GH-01
# Usage: check-branch-name.sh [target_dir] [branch_name_override]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

BRANCH="${2:-${GITHUB_HEAD_REF:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)}}"
PATTERN='^feature/[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$'

if [[ ! "$BRANCH" =~ $PATTERN ]]; then
  cat <<EOF
❌ [GH-01] ชื่อ branch ไม่ตรงมาตรฐาน
   พบ: $BRANCH
   ต้องเป็น: feature/<subsystem>/<เรื่องที่ทำ>
   ตัวอย่าง: feature/equipment/add-borrow-return
   อ้างอิง: github-workflow.md ข้อ 1.1
   วิธีแก้: git branch -m feature/<subsystem>/<เรื่อง>
EOF
  exit 1
fi
echo "✅ [GH-01] Branch name ผ่าน: $BRANCH"
