/**
 * ส่งออกแม่แบบเริ่มต้น (ใบลา / ใบขออนุญาตไปราชการ) จากโค้ด web ไปให้ app
 *
 * app ใช้แม่แบบเริ่มต้นเมื่อฐานข้อมูลยังไม่มีแม่แบบ ต้องตรงกับของ web ทุกค่า
 * จึงสร้างไฟล์ Dart จากโค้ดชุดเดียวกันแทนการเขียนซ้ำด้วยมือ
 *
 * วิธีใช้ (ในโฟลเดอร์ central):  npm run form-defaults
 * → เขียนทับ lib/forms/default_templates.g.dart
 * แก้ leaveTemplate.ts / tripTemplate.ts แล้วต้องรันใหม่ (CI รันให้ก่อน build ทุกครั้ง)
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bundleAndImport } from './bundle-forms.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const central = resolve(here, '..');
const outDart = resolve(central, '../lib/forms/default_templates.g.dart');
const bundle = resolve(central, 'node_modules/.cache/form-defaults/bundle.mjs');

const { defaultLeaveTemplate, defaultTripTemplate } = await bundleAndImport(
  {
    contents: `
      export { defaultLeaveTemplate } from './src/forms/leaveTemplate';
      export { defaultTripTemplate } from './src/forms/tripTemplate';
    `,
    resolveDir: central,
  },
  bundle,
);

/** id บรรทัดสุ่มจากเวลา — แทนด้วยเลขลำดับให้ไฟล์ที่สร้างไม่เปลี่ยนทุกครั้งที่รัน */
function stable(template) {
  return {
    ...template,
    blocks: template.blocks.map((b, i) => ({ ...b, id: `${template.formType}-${i + 1}` })),
  };
}

/** สตริง Dart แบบ raw (r'''...''') — JSON ของเราไม่มี ''' อยู่แล้ว */
function dartRaw(value) {
  const json = JSON.stringify(value, null, 2);
  if (json.includes("'''")) throw new Error("JSON มี ''' ใส่ในสตริง Dart ไม่ได้");
  return `r'''\n${json}\n'''`;
}

const dart = `// ไฟล์นี้สร้างอัตโนมัติจาก central/src/forms (leaveTemplate.ts / tripTemplate.ts)
// ห้ามแก้ด้วยมือ — แก้ที่ web แล้วรัน: cd central && npm run form-defaults
// ignore_for_file: lines_longer_than_80_chars

/// แม่แบบเริ่มต้นของใบลา (JSON เดียวกับ defaultLeaveTemplate() ใน web)
const String defaultLeaveTemplateJson = ${dartRaw(stable(defaultLeaveTemplate()))};

/// แม่แบบเริ่มต้นของใบขออนุญาตไปราชการ (JSON เดียวกับ defaultTripTemplate() ใน web)
const String defaultTripTemplateJson = ${dartRaw(stable(defaultTripTemplate()))};
`;

mkdirSync(dirname(outDart), { recursive: true });
writeFileSync(outDart, dart);
console.log(`เขียน ${outDart} แล้ว`);
process.exit(0);
