// ไฟล์นี้สร้างอัตโนมัติจาก central/src/forms (leaveTemplate.ts / tripTemplate.ts)
// ห้ามแก้ด้วยมือ — แก้ที่ web แล้วรัน: cd central && npm run form-defaults
// ignore_for_file: lines_longer_than_80_chars

/// แม่แบบเริ่มต้นของใบลา (JSON เดียวกับ defaultLeaveTemplate() ใน web)
const String defaultLeaveTemplateJson = r'''
{
  "schema": 1,
  "formType": "leave",
  "paper": {
    "size": "A4",
    "widthMm": 210,
    "heightMm": 297,
    "orientation": "portrait",
    "margin": {
      "top": 11.1125,
      "right": 15.3458,
      "bottom": 11.1125,
      "left": 15.3458
    },
    "fontFamily": "\"Sarabun\", \"TH Sarabun New\", Tahoma, Arial, sans-serif",
    "fontSizePt": 10.5,
    "lineHeight": 1.45,
    "fitToPage": false
  },
  "blocks": [
    {
      "id": "leave-1",
      "name": "หัวเอกสาร + กล่องรับที่",
      "visible": true,
      "spaceBeforeMm": 0,
      "spaceAfterMm": 0,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "header",
      "title": "แบบใบลา",
      "subtitle": "ลาป่วย/ลากิจ/ลาคลอดบุตร",
      "showReceiveBox": true,
      "receiveLines": [
        "รับที่ {เลขรับ}",
        "วันที่ {วันที่รับ}",
        "เวลา {เวลารับ}"
      ]
    },
    {
      "id": "leave-2",
      "name": "ชื่อโรงเรียน / วันที่เขียน",
      "visible": true,
      "spaceBeforeMm": 4.7625,
      "spaceAfterMm": 6.8792,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": "center",
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "textBox",
      "lines": [
        "**{โรงเรียน}**",
        "{ที่อยู่โรงเรียน}",
        "",
        "วันที่ [[{วันที่ยื่น-วัน}]] [[{วันที่ยื่น-เดือน}]] [[{วันที่ยื่น-ปี}]]"
      ],
      "boxWidthMm": 95.25,
      "boxPosition": "right",
      "firstLineIndentMm": 0
    },
    {
      "id": "leave-3",
      "name": "เรื่อง",
      "visible": true,
      "spaceBeforeMm": 1.0583,
      "spaceAfterMm": 1.0583,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "เรื่อง",
          "bold": true
        },
        {
          "kind": "field",
          "text": "ขอ{ประเภทการลา}",
          "widthMm": null
        }
      ]
    },
    {
      "id": "leave-4",
      "name": "เรียน",
      "visible": true,
      "spaceBeforeMm": 1.0583,
      "spaceAfterMm": 1.0583,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "เรียน ผู้อำนวยการ{โรงเรียน}"
        }
      ]
    },
    {
      "id": "leave-5",
      "name": "ข้าพเจ้า / ตำแหน่ง",
      "visible": true,
      "spaceBeforeMm": 1.0583,
      "spaceAfterMm": 1.0583,
      "minHeightMm": null,
      "indentMm": 15.3458,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "ข้าพเจ้า"
        },
        {
          "kind": "field",
          "text": "{ชื่อ}",
          "widthMm": null
        },
        {
          "kind": "text",
          "text": "ตำแหน่ง"
        },
        {
          "kind": "field",
          "text": "{ตำแหน่งและวิทยฐานะ}",
          "widthMm": null
        },
        {
          "kind": "text",
          "text": "{โรงเรียน-ส่วน1}",
          "nowrap": true
        }
      ]
    },
    {
      "id": "leave-6",
      "name": "สังกัด",
      "visible": true,
      "spaceBeforeMm": 1.0583,
      "spaceAfterMm": 1.0583,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "{โรงเรียน-ส่วน2} {สังกัด}"
        }
      ]
    },
    {
      "id": "leave-7",
      "name": "ประเภทการลา / เหตุผล",
      "visible": true,
      "spaceBeforeMm": 2.6458,
      "spaceAfterMm": 2.6458,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "leaveTypes",
      "label": "ขอลา",
      "reasonLabel": "เนื่องจาก",
      "showBrace": true
    },
    {
      "id": "leave-8",
      "name": "ช่วงวันลา",
      "visible": true,
      "spaceBeforeMm": 1.0583,
      "spaceAfterMm": 1.0583,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "ตั้งแต่วันที่"
        },
        {
          "kind": "field",
          "text": "{วันที่เริ่ม}",
          "widthMm": 39.6875
        },
        {
          "kind": "text",
          "text": "ถึงวันที่"
        },
        {
          "kind": "field",
          "text": "{วันที่สิ้นสุด}",
          "widthMm": 39.6875
        },
        {
          "kind": "text",
          "text": "มีกำหนด"
        },
        {
          "kind": "field",
          "text": "{จำนวนวัน}",
          "widthMm": 15.875
        },
        {
          "kind": "text",
          "text": "วัน"
        }
      ]
    },
    {
      "id": "leave-9",
      "name": "ลาครั้งล่าสุด",
      "visible": true,
      "spaceBeforeMm": 1.0583,
      "spaceAfterMm": 1.0583,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "ข้าพเจ้าได้ลา"
        },
        {
          "kind": "checkbox",
          "label": "ป่วย",
          "flag": "ลาครั้งล่าสุด=ป่วย"
        },
        {
          "kind": "checkbox",
          "label": "ลากิจส่วนตัว",
          "flag": "ลาครั้งล่าสุด=ลากิจส่วนตัว"
        },
        {
          "kind": "checkbox",
          "label": "ลาคลอดบุตร",
          "flag": "ลาครั้งล่าสุด=ลาคลอดบุตร"
        },
        {
          "kind": "text",
          "text": "ครั้งสุดท้ายตั้งแต่วันที่"
        },
        {
          "kind": "field",
          "text": "{ลาครั้งล่าสุด-เริ่ม}",
          "widthMm": 34.3958
        }
      ]
    },
    {
      "id": "leave-10",
      "name": "ลาครั้งล่าสุด (ต่อ) / ติดต่อ",
      "visible": true,
      "spaceBeforeMm": 1.0583,
      "spaceAfterMm": 1.0583,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "ถึงวันที่"
        },
        {
          "kind": "field",
          "text": "{ลาครั้งล่าสุด-สิ้นสุด}",
          "widthMm": 34.3958
        },
        {
          "kind": "text",
          "text": "มีกำหนด"
        },
        {
          "kind": "field",
          "text": "{ลาครั้งล่าสุด-จำนวนวัน}",
          "widthMm": 15.875
        },
        {
          "kind": "text",
          "text": "วัน ในระหว่างที่ลาติดต่อข้าพเจ้าได้ที่"
        },
        {
          "kind": "field",
          "text": "{เบอร์โทร}",
          "widthMm": null
        }
      ]
    },
    {
      "id": "leave-11",
      "name": "จึงเรียนมา",
      "visible": true,
      "spaceBeforeMm": 5.8208,
      "spaceAfterMm": 0,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": "center",
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "จึงเรียนมาเพื่อโปรดพิจารณา"
        }
      ]
    },
    {
      "id": "leave-12",
      "name": "สถิติวันลา + ลงนามอนุมัติ",
      "visible": true,
      "spaceBeforeMm": 7.4083,
      "spaceAfterMm": 0,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "approval",
      "showStats": true,
      "statsTitle": "สถิติวันลาในปีงบประมาณนี้",
      "hrLines": [
        "ลงชื่อ ..................................................",
        "{หัวหน้าบุคคล}",
        "หัวหน้ากลุ่มบริหารงานบุคคล",
        "........../........../.........."
      ],
      "applicantLines": [
        "ขอแสดงความนับถือ",
        "",
        "ลงชื่อ ..................................................",
        "( {ชื่อ} )",
        "ตำแหน่ง {ตำแหน่งผู้ลา}"
      ],
      "showComment": true,
      "commentLabel": "ความคิดเห็น",
      "deputyLines": [
        "ลงชื่อ ..................................................",
        "{รองผอ.บุคคล}",
        "รองผู้อำนวยการกลุ่มบริหารงานบุคคล",
        "........../........../.........."
      ],
      "showOrder": true,
      "orderLabel": "คำสั่ง",
      "orderOptions": [
        "อนุญาต",
        "ไม่อนุญาต"
      ],
      "directorLines": [
        "ลงชื่อ ..................................................",
        "{ผู้อำนวยการ}",
        "ผู้อำนวยการ{โรงเรียน}",
        "........../........../.........."
      ]
    }
  ]
}
''';

/// แม่แบบเริ่มต้นของใบขออนุญาตไปราชการ (JSON เดียวกับ defaultTripTemplate() ใน web)
const String defaultTripTemplateJson = r'''
{
  "schema": 1,
  "formType": "trip",
  "paper": {
    "size": "A4",
    "widthMm": 210,
    "heightMm": 297,
    "orientation": "portrait",
    "margin": {
      "top": 20,
      "right": 20,
      "bottom": 20,
      "left": 30
    },
    "fontFamily": "\"Sarabun\", \"TH Sarabun New\", Tahoma, Arial, sans-serif",
    "fontSizePt": 12,
    "lineHeight": 1.6,
    "fitToPage": false
  },
  "blocks": [
    {
      "id": "trip-1",
      "name": "หัวเรื่อง \"บันทึกข้อความ\"",
      "visible": true,
      "spaceBeforeMm": 0,
      "spaceAfterMm": 4,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": "center",
      "fontSizePt": 20,
      "bold": true,
      "underline": false,
      "builtIn": true,
      "type": "textBox",
      "lines": [
        "บันทึกข้อความ"
      ],
      "boxWidthMm": null,
      "boxPosition": "left",
      "firstLineIndentMm": 0
    },
    {
      "id": "trip-2",
      "name": "ส่วนราชการ",
      "visible": true,
      "spaceBeforeMm": null,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "ส่วนราชการ",
          "bold": true,
          "nowrap": true
        },
        {
          "kind": "field",
          "text": "{โรงเรียน} {ที่อยู่โรงเรียน}",
          "widthMm": null
        }
      ]
    },
    {
      "id": "trip-3",
      "name": "ที่ / วันที่",
      "visible": true,
      "spaceBeforeMm": null,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "ที่",
          "bold": true,
          "nowrap": true
        },
        {
          "kind": "field",
          "text": "",
          "widthMm": 60
        },
        {
          "kind": "text",
          "text": "วันที่",
          "bold": true,
          "nowrap": true
        },
        {
          "kind": "field",
          "text": "{วันที่ยื่น}",
          "widthMm": null
        }
      ]
    },
    {
      "id": "trip-4",
      "name": "เรื่อง",
      "visible": true,
      "spaceBeforeMm": null,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "เรื่อง",
          "bold": true,
          "nowrap": true
        },
        {
          "kind": "field",
          "text": "ขออนุญาตไปราชการ",
          "widthMm": null
        }
      ]
    },
    {
      "id": "trip-5",
      "name": "เรียน",
      "visible": true,
      "spaceBeforeMm": 4,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "เรียน ผู้อำนวยการ{โรงเรียน}"
        }
      ]
    },
    {
      "id": "trip-6",
      "name": "เนื้อความ",
      "visible": true,
      "spaceBeforeMm": 3,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": "justify",
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "textBox",
      "lines": [
        "ด้วย {หน่วยงานที่จัด} ได้มีหนังสือที่ {เลขที่หนังสือ} ลงวันที่ {วันที่หนังสือ} แจ้งให้เข้าร่วม{ประเภท} เรื่อง {เรื่อง} ณ {สถานที่} {จังหวัด} ในวันที่ {ช่วงวันที่} ({ช่วงเวลา}) รวม {จำนวนวัน} วันทำการ"
      ],
      "boxWidthMm": null,
      "boxPosition": "left",
      "firstLineIndentMm": 25
    },
    {
      "id": "trip-7",
      "name": "ขออนุญาต",
      "visible": true,
      "spaceBeforeMm": null,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": "justify",
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "textBox",
      "lines": [
        "ในการนี้ ข้าพเจ้าจึงขออนุญาตไปราชการดังกล่าว พร้อมด้วยผู้มีรายชื่อต่อไปนี้ รวม {จำนวนผู้ร่วมเดินทาง} คน"
      ],
      "boxWidthMm": null,
      "boxPosition": "left",
      "firstLineIndentMm": 25
    },
    {
      "id": "trip-8",
      "name": "ตารางผู้ร่วมเดินทาง",
      "visible": true,
      "spaceBeforeMm": null,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "memberTable",
      "showPosition": true,
      "showSignature": false,
      "headers": {
        "no": "ที่",
        "name": "ชื่อ - สกุล",
        "position": "ตำแหน่ง",
        "signature": "ลายมือชื่อ"
      }
    },
    {
      "id": "trip-9",
      "name": "การเดินทาง / ค่าใช้จ่าย",
      "visible": true,
      "spaceBeforeMm": null,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "textBox",
      "lines": [
        "โดยเดินทางด้วย {การเดินทาง} ค่าใช้จ่าย {แหล่งค่าใช้จ่าย} {ค่าใช้จ่าย}"
      ],
      "boxWidthMm": null,
      "boxPosition": "left",
      "firstLineIndentMm": 25
    },
    {
      "id": "trip-10",
      "name": "จึงเรียนมา",
      "visible": true,
      "spaceBeforeMm": 3,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "textBox",
      "lines": [
        "จึงเรียนมาเพื่อโปรดพิจารณาอนุญาต"
      ],
      "boxWidthMm": null,
      "boxPosition": "left",
      "firstLineIndentMm": 25
    },
    {
      "id": "trip-11",
      "name": "ลงชื่อผู้ขออนุญาต",
      "visible": true,
      "spaceBeforeMm": 8,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "signature",
      "lines": [
        "ลงชื่อ ..................................................",
        "( {ชื่อ} )",
        "ตำแหน่ง {ตำแหน่ง}"
      ],
      "boxWidthMm": 90,
      "boxPosition": "right"
    },
    {
      "id": "trip-12",
      "name": "ความเห็นผู้บังคับบัญชา",
      "visible": true,
      "spaceBeforeMm": 6,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "textBox",
      "lines": [
        "**ความเห็นของผู้บังคับบัญชา**",
        ".................................................................................................."
      ],
      "boxWidthMm": null,
      "boxPosition": "left",
      "firstLineIndentMm": 0
    },
    {
      "id": "trip-13",
      "name": "คำสั่ง",
      "visible": true,
      "spaceBeforeMm": 4,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "row",
      "segments": [
        {
          "kind": "text",
          "text": "คำสั่ง",
          "bold": true,
          "nowrap": true
        },
        {
          "kind": "checkbox",
          "label": "อนุญาต",
          "flag": "อนุมัติแล้ว"
        },
        {
          "kind": "checkbox",
          "label": "ไม่อนุญาต",
          "flag": "ไม่อนุมัติ"
        }
      ]
    },
    {
      "id": "trip-14",
      "name": "ลงชื่อผู้อำนวยการ",
      "visible": true,
      "spaceBeforeMm": 6,
      "spaceAfterMm": null,
      "minHeightMm": null,
      "indentMm": null,
      "offsetXMm": 0,
      "offsetYMm": 0,
      "align": null,
      "fontSizePt": null,
      "bold": false,
      "underline": false,
      "builtIn": true,
      "type": "signature",
      "lines": [
        "ลงชื่อ ..................................................",
        "{ผู้อำนวยการ}",
        "ผู้อำนวยการ{โรงเรียน}",
        "........../........../.........."
      ],
      "boxWidthMm": 90,
      "boxPosition": "right"
    }
  ]
}
''';
