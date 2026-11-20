import {
  ALL_ARABIC_DIGITS,
  ALL_THAI_DIGITS,
  formatDigits,
  formatThaiOrderDate,
  type AppointmentOrderFull,
  type DigitFormatSettings,
  DEFAULT_EFFECTIVE_TEXT,
  splitParagraphs,
} from './appointmentOrders';

function xmlEscape(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

// --- Minimal Pure-TS ZIP Builder (STORE method + CRC32) for OpenXML (.docx) ---
const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[i] = c >>> 0;
  }
  return table;
})();

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) {
    crc = CRC_TABLE[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function buildZipBlob(
  files: { path: string; content: string | Uint8Array }[],
): Blob {
  const encoder = new TextEncoder();
  const entries = files.map((f) => {
    const nameBytes = encoder.encode(f.path);
    const dataBytes =
      typeof f.content === 'string' ? encoder.encode(f.content) : f.content;
    const crc = crc32(dataBytes);
    return { nameBytes, dataBytes, crc, offset: 0 };
  });

  let localSize = 0;
  for (const e of entries) {
    e.offset = localSize;
    localSize += 30 + e.nameBytes.length + e.dataBytes.length;
  }

  let centralSize = 0;
  for (const e of entries) {
    centralSize += 46 + e.nameBytes.length;
  }

  const totalSize = localSize + centralSize + 22;
  const buf = new ArrayBuffer(totalSize);
  const view = new DataView(buf);
  const out = new Uint8Array(buf);

  let pos = 0;
  for (const e of entries) {
    view.setUint32(pos, 0x04034b50, true);
    view.setUint16(pos + 4, 20, true);
    view.setUint16(pos + 6, 0x0800, true);
    view.setUint16(pos + 8, 0, true);
    view.setUint16(pos + 10, 0, true);
    view.setUint16(pos + 12, 0x5421, true);
    view.setUint32(pos + 14, e.crc, true);
    view.setUint32(pos + 18, e.dataBytes.length, true);
    view.setUint32(pos + 22, e.dataBytes.length, true);
    view.setUint16(pos + 26, e.nameBytes.length, true);
    view.setUint16(pos + 28, 0, true);
    pos += 30;
    out.set(e.nameBytes, pos);
    pos += e.nameBytes.length;
    out.set(e.dataBytes, pos);
    pos += e.dataBytes.length;
  }

  const centralStart = pos;
  for (const e of entries) {
    view.setUint32(pos, 0x02014b50, true);
    view.setUint16(pos + 4, 20, true);
    view.setUint16(pos + 6, 20, true);
    view.setUint16(pos + 8, 0x0800, true);
    view.setUint16(pos + 10, 0, true);
    view.setUint16(pos + 12, 0, true);
    view.setUint16(pos + 14, 0x5421, true);
    view.setUint32(pos + 16, e.crc, true);
    view.setUint32(pos + 20, e.dataBytes.length, true);
    view.setUint32(pos + 24, e.dataBytes.length, true);
    view.setUint16(pos + 28, e.nameBytes.length, true);
    view.setUint16(pos + 30, 0, true);
    view.setUint16(pos + 32, 0, true);
    view.setUint16(pos + 34, 0, true);
    view.setUint16(pos + 36, 0, true);
    view.setUint32(pos + 38, 0, true);
    view.setUint32(pos + 42, e.offset, true);
    pos += 46;
    out.set(e.nameBytes, pos);
    pos += e.nameBytes.length;
  }

  view.setUint32(pos, 0x06054b50, true);
  view.setUint16(pos + 4, 0, true);
  view.setUint16(pos + 6, 0, true);
  view.setUint16(pos + 8, entries.length, true);
  view.setUint16(pos + 10, entries.length, true);
  view.setUint32(pos + 12, centralSize, true);
  view.setUint32(pos + 16, centralStart, true);
  view.setUint16(pos + 20, 0, true);

  return new Blob([buf], {
    type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  });
}

// ขอบกระดาษตามไฟล์ต้นฉบับคำสั่งแต่งตั้ง (twips: 1 ซม. = 567)
const PAGE_W = 11906; // A4
const PAGE_H = 16838;
const MARGIN_TOP = 851; // 1.5 ซม.
const MARGIN_BOTTOM = 851;
const MARGIN_LEFT = 1134; // 2 ซม.
const MARGIN_RIGHT = 851;
const TEXT_WIDTH_TWIPS = PAGE_W - MARGIN_LEFT - MARGIN_RIGHT;

// --- OpenXML Paragraph & Table Builders (TH SarabunPSK 16pt) ---
function runPropsXml(bold = false): string {
  return `<w:rPr>
    <w:rFonts w:ascii="TH SarabunPSK" w:hAnsi="TH SarabunPSK" w:cs="TH SarabunPSK" w:eastAsia="TH SarabunPSK"/>
    ${bold ? '<w:b/><w:bCs/>' : ''}
    <w:noProof/>
    <w:sz w:val="32"/>
    <w:szCs w:val="32"/>
    <w:lang w:val="th-TH" w:eastAsia="th-TH" w:bidi="th-TH"/>
  </w:rPr>`;
}

function paragraphXml(
  text: string,
  opts: {
    align?: 'left' | 'center' | 'right' | 'both';
    bold?: boolean;
    firstLineTwips?: number;
    leftTwips?: number;
    afterTwips?: number;
    beforeTwips?: number;
  } = {},
): string {
  const alignTag = opts.align ? `<w:jc w:val="${opts.align}"/>` : '';
  const indAttrs = [
    opts.leftTwips ? `w:left="${opts.leftTwips}"` : '',
    opts.firstLineTwips ? `w:firstLine="${opts.firstLineTwips}"` : '',
  ]
    .filter(Boolean)
    .join(' ');
  const indTag = indAttrs ? `<w:ind ${indAttrs}/>` : '';
  const spacingTag = `<w:spacing w:before="${opts.beforeTwips ?? 0}" w:after="${opts.afterTwips ?? 80}" w:line="260" w:lineRule="auto"/>`;

  return `<w:p>
    <w:pPr>
      ${alignTag}
      ${indTag}
      ${spacingTag}
      ${runPropsXml(opts.bold)}
    </w:pPr>
    <w:r>
      ${runPropsXml(opts.bold)}
      <w:t xml:space="preserve">${xmlEscape(text)}</w:t>
    </w:r>
  </w:p>`;
}

/**
 * ตารางรายชื่อไร้เส้น 4 คอลัมน์ (ตามไฟล์ต้นฉบับคำสั่งแต่งตั้งของโรงเรียน):
 * ลำดับ (นับใหม่ทุกคณะ) | ชื่อ-นามสกุล | ตำแหน่ง | หน้าที่ในคณะ
 * ความกว้างรวม = ความกว้างพื้นที่พิมพ์ A4 หลังหักขอบ (TEXT_WIDTH_TWIPS)
 */
const MEMBER_COLS = [624, 3240, 3870, 2187] as const;

function memberTableXml(
  members: AppointmentOrderFull['groups'][number]['members'],
  useThaiMemberDigits: boolean,
): string {
  const cell = (w: number, text: string) => `<w:tc>
          <w:tcPr><w:tcW w:w="${w}" w:type="dxa"/></w:tcPr>
          ${paragraphXml(text, { afterTwips: 0 })}
        </w:tc>`;
  const rowsXml = members
    .map((m, mIdx) => {
      const no = `${formatDigits(mIdx + 1, useThaiMemberDigits)}.`;
      const fullName = m.full_name.trim() || '....................................';
      const pos = m.official_position.trim() || '........................';
      const role = m.working_role.trim() || 'กรรมการ';
      return `<w:tr>
        ${cell(MEMBER_COLS[0], no)}
        ${cell(MEMBER_COLS[1], fullName)}
        ${cell(MEMBER_COLS[2], pos)}
        ${cell(MEMBER_COLS[3], role)}
      </w:tr>`;
    })
    .join('');

  return `<w:tbl>
    <w:tblPr>
      <w:tblW w:w="${TEXT_WIDTH_TWIPS}" w:type="dxa"/>
      <w:tblLayout w:type="fixed"/>
      <w:tblBorders>
        <w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>
      </w:tblBorders>
      <w:tblCellMar>
        <w:left w:w="0" w:type="dxa"/>
        <w:right w:w="113" w:type="dxa"/>
      </w:tblCellMar>
    </w:tblPr>
    <w:tblGrid>
      ${MEMBER_COLS.map((w) => `<w:gridCol w:w="${w}"/>`).join('')}
    </w:tblGrid>
    ${rowsXml}
  </w:tbl>`;
}

function decodePngDataUrl(dataUrl?: string): {
  bytes: Uint8Array;
  width: number;
  height: number;
} | null {
  if (!dataUrl || !dataUrl.includes('base64,')) return null;
  try {
    const b64 = dataUrl.split('base64,')[1];
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) {
      bytes[i] = bin.charCodeAt(i);
    }
    let width = 300;
    let height = 300;
    // Read PNG IHDR chunk (width at offset 16, height at offset 20)
    if (
      bytes.length >= 24 &&
      bytes[0] === 0x89 &&
      bytes[1] === 0x50 &&
      bytes[2] === 0x4e &&
      bytes[3] === 0x47
    ) {
      const view = new DataView(bytes.buffer);
      const w = view.getUint32(16, false);
      const h = view.getUint32(20, false);
      if (w > 0 && h > 0) {
        width = w;
        height = h;
      }
    }
    return { bytes, width, height };
  } catch {
    return null;
  }
}

function emblemDrawingParagraphXml(cxEmu: number, cyEmu: number): string {
  return `<w:p>
    <w:pPr>
      <w:jc w:val="center"/>
      <w:spacing w:before="0" w:after="60" w:line="240" w:lineRule="auto"/>
    </w:pPr>
    <w:r>
      <w:drawing>
        <wp:inline distT="0" distB="0" distL="0" distR="0">
          <wp:extent cx="${cxEmu}" cy="${cyEmu}"/>
          <wp:effectExtent l="0" t="0" r="0" b="0"/>
          <wp:docPr id="1" name="GarudaEmblem" descr="ตราครุฑ"/>
          <wp:cNvGraphicFramePr>
            <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
          </wp:cNvGraphicFramePr>
          <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
            <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:nvPicPr>
                  <pic:cNvPr id="1" name="emblem.png"/>
                  <pic:cNvPicPr/>
                </pic:nvPicPr>
                <pic:blipFill>
                  <a:blip r:embed="rId2"/>
                  <a:stretch>
                    <a:fillRect/>
                  </a:stretch>
                </pic:blipFill>
                <pic:spPr>
                  <a:xfrm>
                    <a:off x="0" y="0"/>
                    <a:ext cx="${cxEmu}" cy="${cyEmu}"/>
                  </a:xfrm>
                  <a:prstGeom prst="rect">
                    <a:avLst/>
                  </a:prstGeom>
                </pic:spPr>
              </pic:pic>
            </a:graphicData>
          </a:graphic>
        </wp:inline>
      </w:drawing>
    </w:r>
  </w:p>`;
}

/**
 * สร้างและดาวน์โหลดไฟล์ Microsoft Word (.docx) มาตรฐาน OpenXML
 * รองรับการตั้งค่าเลขอารบิก / เลขไทย แยกตามส่วนของเอกสาร และฝังรูปตราครุฑ
 */
export async function exportAppointmentOrderToDocx(
  schoolName: string,
  draft: Omit<AppointmentOrderFull, 'id'>,
  digitSettingsOrBool: DigitFormatSettings | boolean = ALL_ARABIC_DIGITS,
): Promise<void> {
  const ds: DigitFormatSettings =
    typeof digitSettingsOrBool === 'boolean'
      ? digitSettingsOrBool
        ? ALL_THAI_DIGITS
        : ALL_ARABIC_DIGITS
      : digitSettingsOrBool;

  const thaiDateInfo = formatThaiOrderDate(draft.order_date, ds.orderDate);
  const bodyParts: string[] = [];

  const emblemPng = decodePngDataUrl(draft.emblem_data_url);
  if (emblemPng) {
    const heightCm = draft.emblem_height_cm || 3.0;
    const cyEmu = Math.round(heightCm * 360000);
    const cxEmu = Math.round(cyEmu * (emblemPng.width / emblemPng.height));
    bodyParts.push(emblemDrawingParagraphXml(cxEmu, cyEmu));
  }

  // 1) ส่วนหัวคำสั่ง (ds.header)
  bodyParts.push(
    paragraphXml(`คำสั่ง${schoolName}`, {
      align: 'center',
      bold: true,
      afterTwips: 40,
    }),
  );
  bodyParts.push(
    paragraphXml(
      `ที่ ${formatDigits(draft.order_no || '...', ds.header)} / ${formatDigits(draft.order_year || '....', ds.header)}`,
      { align: 'center', afterTwips: 40 },
    ),
  );
  bodyParts.push(
    paragraphXml(
      `เรื่อง ${formatDigits(draft.subject || '........................................', ds.header)}`,
      { align: 'center', bold: true, afterTwips: 60 },
    ),
  );
  bodyParts.push(
    paragraphXml('----------------------------------------', {
      align: 'center',
      afterTwips: 160,
    }),
  );

  // 2) ข้อความเกริ่นนำ (ds.preamble)
  if (draft.preamble.trim()) {
    const paragraphs = splitParagraphs(draft.preamble);
    for (const p of paragraphs) {
      bodyParts.push(
        paragraphXml(formatDigits(p.trim(), ds.preamble), {
          align: 'both',
          firstLineTwips: 1417,
          afterTwips: 120,
        }),
      );
    }
  }

  // 3) ชุดคณะทำงาน ข้อ 1, 2, 3...
  for (let gIdx = 0; gIdx < draft.groups.length; gIdx++) {
    const g = draft.groups[gIdx];
    const gHeadingNo = formatDigits(gIdx + 1, ds.groupHeading);

    // หัวข้อชุดคณะทำงาน (ds.groupHeading)
    bodyParts.push(
      paragraphXml(
        `${gHeadingNo}. ${formatDigits(g.group_title || 'คณะทำงาน........', ds.groupHeading)}`,
        {
          bold: true,
          firstLineTwips: 720,
          beforeTwips: 100,
          afterTwips: 60,
        },
      ),
    );

    // ตารางไร้เส้นขอบ 3 คอลัมน์ (ds.memberNo)
    bodyParts.push(memberTableXml(g.members, ds.memberNo));

    // หัวข้อ "หน้าที่"
    bodyParts.push(
      paragraphXml('ให้มีหน้าที่', {
        bold: true,
        beforeTwips: 60,
        afterTwips: 40,
      }),
    );

    // รายการหน้าที่ 1, 2, 3... (ds.dutyNo)
    for (let dIdx = 0; dIdx < g.duties.length; dIdx++) {
      const dNo = formatDigits(dIdx + 1, ds.dutyNo);
      const dText =
        g.duties[dIdx]?.trim() ||
        '........................................................';
      bodyParts.push(
        paragraphXml(`${dNo}. ${formatDigits(dText, ds.dutyNo)}`, {
          leftTwips: 720,
          afterTwips: 40,
        }),
      );
    }
  }

  // 4) ส่วนท้ายคำสั่ง: ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป + สั่ง ณ วันที่ ... (ds.orderDate)
  splitParagraphs(draft.effective_text || DEFAULT_EFFECTIVE_TEXT).forEach((p, i) => {
    bodyParts.push(
      paragraphXml(formatDigits(p, ds.orderDate), {
        align: 'both',
        firstLineTwips: 1417,
        beforeTwips: i === 0 ? 160 : 0,
        afterTwips: 80,
      }),
    );
  });
  bodyParts.push(
    paragraphXml(thaiDateInfo.fullText, {
      firstLineTwips: 2268,
      afterTwips: 360,
    }),
  );

  // 5) บล็อกลงนามผู้บริหาร
  bodyParts.push(
    paragraphXml('........................................', {
      leftTwips: 3969,
      align: 'center',
      afterTwips: 40,
    }),
  );
  bodyParts.push(
    paragraphXml(
      `(${draft.signer_name.trim() || '........................................'})`,
      {
        leftTwips: 3969,
        align: 'center',
        afterTwips: 40,
      },
    ),
  );
  bodyParts.push(
    paragraphXml(
      `(${draft.signer_title.trim() || 'ตำแหน่ง................................'})`,
      {
        leftTwips: 3969,
        align: 'center',
        afterTwips: 80,
      },
    ),
  );

  const documentXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
    ${bodyParts.join('\n')}
    <w:sectPr>
      <w:headerReference w:type="default" r:id="rIdHeader"/>
      <w:pgSz w:w="${PAGE_W}" w:h="${PAGE_H}"/>
      <w:pgMar w:top="${MARGIN_TOP}" w:right="${MARGIN_RIGHT}" w:bottom="${MARGIN_BOTTOM}" w:left="${MARGIN_LEFT}" w:header="454" w:footer="454" w:gutter="0"/>
      <w:titlePg/>
    </w:sectPr>
  </w:body>
</w:document>`;

  const stylesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="TH SarabunPSK" w:hAnsi="TH SarabunPSK" w:cs="TH SarabunPSK" w:eastAsia="TH SarabunPSK"/>
        <w:noProof/>
        <w:sz w:val="32"/>
        <w:szCs w:val="32"/>
        <w:lang w:val="th-TH" w:eastAsia="th-TH" w:bidi="th-TH"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>`;

  // หัวกระดาษ: เลขหน้ากึ่งกลาง (\* ThaiArabic = เลขไทย ตามการตั้งค่าเลขส่วนหัว)
  const pageField = ds.header ? 'PAGE \\* ThaiArabic' : 'PAGE';
  const headerXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="0"/></w:pPr>
    <w:r>${runPropsXml()}<w:fldChar w:fldCharType="begin"/></w:r>
    <w:r>${runPropsXml()}<w:instrText xml:space="preserve"> ${pageField} </w:instrText></w:r>
    <w:r>${runPropsXml()}<w:fldChar w:fldCharType="separate"/></w:r>
    <w:r>${runPropsXml()}<w:t>${ds.header ? '๒' : '2'}</w:t></w:r>
    <w:r>${runPropsXml()}<w:fldChar w:fldCharType="end"/></w:r>
  </w:p>
</w:hdr>`;

  const settingsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:hideSpellingErrors/>
  <w:hideGrammaticalErrors/>
  <w:proofState w:spelling="clean" w:grammar="clean"/>
</w:settings>`;

  const contentTypesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>`;

  const rootRelsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>`;

  const docRelsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rIdHeader" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>
  <Relationship Id="rIdSettings" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" Target="settings.xml"/>
  ${emblemPng ? '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/emblem.png"/>' : ''}
</Relationships>`;

  const zipFiles: { path: string; content: string | Uint8Array }[] = [
    { path: '[Content_Types].xml', content: contentTypesXml },
    { path: '_rels/.rels', content: rootRelsXml },
    { path: 'word/_rels/document.xml.rels', content: docRelsXml },
    { path: 'word/document.xml', content: documentXml },
    { path: 'word/styles.xml', content: stylesXml },
    { path: 'word/settings.xml', content: settingsXml },
    { path: 'word/header1.xml', content: headerXml },
  ];

  if (emblemPng) {
    zipFiles.push({ path: 'word/media/emblem.png', content: emblemPng.bytes });
  }

  const blob = buildZipBlob(zipFiles);

  const safeOrderNo = (draft.order_no || '1').replace(/[^a-zA-Z0-9ก-๙_-]/g, '-');
  const fileName = `คำสั่งที่_${safeOrderNo}-${draft.order_year || 2569}.docx`;

  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  setTimeout(() => URL.revokeObjectURL(url), 5000);
}
