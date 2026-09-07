#!/usr/bin/env bash
# scripts/check-ui-designsystem.sh — DS-01..22
#
# ตรวจ "ชั้นหน้าจอ" ในระดับที่ grep ทำไม่ได้ โดยเรียก csmju-ui-lint ที่มากับ
# @csmju2030/design-system ซึ่ง parse โครงสร้าง App Router จริง
#
# ทำไมต้องเป็นสคริปต์ที่นี่ ไม่ใช่ workflow ในระบบย่อย:
#   GH-03 ห้ามระบบย่อยแก้ไฟล์ใน .github/workflows/ กฎทั้งหมดต้องมาจากส่วนกลางที่แตะไม่ได้
#
# ความสัมพันธ์กับ check-ui-tokens.sh:
#   UI-01..04 ยังเป็นของ check-ui-tokens.sh (เป็น source of truth)
#   สคริปต์นี้ตรวจสิ่งที่ต้องรู้โครงสร้างไฟล์และ AST เช่น
#     DS-01  root layout ครอบด้วย <CsmjuAppShell>
#     DS-02  ทุก route segment มี loading.tsx
#     DS-03  ทุก route segment มี error.tsx
#     DS-04  มี not-found.tsx ที่ราก app/
#     DS-05  <IconButton> มี prop label (aria-label ภาษาไทย)
#     DS-06  <Button disabled> มี disabledReason
#     DS-07  ทุก page export metadata ด้วย csmjuTitle()
#     DS-08  ไม่ใช้ next/font/google
#     DS-13  มี @csmju2030/design-system ใน dependencies
#     DS-14  ไม่ fork component ของ design system
#     DS-16  root layout ไม่มี "use client"
#     DS-19  design_system_version ใน subsystem.yaml ตรงกับ .standards-version
#     DS-20  ไม่เขียน refresh token logic เอง            (auth-contract 22)
#     DS-21  ไม่เรียก /oauth/token ของ Core เอง           (auth-contract 4, 19, 22)
#     DS-22  มี route handler /auth ที่ใช้ createCsmjuAuthRoutes()
#
# เคารพ .compliance-exceptions.yml เหมือน check อื่น ๆ (11.1)
#
# Usage: check-ui-designsystem.sh [target_dir]
set -euo pipefail

TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"

# ระบบที่ยังไม่มีฝั่งหน้าเว็บ (backend-only) ไม่ต้องตรวจ
if [[ ! -d frontend ]]; then
  echo "✅ [DS-xx] ไม่พบโฟลเดอร์ frontend/ (ข้ามการตรวจชั้นหน้าจอ)"
  exit 0
fi

# เวอร์ชันที่ใช้ตรวจ ต้องตรงกับ design_system_version ที่ระบบย่อยประกาศไว้
DS_VERSION="${CSMJU_DESIGN_SYSTEM_VERSION:-1.3.0}"
PKG="@csmju2030/design-system@${DS_VERSION}"

# ดึง CLI มา — ถ้าดึงไม่ได้ถือว่า "ตรวจไม่ได้" ไม่ใช่ "ผ่าน"
if ! npx --yes "$PKG" csmju-ui-lint --help >/dev/null 2>&1; then
  cat <<EOF
❌ [DS-xx] ดึง $PKG จาก GitHub Packages ไม่ได้
   สาเหตุที่พบบ่อย:
     1. ยังไม่ได้ตั้ง NODE_AUTH_TOKEN ให้ job นี้
     2. เวอร์ชัน $DS_VERSION ยังไม่ถูก publish
   อ้างอิง: ui-design-system.md 17.5
EOF
  exit 1
fi

if ! npx --yes "$PKG" csmju-ui-lint; then
  cat <<EOF
   อ้างอิง: ui-design-system.md 5, 9, 16 · auth-contract.md 4, 10, 19, 22
   วิธีแก้: ทำตามข้อความของแต่ละกฎด้านบน หรือดู docs/QUICKSTART.md
            ของ repo CSMJU2030/design-system
EOF
  exit 1
fi
