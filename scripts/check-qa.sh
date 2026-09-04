#!/usr/bin/env bash
# scripts/check-qa.sh — QA-01..05
# QA-05 (package manager) is checked unconditionally — it's a plain file
# check. QA-01..04 (lint/typecheck/test/build) need a real toolchain
# installed; if `pnpm`/`node_modules` aren't present they are reported as
# skipped rather than failing this demo scaffold.
#
# Usage: check-qa.sh [target_dir]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

VIOLATION=0

# QA-05: pnpm workspace only, no package-lock.json / yarn.lock
LOCKFILES=$(find . -maxdepth 3 \( -name 'package-lock.json' -o -name 'yarn.lock' \) \
  -not -path '*/node_modules/*' -not -path './.compliance-tools/*' 2>/dev/null || true)
if [[ -n "$LOCKFILES" ]]; then
  cat <<EOF
❌ [QA-05] พบ lockfile ที่ไม่ใช่ pnpm
$(echo "$LOCKFILES" | sed 's/^/   /')
   อ้างอิง: github-workflow.md ข้อ 2
   วิธีแก้: ลบ lockfile ดังกล่าว แล้วใช้ pnpm-lock.yaml เท่านั้น
EOF
  VIOLATION=1
fi
if [[ ! -f pnpm-workspace.yaml ]]; then
  echo "⚠️  [QA-05] ไม่พบ pnpm-workspace.yaml ที่ root"
fi

# QA-01..04: best-effort — only run if pnpm + installed deps are present
if command -v pnpm >/dev/null 2>&1 && [[ -d node_modules ]]; then
  if ! pnpm -r lint; then
    echo "❌ [QA-01] ESLint/Prettier ไม่ผ่าน"
    VIOLATION=1
  fi
  if ! pnpm -r typecheck; then
    echo "❌ [QA-02] tsc --noEmit ไม่ผ่าน"
    VIOLATION=1
  fi
  if ! pnpm -r test; then
    echo "❌ [QA-03] Unit test ไม่ผ่าน"
    VIOLATION=1
  fi
  if ! pnpm -r build; then
    echo "❌ [QA-04] next build / nest build ไม่ผ่าน"
    VIOLATION=1
  fi
else
  echo "⚠️  [QA-01..04] ข้ามการตรวจ (ไม่พบ pnpm หรือยังไม่ pnpm install — ต้องรันจริงใน CI)"
fi

if [[ "$VIOLATION" -eq 1 ]]; then
  exit 1
fi
echo "✅ [QA-05] ผ่านการตรวจ package manager"
