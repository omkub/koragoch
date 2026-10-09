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
import { build } from 'esbuild';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const central = resolve(here, '..');
const out = resolve(central, '../test/fixtures/form_render_cases.json');
const bundle = resolve(central, 'node_modules/.cache/form-fixtures/bundle.mjs');

mkdirSync(dirname(bundle), { recursive: true });
await build({
  entryPoints: [resolve(here, 'form-render-cases.ts')],
  bundle: true,
  platform: 'node',
  format: 'esm',
  outfile: bundle,
  external: ['@supabase/supabase-js'],
  logLevel: 'warning',
});

const { renderedCases, computedLeaveContexts } = await import(pathToFileURL(bundle).href);
const cases = renderedCases();
const contexts = computedLeaveContexts();

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(cases, null, 1) + '\n');
const outContexts = resolve(dirname(out), 'leave_context_cases.json');
writeFileSync(outContexts, JSON.stringify(contexts, null, 1) + '\n');
console.log(`เขียน ${cases.length} กรณีลง ${out} และ ${contexts.length} กรณีลง ${outContexts} แล้ว`);
process.exit(0);
