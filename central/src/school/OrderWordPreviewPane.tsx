import { useState } from 'react';
import { Download, FileText, Printer, ZoomIn, ZoomOut } from 'lucide-react';
import {
  formatDigits,
  formatThaiOrderDate,
  type AppointmentOrderFull,
} from './appointmentOrders';

interface OrderWordPreviewPaneProps {
  schoolName: string;
  draft: Omit<AppointmentOrderFull, 'id'>;
  useThaiDigits: boolean;
  onChangeThaiDigits: (val: boolean) => void;
  onExportDocx?: () => void;
  exportingDocx?: boolean;
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export default function OrderWordPreviewPane({
  schoolName,
  draft,
  useThaiDigits,
  onChangeThaiDigits,
  onExportDocx,
  exportingDocx = false,
}: OrderWordPreviewPaneProps) {
  const [zoom, setZoom] = useState<85 | 100 | 115>(100);

  const num = (v: string | number) => formatDigits(v, useThaiDigits);
  const thaiDateInfo = formatThaiOrderDate(draft.order_date, useThaiDigits);

  function zoomStep(dir: -1 | 1) {
    setZoom((prev) => {
      if (dir === -1) return prev === 115 ? 100 : 85;
      return prev === 85 ? 100 : 115;
    });
  }

  /**
   * สั่งพิมพ์กระดาษ A4 หรือบันทึกเป็น PDF (รองรับทั้ง Windows และ iOS AirPrint/Save to Files)
   */
  function handlePrintA4() {
    const win = window.open('', '_blank');
    if (!win) return;

    const groupsHtml = draft.groups
      .map((g, gIdx) => {
        const gNo = num(gIdx + 1);
        const gTitle = escapeHtml(g.group_title || '........................');

        const membersRows = g.members
          .map((m, mIdx) => {
            const subNo = `${gNo}.${num(mIdx + 1)}`;
            const fullName = escapeHtml(
              m.full_name.trim() || '....................................',
            );
            const pos = escapeHtml(
              m.official_position.trim() || '........................',
            );
            const role = escapeHtml(m.working_role.trim() || 'คณะทำงาน');
            return `
              <tr>
                <td class="col-name"><span class="sub-no">${subNo}</span>${fullName}</td>
                <td class="col-pos">${pos}</td>
                <td class="col-role">${role}</td>
              </tr>
            `;
          })
          .join('');

        const dutiesRows = g.duties
          .map((d, dIdx) => {
            const dNo = num(dIdx + 1);
            const dText = escapeHtml(
              d.trim() || '................................................................',
            );
            return `<p class="duty-item"><span class="duty-no">${dNo}.</span>${dText}</p>`;
          })
          .join('');

        return `
          <div class="group-block">
            <p class="group-heading">${gNo}. ${gTitle}</p>
            <table class="member-table">
              <tbody>${membersRows}</tbody>
            </table>
            <p class="duty-heading">หน้าที่</p>
            <div class="duty-list">${dutiesRows}</div>
          </div>
        `;
      })
      .join('');

    const html = `<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="utf-8" />
  <title>คำสั่งที่ ${escapeHtml(draft.order_no)}/${escapeHtml(String(draft.order_year))} - ${escapeHtml(draft.subject)}</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@400;600&display=swap" rel="stylesheet">
  <style>
    @page {
      size: A4 portrait;
      margin: 20mm 20mm 20mm 30mm;
    }
    body {
      font-family: "TH SarabunPSK", "TH Sarabun New", "Sarabun", sans-serif;
      font-size: 16pt;
      line-height: 1.45;
      color: #000;
      margin: 0;
      padding: 0;
    }
    p { margin: 0 0 4pt 0; }
    .header { text-align: center; margin-bottom: 10pt; }
    .header-title { font-weight: 600; }
    .divider {
      width: 120px;
      border-bottom: 1px solid #000;
      margin: 8pt auto 12pt auto;
    }
    .indent { text-indent: 25mm; text-align: justify; }
    .group-block { margin-top: 8pt; }
    .group-heading { text-indent: 15mm; font-weight: 600; }
    .member-table {
      width: 100%;
      border-collapse: collapse;
      margin: 2pt 0 4pt 0;
    }
    .member-table td {
      padding: 1.5pt 4pt;
      vertical-align: top;
      font-size: 16pt;
    }
    .col-name { width: 45%; padding-left: 20mm !important; }
    .sub-no { display: inline-block; width: 12mm; }
    .col-pos { width: 30%; }
    .col-role { width: 25%; }
    .duty-heading { font-weight: 600; margin-top: 2pt; }
    .duty-list { padding-left: 20mm; }
    .duty-item { margin-bottom: 2pt; }
    .duty-no { display: inline-block; width: 8mm; }
    .effective { text-indent: 25mm; margin-top: 12pt; }
    .order-date { text-indent: 40mm; margin-top: 4pt; }
    .sig-box {
      margin-top: 28pt;
      margin-left: auto;
      width: 75mm;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="header">
    <p class="header-title">คำสั่ง${escapeHtml(schoolName)}</p>
    <p>ที่ ${escapeHtml(num(draft.order_no || '...'))}/${escapeHtml(num(draft.order_year || '....'))}</p>
    <p class="header-title">เรื่อง ${escapeHtml(num(draft.subject || '........................................'))}</p>
    <div class="divider"></div>
  </div>

  ${draft.preamble ? `<p class="indent">${escapeHtml(num(draft.preamble))}</p>` : ''}

  ${groupsHtml}

  <p class="effective">${escapeHtml(num(draft.effective_text || 'ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป'))}</p>
  <p class="order-date">${escapeHtml(thaiDateInfo.fullText)}</p>

  <div class="sig-box">
    <p>........................................</p>
    <p>(${escapeHtml(draft.signer_name || '........................................')})</p>
    <p>(${escapeHtml(draft.signer_title || 'ตำแหน่ง................................')})</p>
  </div>
  <script>
    window.onload = function() {
      setTimeout(function() { window.print(); }, 250);
    };
  </script>
</body>
</html>`;

    win.document.open();
    win.document.write(html);
    win.document.close();
  }

  return (
    <div className="surface-card overflow-hidden">
      {/* Top Word Preview Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-line bg-canvas px-4 py-2.5">
        <div className="flex items-center gap-2">
          <FileText
            className="h-4 w-4 shrink-0 text-brand-600"
            strokeWidth={1.5}
          />
          <div>
            <p className="text-xs font-semibold text-ink">
              ตัวอย่างกระดาษ Word (A4 Live Preview)
            </p>
            <p className="text-[11px] text-slate-500">
              กั้นหน้าราชการ ซ้าย 3 ซม. · ขวา 2 ซม. · ฟอนต์สารบรรณ
            </p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-1.5">
          {/* Arabic vs Thai Digits Switcher */}
          <div
            className="inline-flex rounded-lg border border-line bg-white p-0.5"
            title="รูปแบบตัวเลขในเอกสาร"
          >
            <button
              type="button"
              onClick={() => onChangeThaiDigits(false)}
              className={`rounded px-2 py-1 text-[11px] font-medium transition-colors ${
                !useThaiDigits
                  ? 'bg-brand-50 text-brand-700'
                  : 'text-slate-500 hover:text-ink'
              }`}
            >
              1, 2, 3
            </button>
            <button
              type="button"
              onClick={() => onChangeThaiDigits(true)}
              className={`rounded px-2 py-1 text-[11px] font-medium transition-colors ${
                useThaiDigits
                  ? 'bg-brand-50 text-brand-700'
                  : 'text-slate-500 hover:text-ink'
              }`}
            >
              ๑, ๒, ๓
            </button>
          </div>

          {/* Zoom Controls */}
          <div className="hidden items-center rounded-lg border border-line bg-white px-1 py-0.5 sm:inline-flex">
            <button
              type="button"
              disabled={zoom === 85}
              onClick={() => zoomStep(-1)}
              className="rounded p-1 text-slate-500 hover:bg-slate-100 disabled:opacity-40"
              title="ย่อกระดาษ"
            >
              <ZoomOut className="h-3.5 w-3.5" strokeWidth={1.5} />
            </button>
            <span className="w-10 text-center tabular-nums text-[11px] font-medium text-slate-600">
              {zoom}%
            </span>
            <button
              type="button"
              disabled={zoom === 115}
              onClick={() => zoomStep(1)}
              className="rounded p-1 text-slate-500 hover:bg-slate-100 disabled:opacity-40"
              title="ขยายกระดาษ"
            >
              <ZoomIn className="h-3.5 w-3.5" strokeWidth={1.5} />
            </button>
          </div>

          {/* Print / PDF Button (iOS AirPrint & Windows Print) */}
          <button
            type="button"
            onClick={handlePrintA4}
            className="btn-secondary btn-sm"
            title="สั่งพิมพ์กระดาษ A4 หรือบันทึกเป็น PDF บน iOS และ Windows"
          >
            <Printer className="h-3.5 w-3.5" strokeWidth={1.5} />
            <span>พิมพ์ / PDF</span>
          </button>

          {/* Word (.docx) Export Button */}
          {onExportDocx && (
            <button
              type="button"
              disabled={exportingDocx}
              onClick={onExportDocx}
              className="btn-primary btn-sm"
            >
              <Download className="h-3.5 w-3.5" strokeWidth={1.5} />
              <span>
                {exportingDocx ? 'กำลังสร้างไฟล์...' : 'ส่งออก Word (.docx)'}
              </span>
            </button>
          )}
        </div>
      </div>

      {/* Word Top Margin Ruler Bar */}
      <div className="hidden border-b border-slate-200 bg-slate-200/70 px-6 py-1 text-[10px] text-slate-500 sm:flex sm:items-center sm:justify-between">
        <span>กั้นซ้าย 3.0 ซม.</span>
        <span className="tabular-nums">
          กระดาษ A4 (21.0 × 29.7 ซม.) · TH SarabunPSK 16 pt
        </span>
        <span>กั้นขวา 2.0 ซม.</span>
      </div>

      {/* Scrollable Paper Workspace */}
      <div className="max-h-[82vh] overflow-auto bg-slate-100 p-3 sm:p-6">
        <div
          style={{
            transform: `scale(${zoom / 100})`,
            transformOrigin: 'top center',
          }}
          className="mx-auto min-h-[840px] w-full max-w-[680px] rounded-sm border border-slate-300 bg-white pt-10 pb-14 pr-7 pl-10 text-[15px] leading-[1.6] text-ink shadow-sm transition-transform sm:pr-10 sm:pl-14"
        >
          {/* ส่วนหัว: คำสั่ง / ที่ .../... / เรื่อง..... / เส้นคั่น */}
          <div className="text-center">
            <p className="font-semibold text-ink">คำสั่ง{schoolName}</p>
            <p className="tabular-nums">
              ที่ {num(draft.order_no || '...')} / {num(draft.order_year || '....')}
            </p>
            <p className="font-semibold text-ink">
              เรื่อง {num(draft.subject || '........................................')}
            </p>
            <div className="mx-auto my-3 w-36 border-b border-slate-700" />
          </div>

          {/* ข้อความเกริ่นนำ */}
          {draft.preamble && (
            <p className="mt-3 indent-10 text-justify whitespace-pre-line">
              {num(draft.preamble)}
            </p>
          )}

          {/* ชุดคณะทำงาน ข้อ 1, 2, 3... */}
          <div className="mt-4 space-y-4">
            {draft.groups.map((g, gIdx) => {
              const gNo = num(gIdx + 1);
              return (
                <div key={gIdx} className="space-y-1">
                  {/* 1. คณะทำงานด้านอำนวยการ */}
                  <p className="indent-6 font-semibold text-ink">
                    {gNo}. {num(g.group_title || 'คณะทำงาน........')}
                  </p>

                  {/* 1.1 ชื่อ-นามสกุล   ตำแหน่ง   ตำแหน่งทำงาน */}
                  <table className="w-full border-collapse text-[14.5px]">
                    <tbody>
                      {g.members.map((m, mIdx) => {
                        const subNo = `${gNo}.${num(mIdx + 1)}`;
                        return (
                          <tr key={mIdx} className="align-top">
                            <td className="w-[45%] py-0.5 pl-8 pr-2">
                              <span className="inline-block w-8 tabular-nums">
                                {subNo}
                              </span>
                              <span>
                                {m.full_name.trim() ||
                                  'ชื่อ-นามสกุล....................'}
                              </span>
                            </td>
                            <td className="w-[30%] py-0.5 px-2">
                              {m.official_position.trim() || 'ตำแหน่ง............'}
                            </td>
                            <td className="w-[25%] py-0.5 pl-2">
                              {m.working_role.trim() || 'ตำแหน่งทำงาน'}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>

                  {/* หน้าที่ 1, 2, 3... */}
                  <div className="pt-1">
                    <p className="font-semibold text-ink">หน้าที่</p>
                    <div className="space-y-0.5 pl-8">
                      {g.duties.map((d, dIdx) => (
                        <p key={dIdx} className="flex items-start">
                          <span className="w-6 shrink-0 tabular-nums">
                            {num(dIdx + 1)}.
                          </span>
                          <span className="flex-1">
                            {num(
                              d.trim() ||
                                '........................................................',
                            )}
                          </span>
                        </p>
                      ))}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* ส่วนท้าย: ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป + สั่ง ณ วันที่ ... + ผู้ลงนาม */}
          <div className="mt-6 space-y-1.5">
            <p className="indent-10">
              {num(draft.effective_text || 'ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป')}
            </p>
            <p className="indent-16 tabular-nums">{thaiDateInfo.fullText}</p>

            <div className="mt-10 ml-auto w-64 text-center">
              <p className="tracking-widest text-slate-500">
                ........................................
              </p>
              <p className="mt-1">
                ({draft.signer_name.trim() || '........................................'})
              </p>
              <p>
                ({draft.signer_title.trim() || 'ตำแหน่ง................................'})
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
