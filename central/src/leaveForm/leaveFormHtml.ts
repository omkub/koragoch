/**
 * แบบใบลาฉบับ HTML — แปลงมาจาก app แบบตัวอักษรต่อตัวอักษร
 *   lib/widgets/leave_form_html.dart (buildLeaveFormHtml)
 *
 * พาร์ท 1: ต้องได้ HTML ตรงกับ app ทุกตัวอักษรเมื่อป้อนข้อมูลชุดเดียวกัน
 * (เนื้อ HTML/CSS ด้านล่างดึงมาจากไฟล์ Dart ด้วยสคริปต์ ไม่ได้พิมพ์ใหม่)
 * พาร์ท 2 จะเปลี่ยนให้วาดจากแม่แบบแทน
 */
import { LeaveFormData, type LeaveStatRow } from './leaveFormData';

/** Dart HtmlEscape() (โหมด unknown) — escape & < > " ' / */
export function htmlEscape(value: unknown): string {
  const text = value === null || value === undefined ? '-' : String(value);
  return text.replace(/[&<>"'/]/g, (c) =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;', '/': '&#47;' })[c]!,
  );
}

function checkbox(label: string, checked: boolean): string {
  return '<span style="display: inline-flex; align-items: center; white-space: nowrap;">' +
    `<span class="check">${checked ? '✓' : ''}</span><span>${label}</span></span>`;
}

function statRowHtml(row: LeaveStatRow): string {
  return `<tr><td>${htmlEscape(row.label)}</td>` +
    `<td>${htmlEscape(row.previousTimes)}</td><td>${htmlEscape(row.previousDays)}</td>` +
    `<td>${htmlEscape(row.currentTimes)}</td><td>${htmlEscape(row.currentDays)}</td>` +
    `<td>${htmlEscape(row.totalTimes)}</td><td>${htmlEscape(row.totalDays)}</td></tr>`;
}

/**
 * สร้างหน้า HTML ของใบลาพร้อมพิมพ์ (buildLeaveFormHtml)
 * autoPrint = true จะเปิดหน้าต่างพิมพ์ให้เองเมื่อโหลดเสร็จ
 */
export function buildLeaveFormHtml(data: LeaveFormData, { autoPrint = false } = {}): string {
  const school = data.school;
  const fullName = htmlEscape(data.fullName);
  const position = htmlEscape(data.positionWithStanding);
  const applicantPosition = htmlEscape(data.position === '' ? '-' : data.position);
  const leaveType = htmlEscape(data.leaveTypeRaw);
  const reason = htmlEscape(data.reason);
  const phone = htmlEscape(data.phone);
  const startDate = htmlEscape(data.startDateText);
  const endDate = htmlEscape(data.endDateText);
  const totalDaysText = htmlEscape(data.totalDaysText);
  const latestStart = htmlEscape(data.latestStartText);
  const latestEnd = htmlEscape(data.latestEndText);
  const latestDays = htmlEscape(data.latestDaysText);
  const latestLabel = data.latestLeaveLabel;
  const requestDate =
    `${htmlEscape(data.requestDay)} ${htmlEscape(data.requestMonth)} ${htmlEscape(data.requestYear)}`;
  const hrName = htmlEscape(data.hrName);
  const deputyName = htmlEscape(data.deputyName);
  const directorName = htmlEscape(data.directorName);

  const receiveNumber = data.receiveNumber ?? '............................';
  const receiveDate = data.receiveDate ?? '............................';
  const receiveTime = data.receiveTime ?? '..............................';

  const leaveTypeChecks = data.printableLeaveTypes
    .map((t) => `<div class="checkline">${checkbox(htmlEscape(t), data.isSelectedLeaveType(t))}</div>`)
    .join('');

  const stats = data.statRows.map(statRowHtml).join('');

  // ความสูงของช่องติ๊ก = จำนวนบรรทัด × 22px + ช่องไฟระหว่างบรรทัด 2px
  const leaveTypeCount = data.printableLeaveTypes.length;
  const braceHeight = leaveTypeCount * 22 + (leaveTypeCount - 1) * 2;

  const printScript = autoPrint
    ? `<script>
  window.addEventListener('load', function() {
    setTimeout(function() {
      window.focus();
      window.print();
    }, 350);
  });
</script>
`
    : '';

  return `<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Leave-${fullName}</title>
  <style>
    @page { size: A4; margin: 0; }
    * { box-sizing: border-box; }
    body { margin: 0; background: #475569; font-family: "Sarabun", "TH Sarabun New", Tahoma, Arial, sans-serif; color: #111; }
    .page { width: 794px; min-height: 1123px; margin: 0 auto; padding: 42px 58px; background: white; font-size: 14px; line-height: 1.45; }
    .top { display: grid; grid-template-columns: 165px 1fr 180px; align-items: start; }
    h1 { text-align: center; font-size: 16px; margin: 0; text-decoration: underline; }
    h2 { text-align: center; font-size: 13px; margin: 0; font-weight: 400; }
    .receive { border: 1px solid #111; padding: 10px 12px; font-size: 12px; line-height: 1.8; }
    .school { text-align: center; margin: 18px 0 26px auto; width: 360px; }
    .school strong { font-weight: 700; }
    .row { display: flex; align-items: baseline; gap: 6px; margin: 4px 0; }
    .indent { padding-left: 58px; }
    .line { border-bottom: 1px dotted #aaa; min-height: 20px; padding: 0 8px 1px; text-align: center; font-weight: 600; display: inline-block; white-space: nowrap; }
    .grow { flex: 1; }
    .w40 { width: 40px; } .w60 { width: 60px; } .w80 { width: 80px; } .w130 { width: 130px; } .w150 { width: 150px; }
    .leave-block { display: grid; grid-template-columns: 78px 115px 62px 1fr; align-items: start; margin: 10px 0; }
    .checks { display: grid; gap: 2px; }
    .checkline { display: flex; align-items: center; gap: 7px; height: 22px; }
    .check { width: 14px; height: 14px; border: 1px solid #111; display: inline-flex; align-items: center; justify-content: center; font-size: 13px; line-height: 1; margin-right: 6px; }
    /* ปีกนกวาดเป็น SVG แล้วยืดเต็มกล่อง ความสูงของกล่องคำนวณจากจำนวน
       ประเภทการลา (ดู braceHeight ในโค้ด) จึงพอดีเสมอไม่ว่าจะมีกี่ประเภท
       ของเดิมใช้ตัวอักษร } ขนาดตายตัว 140px ซึ่งสูงเกินช่องติ๊กเกือบเท่าตัว */
    .brace { display: block; width: 26px; margin: 0 auto; }
    .brace svg { display: block; width: 100%; height: 100%; }
    .center { text-align: center; }
    .bottom { display: grid; grid-template-columns: 1fr 1.04fr; gap: 46px; margin-top: 28px; align-items: end; }
    .stats-title { text-align: center; font-weight: 700; font-size: 12px; margin-bottom: 8px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { border: 1px solid #333; padding: 4px 5px; text-align: center; font-size: 11px; line-height: 1.25; }
    .signature { text-align: center; margin-top: 14px; line-height: 1.35; }
    .comment { margin-top: 26px; font-size: 12px; font-weight: 700; }
    .order { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 22px; }
    .toolbar { position: fixed; right: 16px; top: 16px; }
    .toolbar button { padding: 8px 12px; border: 0; background: #0f172a; color: white; border-radius: 6px; cursor: pointer; }
    .reason-section { display: grid; grid-template-columns: max-content minmax(0, 1fr); column-gap: 6px; align-items: start; margin: 0 0 4px; min-width: 0; }
    .reason-label { grid-column: 1; white-space: nowrap; }
    .reason-text { grid-column: 2; min-width: 0; white-space: pre-wrap; overflow-wrap: anywhere; word-break: break-word; }
    .reason-underline { grid-column: 2; border-bottom: 1px dotted #aaa; margin-top: 4px; }
    @media print { body { background: white; } .toolbar { display: none; } .page { width: 210mm; min-height: 297mm; margin: 0; box-shadow: none; } }
  </style>
</head>
<body>
  <div class="toolbar"><button onclick="window.print()">พิมพ์ / บันทึก PDF</button></div>
  <main class="page">
    <section class="top">
      <div></div>
      <div><h1>แบบใบลา</h1><h2>ลาป่วย/ลากิจ/ลาคลอดบุตร</h2></div>
      <div class="receive">รับที่ ${receiveNumber}<br>วันที่ ${receiveDate}<br>เวลา ${receiveTime}</div>
    </section>

    <section class="school">
      <strong>${school.fullName}</strong><br>
      ${school.address}<br><br>
      วันที่ ${requestDate}
    </section>

    <div class="row"><strong>เรื่อง</strong><span class="line grow">ขอ${leaveType}</span></div>
    <div class="row">เรียน ผู้อำนวยการ${school.fullName}</div>
    <div class="row indent"><span>ข้าพเจ้า</span><span class="line grow">${fullName}</span><span>ตำแหน่ง</span><span class="line grow">${position}</span><span style="white-space: nowrap;">${school.namePart1}</span></div>
    <div class="row">${school.namePart2} ${school.affiliation}</div>

    <section class="leave-block">
      <strong>ขอลา</strong>
      <div class="checks">
        ${leaveTypeChecks}
      </div>
      <div class="brace" style="height: ${braceHeight}px">
        <svg viewBox="0 0 20 100" preserveAspectRatio="none" aria-hidden="true">
          <path d="M4 1 C13 1 11 9 11 22 C11 38 11 46 18 50 C11 54 11 62 11 78 C11 91 13 99 4 99"
                fill="none" stroke="rgba(0,0,0,0.55)" stroke-width="1.4"
                stroke-linecap="round" vector-effect="non-scaling-stroke" />
        </svg>
      </div>
      <div class="reason-section" style="padding-top: 34px;">
        <span class="reason-label">เนื่องจาก</span>
        <div class="reason-text">${reason}</div>
        <div class="reason-underline"></div>
      </div>
    </section>

    <div class="row"><span>ตั้งแต่วันที่</span><span class="line w150">${startDate}</span><span>ถึงวันที่</span><span class="line w150">${endDate}</span><span>มีกำหนด</span><span class="line w60">${totalDaysText}</span><span>วัน</span></div>
    <div class="row"><span>ข้าพเจ้าได้ลา</span><span>${checkbox('ป่วย', latestLabel === 'ป่วย')}</span><span>${checkbox('ลากิจส่วนตัว', latestLabel === 'ลากิจส่วนตัว')}</span><span>${checkbox('ลาคลอดบุตร', latestLabel === 'ลาคลอดบุตร')}</span><span>ครั้งสุดท้ายตั้งแต่วันที่</span><span class="line w130">${latestStart}</span></div>
    <div class="row"><span>ถึงวันที่</span><span class="line w130">${latestEnd}</span><span>มีกำหนด</span><span class="line w60">${latestDays}</span><span>วัน ในระหว่างที่ลาติดต่อข้าพเจ้าได้ที่</span><span class="line grow">${phone}</span></div>

    <p class="center" style="margin: 22px 0 0;">จึงเรียนมาเพื่อโปรดพิจารณา</p>

    <section class="bottom">
      <div>
        <div class="stats-title">สถิติวันลาในปีงบประมาณนี้</div>
        <table>
          <thead>
            <tr><th rowspan="2">ประเภทการลา</th><th colspan="2">ลามาแล้ว</th><th colspan="2">ลาครั้งนี้</th><th colspan="2">รวมเป็น</th></tr>
            <tr><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th><th>ครั้ง</th><th>วัน</th></tr>
          </thead>
          <tbody>${stats}</tbody>
        </table>
        <div class="signature">ลงชื่อ ..................................................<br>${hrName}<br>หัวหน้ากลุ่มบริหารงานบุคคล<br>........../........../..........</div>
      </div>
      <div>
        <div class="signature" style="margin-top:0;">ขอแสดงความนับถือ<br><br>ลงชื่อ ..................................................<br>( ${fullName} )<br>ตำแหน่ง ${applicantPosition}</div>
        <div class="comment">ความคิดเห็น</div><div class="line grow" style="width:100%; margin-top:4px;"></div>
        <div class="signature">ลงชื่อ ..................................................<br>${deputyName}<br>รองผู้อำนวยการกลุ่มบริหารงานบุคคล<br>........../........../..........</div>
        <div class="order"><strong>คำสั่ง</strong><span>${checkbox('อนุญาต', false)}</span><span>${checkbox('ไม่อนุญาต', false)}</span></div>
        <div class="signature">ลงชื่อ ..................................................<br>${directorName}<br>ผู้อำนวยการ${school.fullName}<br>........../........../..........</div>
      </div>
    </section>
  </main>
${printScript}
</body>
</html>
`;
}
