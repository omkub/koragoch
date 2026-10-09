import { useEffect, useRef, useState } from 'react';

export interface FitInfo {
  /** เนื้อหาสูงเกินพื้นที่พิมพ์ (px) — 0 = พอดีหน้า */
  overflowPx: number;
  /** เนื้อหากว้างเกิน (เช่น ช่องกว้างรวมเกินกระดาษ A5) */
  overflowWidthPx: number;
  /** ย่ออัตโนมัติเหลือ (1 = ไม่ย่อ) */
  fitScale: number;
}

/**
 * ตัวอย่างเอกสาร — iframe แยก CSS ออกจากหน้าเว็บ
 * กดที่บรรทัดบนเอกสาร = เลือกบรรทัดนั้นในตัวแก้ไข
 * ย่อทั้งกระดาษให้พอดีความกว้างช่องตัวอย่าง (แค่การแสดงผล ไม่กระทบการพิมพ์)
 */
export default function PreviewFrame({
  html,
  onSelectBlock,
  onFit,
}: {
  html: string;
  onSelectBlock?: (id: string) => void;
  onFit?: (info: FitInfo) => void;
}) {
  const ref = useRef<HTMLIFrameElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ w: 900, h: 1200, scale: 1 });
  const selectRef = useRef(onSelectBlock);
  const fitRef = useRef(onFit);
  selectRef.current = onSelectBlock;
  fitRef.current = onFit;

  useEffect(() => {
    const frame = ref.current;
    if (!frame) return;
    const measure = () => {
      const doc = frame.contentDocument;
      const page = doc?.querySelector<HTMLElement>('.page');
      const content = doc?.querySelector<HTMLElement>('.content');
      if (!doc || !page || !content) return;
      const availH = parseFloat(page.dataset.availH ?? '0');
      const availW = parseFloat(page.dataset.availW ?? '0');
      const fitScale = parseFloat(page.dataset.fitScale ?? '1');
      fitRef.current?.({
        overflowPx: fitScale < 1 ? 0 : Math.max(0, content.scrollHeight - availH),
        overflowWidthPx: fitScale < 1 ? 0 : Math.max(0, content.scrollWidth - availW),
        fitScale,
      });
      const pageW = page.offsetWidth + 40;
      const pageH = Math.max(page.offsetHeight, page.scrollHeight) + 40;
      const avail = wrapRef.current?.clientWidth ?? pageW;
      setSize({ w: pageW, h: pageH, scale: Math.min(1, avail / pageW) });
    };
    const onLoad = () => {
      const doc = frame.contentDocument;
      if (!doc) return;
      doc.body.style.padding = '20px 0';
      doc.addEventListener('click', (e) => {
        const el = (e.target as HTMLElement).closest<HTMLElement>('[data-block]');
        if (el?.dataset.block) selectRef.current?.(el.dataset.block);
      });
      measure();
      // ฟอนต์ / ย่อให้พอดีหน้าคำนวณเสร็จทีหลัง
      doc.fonts?.ready.then(measure);
      setTimeout(measure, 300);
    };
    frame.addEventListener('load', onLoad);
    return () => frame.removeEventListener('load', onLoad);
  }, []);

  useEffect(() => {
    const onResize = () =>
      setSize((s) => ({ ...s, scale: Math.min(1, (wrapRef.current?.clientWidth ?? s.w) / s.w) }));
    window.addEventListener('resize', onResize);
    return () => window.removeEventListener('resize', onResize);
  }, []);

  return (
    <div ref={wrapRef} className="preview-wrap" style={{ height: size.h * size.scale }}>
      <iframe
        ref={ref}
        title="ตัวอย่างเอกสาร"
        srcDoc={html}
        style={{ width: size.w, height: size.h, transform: `scale(${size.scale})`, transformOrigin: 'top left' }}
      />
    </div>
  );
}
