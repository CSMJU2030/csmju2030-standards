#!/usr/bin/env bash
# scripts/check-dependency-audit.sh — SEC-06
# Production dependencies (pnpm audit --prod) carry no high or critical
# advisory. Reads pnpm-lock.yaml only, so it needs no `pnpm install`, but it
# asks the npm registry, so it needs the network.
#
# SEC-06 is ⚠️ Warn since 1.9.0: it prints every high/critical advisory (and a
# ::warning annotation in GitHub Actions) but never blocks the merge. PL
# decides the version in which it becomes ❌ Fail (ci-compliance-spec.md 7.1)
# — that change is LEVEL=fail below.
#
# - no pnpm-lock.yaml → skip: a repo fresh from new-subsystem.sh
# - no pnpm or node   → skip: CI runs it in Code Quality, which has both
# - the registry cannot be reached → warn and pass: an npm outage must not
#   block every PR in the organisation
#
# CSMJU_AUDIT_REPORT=<file> reads a saved `pnpm audit --prod --json` instead of
# asking the registry (self-test uses it to stay offline).
#
# Usage: check-dependency-audit.sh [target_dir]
set -uo pipefail

LEVEL=warn

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"
REPORT="${CSMJU_AUDIT_REPORT:-}"
# resolve before cd: a relative path would then point inside the target
if [[ -n "$REPORT" && "$REPORT" != /* ]]; then
  REPORT="$PWD/$REPORT"
fi
cd "$TARGET_DIR" || exit 1

if [[ ! -f pnpm-lock.yaml ]]; then
  echo "✅ [SEC-06] ข้ามการตรวจ (ไม่พบ pnpm-lock.yaml — repo เพิ่ง scaffold)"
  exit 0
fi
if ! command -v node >/dev/null 2>&1; then
  echo "⚠️  [SEC-06] ข้ามการตรวจ (ไม่พบ node)"
  exit 0
fi

CLEANUP=""
if [[ -z "$REPORT" ]]; then
  if ! command -v pnpm >/dev/null 2>&1; then
    echo "⚠️  [SEC-06] ข้ามการตรวจ (ไม่พบ pnpm — ใน CI ตรวจที่ job Code Quality)"
    exit 0
  fi
  REPORT="$(mktemp)"
  CLEANUP="$REPORT"
  # pnpm audit exits 1 whenever it finds anything, so its exit code says
  # nothing here; audit-report.js reads the JSON and decides.
  pnpm audit --prod --json > "$REPORT" 2>/dev/null
fi

node "$SCRIPT_DIR/lib/audit-report.js" "$REPORT"
CODE=$?
[[ -n "$CLEANUP" ]] && rm -f "$CLEANUP"

case "$CODE" in
  0)
    echo "✅ [SEC-06] ไม่มี dependency ใน production ที่มีช่องโหว่ระดับ high/critical"
    exit 0
    ;;
  2)
    echo "⚠️  [SEC-06] ตรวจไม่ได้ — อ่านผล pnpm audit ไม่ได้ (ต่อ npm registry ไม่ได้?) · ลองรัน pnpm audit --prod เอง"
    exit 0
    ;;
esac

cat <<'EOF'
   อ้างอิง: github-workflow.md ข้อ 2.1
   วิธีแก้: pnpm up <แพ็กเกจ> ถ้าเป็น dependency ตรง · ถ้าเป็น dependency ทางอ้อม
            ให้อัปเดตตัวที่ดึงมันเข้ามา หรือเพิ่ม overrides ใน pnpm-workspace.yaml
            เช่น  multer: '>=2.4.0'  แล้ว pnpm install · ตรวจด้วย pnpm why <แพ็กเกจ>
EOF
if [[ "$LEVEL" == "fail" ]]; then
  echo "❌ [SEC-06] มี dependency ใน production ที่มีช่องโหว่ระดับ high/critical"
  exit 1
fi
echo "⚠️  [SEC-06] ระดับ Warn — ยัง merge ได้ แต่ควรแก้ก่อนขึ้น server (จะเป็น Fail ในเวอร์ชันถัดไปตามที่ PL ประกาศ)"
exit 0
