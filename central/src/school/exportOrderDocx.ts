import {
  ALL_ARABIC_DIGITS,
  ALL_THAI_DIGITS,
  formatDigits,
  formatThaiOrderDate,
  type AppointmentOrderFull,
  type DigitFormatSettings,
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

function buildZipBlob(files: { path: string; content: string }[]): Blob {
  const encoder = new TextEncoder();
  const entries = files.map((f) => {
    const nameBytes = encoder.encode(f.path);
    const dataBytes = encoder.encode(f.content);
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

// --- OpenXML Paragraph & Table Builders (TH SarabunPSK 16pt) ---
function runPropsXml(bold = false): string {
  return `<w:rPr>
    <w:rFonts w:ascii="TH SarabunPSK" w:hAnsi="TH SarabunPSK" w:cs="TH SarabunPSK" w:eastAsia="TH SarabunPSK"/>
    ${bold ? '<w:b/><w:bCs/>' : ''}
    <w:sz w:val="32"/>
    <w:szCs w:val="32"/>
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

function memberTableXml(
  groupIndex: number,
  members: AppointmentOrderFull['groups'][number]['members'],
  useThaiMemberDigits: boolean,
): string {
  const rowsXml = members
    .map((m, mIdx) => {
      const subNo = `${formatDigits(groupIndex + 1, useThaiMemberDigits)}.${formatDigits(mIdx + 1, useThaiMemberDigits)}`;
      const fullName = `${subNo}  ${m.full_name.trim() || '....................................'}`;
      const pos = m.official_position.trim() || '........................';
      const role = m.working_role.trim() || 'คณะทำงาน';

      return `<w:tr>
        <w:tc>
          <w:tcPr><w:tcW w:w="3850" w:type="dxa"/></w:tcPr>
          ${paragraphXml(fullName, { afterTwips: 40 })}
        </w:tc>
        <w:tc>
          <w:tcPr><w:tcW w:w="2400" w:type="dxa"/></w:tcPr>
          ${paragraphXml(pos, { afterTwips: 40 })}
        </w:tc>
        <w:tc>
          <w:tcPr><w:tcW w:w="2101" w:type="dxa"/></w:tcPr>
          ${paragraphXml(role, { afterTwips: 40 })}
        </w:tc>
      </w:tr>`;
    })
    .join('');

  return `<w:tbl>
    <w:tblPr>
      <w:tblW w:w="8351" w:type="dxa"/>
      <w:tblInd w:w="720" w:type="dxa"/>
      <w:tblBorders>
        <w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>
        <w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>
      </w:tblBorders>
    </w:tblPr>
    <w:tblGrid>
      <w:gridCol w:w="3850"/>
      <w:gridCol w:w="2400"/>
      <w:gridCol w:w="2101"/>
    </w:tblGrid>
    ${rowsXml}
  </w:tbl>`;
}

/**
 * สร้างและดาวน์โหลดไฟล์ Microsoft Word (.docx) มาตรฐาน OpenXML
 * รองรับการตั้งค่าเลขอารบิก / เลขไทย แยกตามส่วนของเอกสาร
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
    const paragraphs = draft.preamble.split(/\r?\n/).filter((p) => p.trim());
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
    bodyParts.push(memberTableXml(gIdx, g.members, ds.memberNo));

    // หัวข้อ "หน้าที่"
    bodyParts.push(
      paragraphXml('หน้าที่', {
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
  bodyParts.push(
    paragraphXml(
      formatDigits(
        draft.effective_text || 'ทั้งนี้ ตั้งแต่บัดนี้เป็นต้นไป',
        ds.orderDate,
      ),
      {
        firstLineTwips: 1417,
        beforeTwips: 160,
        afterTwips: 80,
      },
    ),
  );
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
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    ${bodyParts.join('\n')}
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1701" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>`;

  const stylesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="TH SarabunPSK" w:hAnsi="TH SarabunPSK" w:cs="TH SarabunPSK" w:eastAsia="TH SarabunPSK"/>
        <w:sz w:val="32"/>
        <w:szCs w:val="32"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>`;

  const contentTypesXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>`;

  const rootRelsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>`;

  const docRelsXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>`;

  const blob = buildZipBlob([
    { path: '[Content_Types].xml', content: contentTypesXml },
    { path: '_rels/.rels', content: rootRelsXml },
    { path: 'word/_rels/document.xml.rels', content: docRelsXml },
    { path: 'word/document.xml', content: documentXml },
    { path: 'word/styles.xml', content: stylesXml },
  ]);

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
