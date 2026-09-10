#!/usr/bin/env bash
# scripts/self-test.sh
# Runs every check script against small pass/fail fixtures and asserts the
# exit code is what's expected (0 for pass, 1 for fail). This is the main
# way to verify the whole compliance-check system actually works, without
# needing a real subsystem repo or GitHub Actions.
#
# Usage: self-test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/../__fixtures__"

TOTAL=0
FAILED=0

assert_exit() {
  local label="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  ✅ PASS  $label (exit=$actual, expected=$expected)"
  else
    echo "  ❌ FAIL  $label (exit=$actual, expected=$expected)"
    FAILED=$((FAILED + 1))
  fi
}

# --- Generic fixture-based checks: __fixtures__/<name>/{pass,fail} -------
run_fixture_case() {
  local name="$1" script="$2"
  local pass_dir="$FIXTURES_DIR/$name/pass"
  local fail_dir="$FIXTURES_DIR/$name/fail"

  if [[ -d "$pass_dir" ]]; then
    "$SCRIPT_DIR/$script" "$pass_dir" >/dev/null 2>&1
    assert_exit "$name pass-fixture ($script)" 0 "$?"
  fi
  if [[ -d "$fail_dir" ]]; then
    "$SCRIPT_DIR/$script" "$fail_dir" >/dev/null 2>&1
    assert_exit "$name fail-fixture ($script)" 1 "$?"
  fi
}

echo "== Fixture-based checks =="
run_fixture_case "SEC-01"    "check-no-secrets.sh"
run_fixture_case "SEC-03"    "check-no-local-storage.sh"
run_fixture_case "ARC-01"    "check-db-isolation.sh"
run_fixture_case "ARC-02-03" "check-authorized-deps.sh"
# ARC-02-DEV: devDependencies are held to allowed_dev_tooling + @types/*,
# but forbidden_everywhere still applies there and dev tooling is still
# rejected as a runtime dependency.
run_fixture_case "ARC-02-DEV" "check-authorized-deps.sh"
run_fixture_case "DD-01"     "check-field-aliases.sh"
# DD-02 is a regression case: the enum was copied wrong as
# student|staff|faculty|admin|guest, which rejected the real value
# "alumni" and accepted "faculty" — a field name, not a role.
run_fixture_case "DD-02"     "check-field-aliases.sh"
# DD-04/DD-05 fixtures are regression cases: both shapes below used to
# slip through (a SCREAMING_CASE faculty const, and a money field with a
# type annotation or a prisma Float column).
echo ""
echo "== DD-03: database naming (prisma @map) =="
run_fixture_case "DD-03"     "check-snake-case.sh"

echo ""
echo "== SEC-04: JWT verification ตามสัญญา =="
run_fixture_case "SEC-04"    "check-no-jwt-verify.sh"

run_fixture_case "DD-04"     "check-no-hardcoded-faculty.sh"
run_fixture_case "DD-05"     "check-money-fields.sh"
# API-02 is a regression case: the prefix check demanded exactly
# setGlobalPrefix('v1'), so following api-conventions.md ข้อ 1
# (/api/v1, with /health excluded) failed CI. pass/fail differ only
# in main.ts.
run_fixture_case "API-02"   "check-api-conventions.sh"
# API-02-EMPTY: a freshly scaffolded repo has backend/src but no .ts
# files yet. Gating on the directory alone made API-03/API-05 fail
# before anyone could write code. pass-only fixture.
run_fixture_case "API-02-EMPTY" "check-api-conventions.sh"
run_fixture_case "UI-01"     "check-ui-tokens.sh"
run_fixture_case "QA-05"     "check-qa.sh"
run_fixture_case "EXC-01"    "check-exceptions.sh"

# --- GH-01: branch naming (no fixture dir needed, branch passed as arg) --
echo
echo "== GH-01: branch naming =="
"$SCRIPT_DIR/check-branch-name.sh" . "feature/equipment/add-borrow-return" >/dev/null 2>&1
assert_exit "GH-01 pass (valid branch name)" 0 "$?"
"$SCRIPT_DIR/check-branch-name.sh" . "bugfix-thing" >/dev/null 2>&1
assert_exit "GH-01 fail (invalid branch name)" 1 "$?"

# --- GH-02: commit messages (needs a real git repo, built on the fly) ----
echo
echo "== GH-02: commit messages =="
setup_and_run_gh02() {
  local variant="$1"
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    echo "# readme" > README.md
    git add -A
    git commit -qm "chore: base"
  ) >/dev/null 2>&1

  local base_sha
  base_sha="$(cd "$dir" && git rev-parse HEAD)"

  case "$variant" in
    pass)
      (cd "$dir" && echo a >> README.md && git add -A && git commit -qm "feat(equipment): add borrow flow") >/dev/null 2>&1
      ;;
    fail)
      (cd "$dir" && echo a >> README.md && git add -A && git commit -qm "updated some stuff") >/dev/null 2>&1
      ;;
    merge)
      # Reproduces a pull_request checkout: a synthetic merge commit on top of
      # a valid Conventional Commit. The merge subject must be ignored.
      (
        cd "$dir"
        git switch -qc topic
        echo a >> README.md && git add -A && git commit -qm "fix(api): correct envelope"
        git switch -q master 2>/dev/null || git switch -q main
        echo b >> OTHER.md && git add -A && git commit -qm "chore: unrelated"
        git merge -q --no-ff topic -m "Merge topic into master"
      ) >/dev/null 2>&1
      ;;
  esac

  "$SCRIPT_DIR/check-commit-messages.sh" "$dir" "$base_sha" >/dev/null 2>&1
  local code=$?
  rm -rf "$dir"
  return $code
}
setup_and_run_gh02 "pass"
assert_exit "GH-02 pass (conventional commit)" 0 "$?"
setup_and_run_gh02 "fail"
assert_exit "GH-02 fail (non-conventional commit)" 1 "$?"
setup_and_run_gh02 "merge"
assert_exit "GH-02 pass (synthetic merge commit ignored)" 0 "$?"

# --- GH-03: CI file guard (needs a real git repo, built on the fly) ------
echo
echo "== GH-03: CI file guard =="
setup_and_run_gh03() {
  local variant="$1"
  local dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    mkdir -p .github/workflows
    echo "# readme" > README.md
    echo "name: CI" > .github/workflows/ci.yml
    git add -A
    git commit -qm "chore: base"
  ) >/dev/null 2>&1

  local base_sha
  base_sha="$(cd "$dir" && git rev-parse HEAD)"

  if [[ "$variant" == "pass" ]]; then
    (cd "$dir" && echo "more text" >> README.md && git add -A && git commit -qm "docs: update readme") >/dev/null 2>&1
  else
    (cd "$dir" && echo "name: CI modified" > .github/workflows/ci.yml && git add -A && git commit -qm "ci: sneak change") >/dev/null 2>&1
  fi

  "$SCRIPT_DIR/check-ci-untouched.sh" "$dir" "$base_sha" >/dev/null 2>&1
  local code=$?
  rm -rf "$dir"
  return $code
}
setup_and_run_gh03 "pass"
assert_exit "GH-03 pass (only README changed)" 0 "$?"
setup_and_run_gh03 "fail"
assert_exit "GH-03 fail (workflow file changed)" 1 "$?"

echo ""
echo "== QA-06: workspace filter ต้องชี้ถูก =="
# ชื่อ package ซ้ำ / --filter ชี้ผิด ทำให้ pnpm ไม่รันอะไรเลยแต่คืน exit 0
run_fixture_case "QA-06"     "check-qa.sh"

echo ""
echo "== Profile: core-hub (docs/core-hub-rules.md) =="
# fixture เดียวกัน ต้องให้ผลตรงข้ามกันตาม CSMJU_PROFILE — ถ้า profile หลุด
# ระบบย่อยจะแอบใช้ passport-jwt/user_id ได้ทันที จึงต้องยืนยันทั้งสองทิศทาง
PROFILE_FIXTURE="$FIXTURES_DIR/PROFILE-CORE-HUB"

CSMJU_PROFILE=subsystem "$SCRIPT_DIR/check-authorized-deps.sh" "$PROFILE_FIXTURE" >/dev/null 2>&1
assert_exit "ARC-02 subsystem ตี passport-jwt/@nestjs/jwt ตก" 1 "$?"
CSMJU_PROFILE=core-hub  "$SCRIPT_DIR/check-authorized-deps.sh" "$PROFILE_FIXTURE" >/dev/null 2>&1
assert_exit "ARC-02 core-hub อนุญาต allowed_core_hub" 0 "$?"

CSMJU_PROFILE=subsystem "$SCRIPT_DIR/check-field-aliases.sh" "$PROFILE_FIXTURE" >/dev/null 2>&1
assert_exit "DD-01 subsystem ตี user_id ตก" 1 "$?"
CSMJU_PROFILE=core-hub  "$SCRIPT_DIR/check-field-aliases.sh" "$PROFILE_FIXTURE" >/dev/null 2>&1
assert_exit "DD-01 core-hub ข้าม (เจ้าของตาราง users)" 0 "$?"

# ค่าเริ่มต้นต้องเป็น subsystem เสมอ — ห้าม profile รั่วเป็น core-hub เมื่อไม่ได้ตั้งค่า
(unset CSMJU_PROFILE; "$SCRIPT_DIR/check-field-aliases.sh" "$PROFILE_FIXTURE" >/dev/null 2>&1)
assert_exit "ค่าเริ่มต้นของ CSMJU_PROFILE คือ subsystem" 1 "$?"

# subsystem-compliance.yml ต้องไม่ส่ง profile core-hub ให้ระบบย่อย
if grep -q "CSMJU_PROFILE" "$SCRIPT_DIR/../.github/workflows/subsystem-compliance.yml"; then
  assert_exit "subsystem workflow ไม่ตั้ง CSMJU_PROFILE" 0 1
else
  assert_exit "subsystem workflow ไม่ตั้ง CSMJU_PROFILE" 0 0
fi
# core-hub-compliance.yml ต้องตั้ง profile ให้เอง
if grep -q "CSMJU_PROFILE: core-hub" "$SCRIPT_DIR/../.github/workflows/core-hub-compliance.yml"; then
  assert_exit "core-hub workflow ตั้ง CSMJU_PROFILE=core-hub" 0 0
else
  assert_exit "core-hub workflow ตั้ง CSMJU_PROFILE=core-hub" 0 1
fi

echo
echo "=================================================================="
if [[ "$FAILED" -gt 0 ]]; then
  echo "❌ self-test: $FAILED / $TOTAL assertions failed"
  exit 1
fi
echo "✅ self-test: all $TOTAL assertions passed"
