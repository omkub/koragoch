/**
 * ส่งออกชุดทดสอบตัววาดเอกสาร: แม่แบบ + ข้อมูล + HTML ที่ web วาดได้
 *
 * เทสฝั่ง app (test/form_render_parity_test.dart) วาดชุดเดียวกันแล้วเทียบ
 * ว่าได้ HTML เดียวกันทุกตัวอักษร — แก้ render.ts แล้วลืมแก้ form_render.dart
 * (หรือกลับกัน) เทสจะไม่ผ่าน
 *
 * วิธีใช้ (ในโฟลเดอร์ central):  npm run form-fixtures
 * → เขียนทับ test/fixtures/form_render_cases.json (CI รันให้ก่อนเทสทุกครั้ง)
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bundleAndImport } from './bundle-forms.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const central = resolve(here, '..');
const out = resolve(central, '../test/fixtures/form_render_cases.json');
const bundle = resolve(central, 'node_modules/.cache/form-fixtures/bundle.mjs');

const { renderedCases, computedLeaveContexts, computedTripContexts } = await bundleAndImport(
  resolve(here, 'form-render-cases.ts'),
  bundle,
);
const cases = renderedCases();
const contexts = computedLeaveContexts();

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(cases, null, 1) + '\n');
const outContexts = resolve(dirname(out), 'leave_context_cases.json');
writeFileSync(outContexts, JSON.stringify(contexts, null, 1) + '\n');
const trips = computedTripContexts();
const outTrips = resolve(dirname(out), 'trip_context_cases.json');
writeFileSync(outTrips, JSON.stringify(trips, null, 1) + '\n');
console.log(`เขียน ${cases.length} + ${contexts.length} + ${trips.length} กรณีลง ${dirname(out)} แล้ว`);
process.exit(0);
