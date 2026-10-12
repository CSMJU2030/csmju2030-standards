#!/usr/bin/env node
'use strict';
/**
 * SEC-06: อ่านผลของ `pnpm audit --prod --json` แล้วพิมพ์ advisory ระดับ high/critical
 * ทีละรายการ (แพ็กเกจ · รุ่นที่ติดตั้ง · รุ่นที่แก้แล้ว · เส้นทาง · ลิงก์)
 *
 * อยู่เป็นไฟล์แยกจาก check-dependency-audit.sh เพราะ logic ซับซ้อนใน bash 3.2
 * ของ macOS พังง่าย (ห้าม heredoc ซ้อนใน $( ) — CLAUDE.md / api04-errorcode-scan.js)
 *
 * ใช้: node audit-report.js <report.json>
 * ออก: exit 0 = ไม่มี high/critical · 1 = มี · 2 = อ่านผลไม่ได้ (เช่น ต่อ registry ไม่ได้)
 *      ใน GitHub Actions พิมพ์ ::warning ด้วย ให้เห็นในหน้า PR โดยไม่ต้องเปิด log
 */
const fs = require('fs');

const BLOCKING = new Set(['high', 'critical']);
const inActions = process.env.GITHUB_ACTIONS === 'true';

let report;
try {
  report = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
} catch {
  process.exit(2);
}
if (!report || typeof report.advisories !== 'object' || report.advisories === null) {
  process.exit(2);
}

const counts = { critical: 0, high: 0, moderate: 0, low: 0 };
const blocking = [];
for (const a of Object.values(report.advisories)) {
  if (a.severity in counts) counts[a.severity] += 1;
  if (BLOCKING.has(a.severity)) blocking.push(a);
}

const order = { critical: 0, high: 1 };
blocking.sort((a, b) => order[a.severity] - order[b.severity] || a.module_name.localeCompare(b.module_name));

for (const a of blocking) {
  const versions = [...new Set((a.findings ?? []).map((f) => f.version))].join(', ') || '?';
  const path = (a.findings ?? []).flatMap((f) => f.paths ?? [])[0] ?? a.module_name;
  const patched = a.patched_versions && a.patched_versions !== '<0.0.0' ? a.patched_versions : 'ยังไม่มีรุ่นที่แก้';
  console.log(`⚠️  [SEC-06] ${a.module_name} ${versions} — ${a.severity}: ${a.title}`);
  console.log(`   เส้นทาง: ${path}`);
  console.log(`   ต้องเป็น: ${patched}`);
  if (a.url) console.log(`   รายละเอียด: ${a.url}`);
  if (inActions) {
    console.log(`::warning title=SEC-06 ${a.module_name}::${a.module_name} ${versions} มีช่องโหว่ระดับ ${a.severity} — ต้องเป็น ${patched} (${a.url ?? ''})`);
  }
}

const summary = `critical ${counts.critical} · high ${counts.high} · moderate ${counts.moderate} · low ${counts.low}`;
console.log(`   สรุป pnpm audit --prod: ${summary}`);
process.exit(blocking.length > 0 ? 1 : 0);
