#!/usr/bin/env bash
# scripts/check-authorized-deps.sh — ARC-02, ARC-03
#
# `dependencies` (runtime) and `devDependencies` (build tooling) are checked
# against different lists on purpose. tech-stack.md ข้อ 1 is an architectural
# rule — which framework, which UI kit, which DB client ships to production —
# and that is what `allowed_frontend`/`allowed_backend` encode. A type stub or
# an eslint parser is not an architectural choice, and holding devDependencies
# to the runtime list made QA-01..04 impossible to satisfy: a Next app cannot
# typecheck without @types/react, TypeScript cannot be linted without a TS
# parser, and a Nest app cannot build without @nestjs/cli.
#
# `forbidden_everywhere` still applies to both — a banned UI kit hidden in
# devDependencies is still banned.
#
# Usage: check-authorized-deps.sh [target_dir]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLOWED_DEPS="$SCRIPT_DIR/lib/allowed-deps.json"

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

if ! command -v jq >/dev/null 2>&1; then
  echo "✅ [ARC-02/03] ข้ามการตรวจ (ไม่พบ jq ในเครื่อง)"
  exit 0
fi

VIOLATION=0

is_forbidden() {
  [[ "$(jq --arg d "$1" '.forbidden_everywhere | index($d) != null' "$ALLOWED_DEPS")" == "true" ]]
}
in_list() {
  [[ "$(jq --arg d "$1" --arg k "$2" '.[$k] | index($d) != null' "$ALLOWED_DEPS")" == "true" ]]
}
matches_dev_pattern() {
  [[ "$(jq -r --arg d "$1" '[.dev_tooling_patterns[] | select($d | test(.))] | length > 0' "$ALLOWED_DEPS")" == "true" ]]
}

report_forbidden() {
  cat <<EOF
❌ [ARC-03] Dependency ต้องห้ามใน $2
   พบ: $1
   อ้างอิง: tech-stack.md ข้อ 1 / ci-compliance-spec.md §7.3
   วิธีแก้: ลบ dependency นี้ออก และใช้ทางเลือกที่อยู่ใน whitelist ของ stack แทน
EOF
}

check_section() {
  local pkg="$1" section="$2" allowed_key="$3" kind="$4"
  local deps
  deps=$(jq -r --arg s "$section" '(.[$s] // {}) | keys[]' "$pkg" 2>/dev/null || true)

  while IFS= read -r DEP; do
    [[ -z "$DEP" ]] && continue

    if is_forbidden "$DEP"; then
      report_forbidden "$DEP" "$pkg"
      VIOLATION=1
      continue
    fi

    if in_list "$DEP" "$allowed_key"; then
      continue
    fi
    # devDependencies ผ่านได้อีกทางถ้าเป็น build tooling หรือ type stub
    if [[ "$kind" == "dev" ]] \
      && { in_list "$DEP" "allowed_dev_tooling" || matches_dev_pattern "$DEP"; }; then
      continue
    fi

    cat <<EOF
❌ [ARC-02] Dependency ไม่อยู่ใน whitelist ของ stack ใน $pkg ($section)
   พบ: $DEP
   อ้างอิง: tech-stack.md ข้อ 1
   วิธีแก้: เปิด issue ขอ DevOps เพิ่มเข้า whitelist หรือใช้ dependency ที่อนุมัติแล้วแทน
            devDependencies ที่เป็นเครื่องมือ build/lint/test เพิ่มที่ allowed_dev_tooling
EOF
    VIOLATION=1
  done <<< "$deps"
}

check_side() {
  local side_dir="$1" allowed_key="$2"
  local pkg="$side_dir/package.json"
  [[ -f "$pkg" ]] || return 0
  check_section "$pkg" "dependencies"    "$allowed_key" "runtime"
  check_section "$pkg" "devDependencies" "$allowed_key" "dev"
}

check_side "frontend" "allowed_frontend"
check_side "backend"  "allowed_backend"

if [[ "$VIOLATION" -eq 1 ]]; then
  exit 1
fi
echo "✅ [ARC-02/03] Dependency ทั้งหมดอยู่ใน whitelist"
