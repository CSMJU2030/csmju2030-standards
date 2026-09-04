#!/usr/bin/env bash
# apply-rulesets.sh — create the two CSMJU2030 rulesets from the .json
# payloads beside this script.
#
#   ./apply-rulesets.sh org                 # one org ruleset covering csmju-*
#   ./apply-rulesets.sh repo csmju-equipment [more repos...]
#   ./apply-rulesets.sh validate <repo>     # POST as `disabled`, then delete
#
# org mode needs the `admin:org` scope:
#   gh auth refresh -h github.com -s admin:org
# repo mode works with plain `repo` scope but must be run per subsystem repo.
#
# A ruleset of the same name is updated in place (PUT) rather than duplicated.

set -euo pipefail

ORG="CSMJU2030"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:?ระบุ mode: org | repo | validate}"
shift || true

# บล็อกกรณี default branch ยังไม่ใช่ main — ruleset exclude แค่ refs/heads/main
# ถ้า default เป็น master จะโดน branch_name_pattern ตีตก push เข้า default เอง
guard_default_branch() {
  local repo="$1" br
  br=$(gh api "repos/$ORG/$repo" --jq .default_branch)
  if [ "$br" != "main" ]; then
    echo "❌ $repo: default branch คือ '$br' ไม่ใช่ 'main'" >&2
    echo "   ต้อง rename เป็น main ก่อน ไม่งั้น branch-naming จะบล็อก branch หลักเอง" >&2
    return 1
  fi
}

# POST ถ้ายังไม่มีชื่อนี้, PUT ถ้ามีแล้ว
upsert() {
  local scope_path="$1" payload="$2" name existing
  name=$(jq -r .name "$payload")
  existing=$(gh api "$scope_path" --jq ".[] | select(.name==\"$name\") | .id" 2>/dev/null | head -1)
  if [ -n "$existing" ]; then
    gh api "$scope_path/$existing" -X PUT --input "$payload" --jq '"  ↻ อัปเดต \(.name) (id=\(.id), \(.enforcement))"'
  else
    gh api "$scope_path" -X POST --input "$payload" --jq '"  + สร้าง \(.name) (id=\(.id), \(.enforcement))"'
  fi
}

case "$MODE" in
  org)
    echo "→ org ruleset บน $ORG (ครอบ csmju-*)"
    for n in main-protection branch-naming; do
      upsert "orgs/$ORG/rulesets" "$DIR/ruleset-$n.org.json"
    done
    ;;
  repo)
    [ "$#" -gt 0 ] || { echo "ระบุชื่อ repo อย่างน้อย 1 ตัว" >&2; exit 1; }
    for repo in "$@"; do
      echo "→ $ORG/$repo"
      guard_default_branch "$repo"
      for n in main-protection branch-naming; do
        upsert "repos/$ORG/$repo/rulesets" "$DIR/ruleset-$n.repo.json"
      done
    done
    ;;
  validate)
    repo="${1:?ระบุ repo}"
    echo "→ validate payload บน $ORG/$repo (สร้างแบบ disabled แล้วลบ)"
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    for n in main-protection branch-naming; do
      jq '.enforcement="disabled" | .name="VALIDATE-ONLY-'"$n"'"' \
        "$DIR/ruleset-$n.repo.json" > "$tmp/$n.json"
      id=$(gh api "repos/$ORG/$repo/rulesets" -X POST --input "$tmp/$n.json" --jq .id)
      echo "  ✅ $n รับได้ (id=$id)"
      gh api "repos/$ORG/$repo/rulesets/$id" -X DELETE
    done
    echo "  ลบ ruleset ทดสอบเรียบร้อย"
    ;;
  *)
    echo "mode ไม่รู้จัก: $MODE (org | repo | validate)" >&2; exit 1 ;;
esac

echo "✅ เสร็จ"
