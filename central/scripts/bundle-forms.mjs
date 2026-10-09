/**
 * รวมโค้ดแม่แบบฟอร์มของ web ให้รันใน node ได้ (ใช้กับสคริปต์ส่งออกให้ app)
 *
 * โค้ดแม่แบบ import ไฟล์ supabase.ts ซึ่งสร้าง client ตอนโหลดไฟล์ แต่สคริปต์
 * พวกนี้ไม่ได้ใช้ฐานข้อมูลเลย — ถ้าใช้ของจริง node ต่ำกว่า 22 (ใน CI) จะล้ม
 * เพราะไม่มี WebSocket ให้ supabase-js จึงแทนด้วยตัวปลอมที่โยน error ถ้าถูกเรียกใช้จริง
 */
import { build } from 'esbuild';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { pathToFileURL } from 'node:url';

const supabaseStub = {
  name: 'supabase-stub',
  setup(b) {
    b.onResolve({ filter: /^@supabase\/supabase-js$/ }, () => ({ path: 'supabase-js', namespace: 'stub' }));
    b.onLoad({ filter: /.*/, namespace: 'stub' }, () => ({
      loader: 'js',
      contents: `
        const fail = (key) => () => {
          throw new Error('สคริปต์ส่งออกแม่แบบห้ามใช้ฐานข้อมูล (เรียก ' + String(key) + ')');
        };
        const client = new Proxy({}, { get: (_, key) => fail(key) });
        export function createClient() { return client; }
      `,
    }));
  },
};

/** รวม [entry] (ไฟล์ หรือ { contents, resolveDir }) เป็น [outfile] แล้ว import คืนมา */
export async function bundleAndImport(entry, outfile) {
  mkdirSync(dirname(outfile), { recursive: true });
  await build({
    ...(typeof entry === 'string'
      ? { entryPoints: [entry] }
      : { stdin: { contents: entry.contents, resolveDir: entry.resolveDir, loader: 'ts' } }),
    bundle: true,
    platform: 'node',
    format: 'esm',
    outfile,
    plugins: [supabaseStub],
    logLevel: 'warning',
  });
  // ?t= กันได้ไฟล์เก่าจาก cache ของ node เมื่อรันซ้ำใน process เดียวกัน
  return import(`${pathToFileURL(outfile).href}?t=${Date.now()}`);
}
