/// ตัววาดของ app (lib/forms/form_render.dart) ต้องได้ HTML เดียวกับตัววาดของ web
/// (central/src/forms/render.ts) ทุกตัวอักษร
///
/// ชุดทดสอบ + HTML ที่ถูกต้องสร้างจาก web: cd central && npm run form-fixtures
/// (กรณีทดสอบอยู่ที่ central/scripts/form-render-cases.ts)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/forms/default_templates.dart';
import 'package:school_leave_app/forms/form_render.dart';
import 'package:school_leave_app/forms/form_template.dart';
import 'package:school_leave_app/widgets/leave_form_data.dart';

RenderContext _context(Map<String, dynamic> c) {
  String s(Object? v) => v?.toString() ?? '';
  return RenderContext(
    title: s(c['title']),
    values: {
      for (final e in (c['values'] as Map? ?? const {}).entries)
        e.key.toString(): s(e.value),
    },
    flags: {
      for (final e in (c['flags'] as Map? ?? const {}).entries)
        e.key.toString(): e.value == true,
    },
    leaveTypes: (c['leaveTypes'] as List?)
        ?.map((t) => (label: s(t['label']), checked: t['checked'] == true))
        .toList(),
    reason: c['reason'] as String?,
    stats: (c['stats'] as List?)
        ?.map((r) => LeaveStatRow(
              label: s(r['label']),
              previousTimes: s(r['previousTimes']),
              previousDays: s(r['previousDays']),
              currentTimes: s(r['currentTimes']),
              currentDays: s(r['currentDays']),
              totalTimes: s(r['totalTimes']),
              totalDays: s(r['totalDays']),
            ))
        .toList(),
    members: (c['members'] as List?)
        ?.map((m) => (name: s(m['name']), position: s(m['position'])))
        .toList(),
  );
}

RenderOptions _options(Map<String, dynamic> o) => RenderOptions(
      toolbar: o['toolbar'] == true,
      autoPrint: o['autoPrint'] == true,
      editor: o['editor'] == true,
      selectedBlockId: o['selectedBlockId'] as String?,
    );

/// บอกตำแหน่งแรกที่ต่าง พร้อมข้อความรอบ ๆ — อ่านง่ายกว่าเทียบสตริงยาวทั้งก้อน
String? _firstDifference(String actual, String expected) {
  if (actual == expected) return null;
  var i = 0;
  while (i < actual.length && i < expected.length && actual[i] == expected[i]) {
    i++;
  }
  String around(String s) =>
      s.substring((i - 80).clamp(0, s.length), (i + 80).clamp(0, s.length));
  return 'ต่างกันที่ตัวอักษรที่ $i\n'
      '--- web ---\n${around(expected)}\n'
      '--- app ---\n${around(actual)}';
}

void main() {
  final cases = jsonDecode(
          File('test/fixtures/form_render_cases.json').readAsStringSync())
      as List;

  test('มีชุดทดสอบจาก web', () => expect(cases, isNotEmpty));

  for (final raw in cases.cast<Map<String, dynamic>>()) {
    test(raw['name'], () {
      final tpl = raw['template'] as Map<String, dynamic>;
      final type = FormType.fromKey(tpl['formType'])!;
      final template = FormTemplate.normalize(tpl, builtInTemplate(type));
      expect(template.blocks.length, (tpl['blocks'] as List).length,
          reason: 'อ่านบรรทัดของแม่แบบได้ไม่ครบ');

      final html = renderDocument(
        template,
        _context(raw['context'] as Map<String, dynamic>),
        _options(raw['options'] as Map<String, dynamic>),
      );
      final diff = _firstDifference(html, raw['html'] as String);
      expect(diff, isNull, reason: diff);
    });
  }

  test('ตัวเลขเขียนแบบ JavaScript', () {
    expect(jsNum(10), '10');
    expect(jsNum(10.0), '10');
    expect(jsNum(-0.0), '0');
    expect(jsNum(10.5), '10.5');
    expect(jsNum(0.1 + 0.2), '0.30000000000000004');
    expect(jsNum(15.3458), '15.3458');
  });
}
