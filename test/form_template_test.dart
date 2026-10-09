import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_leave_app/forms/default_templates.dart';
import 'package:school_leave_app/forms/default_templates.g.dart';
import 'package:school_leave_app/forms/form_template.dart';
import 'package:school_leave_app/services/form_template_service.dart';

Map<String, dynamic> _json(String s) => jsonDecode(s) as Map<String, dynamic>;

/// แม่แบบเริ่มต้นแบบ JSON (สำเนาใหม่ทุกครั้ง แก้ได้ไม่กระทบเทสอื่น)
Map<String, dynamic> _leaveJson() => _json(defaultLeaveTemplateJson);

void main() {
  group('แม่แบบเริ่มต้นจาก web', () {
    for (final (type, raw) in [
      (FormType.leave, defaultLeaveTemplateJson),
      (FormType.trip, defaultTripTemplateJson),
    ]) {
      test('${type.key}: อ่านแล้วเขียนกลับได้ JSON เดิมทุกช่อง', () {
        // ถ้าไม่ตรง = web เพิ่มช่องใหม่ที่ model ฝั่ง app ยังไม่รู้จัก
        expect(builtInTemplate(type).toJson(), _json(raw));
      });
    }

    test('ใบลามีครบทุกชนิดบรรทัดที่ใบลาใช้', () {
      final types = builtInTemplate(FormType.leave).blocks.map((b) => b.type);
      expect(types, containsAll(['header', 'textBox', 'row', 'leaveTypes', 'approval']));
    });

    test('ใบไปราชการมีตารางผู้ร่วมเดินทางและช่องลงชื่อ', () {
      final types = builtInTemplate(FormType.trip).blocks.map((b) => b.type);
      expect(types, containsAll(['memberTable', 'signature', 'textBox', 'row']));
    });
  });

  group('normalize — อ่านแม่แบบจากฐานข้อมูลอย่างปลอดภัย', () {
    final fallback = builtInTemplate(FormType.leave);

    test('ไม่ใช่ object / ประเภทไม่ตรง / ไม่มีรายการบรรทัด = แม่แบบเริ่มต้น', () {
      expect(FormTemplate.normalize(null, fallback), same(fallback));
      expect(FormTemplate.normalize('x', fallback), same(fallback));
      expect(FormTemplate.normalize({..._leaveJson(), 'formType': 'trip'}, fallback),
          same(fallback));
      expect(FormTemplate.normalize({..._leaveJson(), 'blocks': 'x'}, fallback),
          same(fallback));
    });

    test('แม่แบบที่ถูกต้องอ่านได้ครบเหมือนเดิม', () {
      final raw = _leaveJson();
      expect(FormTemplate.normalize(raw, fallback).toJson(), raw);
    });

    test('ตั้งค่ากระดาษที่ขาด ใช้ค่าของแม่แบบเริ่มต้น', () {
      final t = FormTemplate.normalize({
        'formType': 'leave',
        'paper': {
          'fontSizePt': 14,
          'margin': {'top': 30},
        },
        'blocks': [],
      }, fallback);
      expect(t.paper.fontSizePt, 14);
      expect(t.paper.margin.top, 30);
      expect(t.paper.margin.left, fallback.paper.margin.left);
      expect(t.paper.size, 'A4');
      expect(t.paper.lineHeight, fallback.paper.lineHeight);
    });

    test('ช่องของบรรทัดที่ขาด ใช้ค่าตั้งต้น (บันทึกก่อนมีฟีเจอร์ใหม่)', () {
      final t = FormTemplate.normalize({
        'formType': 'leave',
        'blocks': [
          {
            'type': 'row',
            'id': 'r1',
            'segments': [
              {'kind': 'field', 'text': '{ชื่อ}', 'widthMm': null},
              {'kind': 'text', 'text': 'เรื่อง', 'bold': true},
            ],
          },
        ],
      }, fallback);
      final row = t.blocks.single as RowBlock;
      expect(row.common.visible, isTrue);
      expect(row.common.spaceBeforeMm, isNull);
      expect(row.common.offsetXMm, 0);
      expect(row.common.align, isNull);
      final field = row.segments[0] as FieldSegment;
      expect(field.noLine, isFalse);
      expect(field.widthMm, isNull);
      expect((row.segments[1] as TextSegment).bold, isTrue);
    });

    test('ค่าที่ใช้ไม่ได้ไม่ทำให้ล้ม', () {
      final t = FormTemplate.normalize({
        'formType': 'leave',
        'paper': {'fontSizePt': 'ใหญ่', 'margin': 5},
        'blocks': [
          {'type': 'row', 'align': 'กลาง', 'spaceBeforeMm': '3', 'segments': 'x'},
          {'type': 'textBox', 'lines': ['ก', 1, null, 'ข'], 'boxPosition': 'บน'},
          {
            'type': 'row',
            'segments': [
              {'kind': 'อะไร'},
              {'kind': 'checkbox', 'label': 'อนุญาต', 'flag': 'อนุมัติแล้ว'},
            ],
          },
        ],
      }, fallback);
      expect(t.paper.fontSizePt, fallback.paper.fontSizePt);
      expect(t.paper.margin.top, fallback.paper.margin.top);
      final row = t.blocks[0] as RowBlock;
      expect(row.common.align, isNull);
      expect(row.common.spaceBeforeMm, isNull);
      expect(row.segments, isEmpty);
      final box = t.blocks[1] as TextBoxBlock;
      expect(box.lines, ['ก', 'ข']);
      expect(box.boxPosition, 'left');
      expect((t.blocks[2] as RowBlock).segments.single, isA<CheckboxSegment>());
    });

    test('ชนิดบรรทัดที่ app ยังไม่รู้จัก ข้ามไป ไม่ทำให้ทั้งแม่แบบใช้ไม่ได้', () {
      final raw = _leaveJson();
      (raw['blocks'] as List).insert(1, {'type': 'qrCode', 'id': 'q1'});
      final t = FormTemplate.normalize(raw, fallback);
      expect(t.blocks.length, fallback.blocks.length);
    });

    test('ค่าที่ตั้งจาก web (ปิดเส้นประ / ช่องเส้นประในบรรทัด) อ่านได้ครบ', () {
      final raw = _leaveJson();
      final blocks = raw['blocks'] as List;
      final subject = blocks.firstWhere((b) => b['name'] == 'เรื่อง') as Map;
      (subject['segments'] as List)[1]['noLine'] = true;
      final t = FormTemplate.normalize(raw, fallback);
      final row = t.blocks.firstWhere((b) => b.common.name == 'เรื่อง') as RowBlock;
      expect((row.segments[1] as FieldSegment).noLine, isTrue);
      final box = t.blocks.whereType<TextBoxBlock>().first;
      expect(box.lines.last, contains('[[{วันที่ยื่น-วัน}]]'));
      expect(t.toJson(), raw);
    });
  });

  test('ขนาดกระดาษตามแนว', () {
    final p = builtInTemplate(FormType.leave).paper;
    expect(p.dimensions, (widthMm: 210.0, heightMm: 297.0));
    final landscape = p.merge({'orientation': 'landscape', 'size': 'A5'});
    expect(landscape.dimensions, (widthMm: 210.0, heightMm: 148.0));
    final custom = p.merge({'size': 'custom', 'widthMm': 300, 'heightMm': 100});
    expect(custom.dimensions, (widthMm: 100.0, heightMm: 300.0));
  });

  group('FormTemplateService', () {
    final t0 = DateTime(2026, 10, 10, 9);

    Map<String, dynamic> row({int? school, int version = 3, Object? template}) => {
          'id_template': 1,
          'id_school': school,
          'version': version,
          'template': template ?? _leaveJson(),
        };

    test('ฐานข้อมูลยังไม่มีแม่แบบ = แม่แบบเริ่มต้น', () async {
      final s = FormTemplateService.withFetcher((_, __) async => []);
      final r = await s.resolve(FormType.leave, schoolId: 1, now: t0);
      expect(r.source, TemplateSource.builtIn);
      expect(r.version, isNull);
      expect(r.template, same(builtInTemplate(FormType.leave)));
    });

    test('แม่แบบกลาง / แม่แบบของโรงเรียน บอกที่มาและเวอร์ชัน', () async {
      final global = FormTemplateService.withFetcher((_, __) async => [row()]);
      final g = await global.resolve(FormType.leave, schoolId: 1, now: t0);
      expect(g.source, TemplateSource.global);
      expect(g.version, 3);

      final own = FormTemplateService.withFetcher(
          (_, __) async => [row(school: 1, version: 7)]);
      final o = await own.resolve(FormType.leave, schoolId: 1, now: t0);
      expect(o.source, TemplateSource.school);
      expect(o.version, 7);
    });

    test('ส่งประเภทฟอร์มและโรงเรียนไปถามฐานข้อมูล', () async {
      final asked = <String>[];
      final s = FormTemplateService.withFetcher((type, school) async {
        asked.add('${type.key}:$school');
        return [];
      });
      await s.resolve(FormType.trip, schoolId: 5, now: t0);
      expect(asked, ['trip:5']);
    });

    test('เก็บผลไว้ใช้ซ้ำ หมดเวลาแล้วถามใหม่ / refresh ถามใหม่ทันที', () async {
      var calls = 0;
      final s = FormTemplateService.withFetcher((_, __) async {
        calls++;
        return [row()];
      });
      await s.resolve(FormType.leave, schoolId: 1, now: t0);
      await s.resolve(FormType.leave, schoolId: 1, now: t0.add(const Duration(minutes: 4)));
      expect(calls, 1);
      await s.resolve(FormType.leave, schoolId: 2, now: t0);
      expect(calls, 2, reason: 'คนละโรงเรียน เก็บแยกกัน');
      await s.resolve(FormType.leave, schoolId: 1, now: t0.add(const Duration(minutes: 6)));
      expect(calls, 3);
      await s.resolve(FormType.leave, schoolId: 1, refresh: true, now: t0.add(const Duration(minutes: 6)));
      expect(calls, 4);
    });

    test('หลายหน้าจอขอพร้อมกัน ถามฐานข้อมูลครั้งเดียว', () async {
      var calls = 0;
      final s = FormTemplateService.withFetcher((_, __) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return [row()];
      });
      final results = await Future.wait([
        s.resolve(FormType.leave, schoolId: 1, now: t0),
        s.resolve(FormType.leave, schoolId: 1, now: t0),
      ]);
      expect(calls, 1);
      expect(results[0], same(results[1]));
    });

    test('โหลดไม่ได้ = แม่แบบเริ่มต้น ไม่ล้ม และลองใหม่หลัง 30 วินาที', () async {
      var fail = true;
      var calls = 0;
      final s = FormTemplateService.withFetcher((_, __) async {
        calls++;
        if (fail) throw Exception('เน็ตหลุด');
        return [row()];
      });
      final r1 = await s.resolve(FormType.leave, schoolId: 1, now: t0);
      expect(r1.source, TemplateSource.builtIn);
      // ปุ่มพิมพ์ต้องกดได้แม้โหลดไม่สำเร็จ (ใช้แม่แบบเริ่มต้นไปก่อน)
      expect(s.cached(FormType.leave, schoolId: 1)?.source,
          TemplateSource.builtIn);

      fail = false;
      final r2 = await s.resolve(FormType.leave, schoolId: 1,
          now: t0.add(const Duration(seconds: 10)));
      expect(r2.source, TemplateSource.builtIn, reason: 'ยังไม่ถึงเวลาลองใหม่');
      expect(calls, 1);

      final r3 = await s.resolve(FormType.leave, schoolId: 1,
          now: t0.add(const Duration(seconds: 31)));
      expect(r3.source, TemplateSource.global);
      expect(calls, 2);
    });

    test('เคยโหลดได้แล้ว รอบถัดไปโหลดไม่ได้ = ใช้ของเดิม', () async {
      var fail = false;
      final s = FormTemplateService.withFetcher((_, __) async {
        if (fail) throw Exception('เน็ตหลุด');
        return [row(school: 1, version: 9)];
      });
      await s.resolve(FormType.leave, schoolId: 1, now: t0);
      fail = true;
      final r = await s.resolve(FormType.leave, schoolId: 1,
          now: t0.add(const Duration(minutes: 10)));
      expect(r.source, TemplateSource.school);
      expect(r.version, 9);
    });

    test('แม่แบบในฐานข้อมูลเสีย = ใช้แม่แบบเริ่มต้นแทนทั้งชุด', () async {
      final s = FormTemplateService.withFetcher(
          (_, __) async => [row(template: {'formType': 'trip', 'blocks': []})]);
      final r = await s.resolve(FormType.leave, schoolId: 1, now: t0);
      expect(r.template, same(builtInTemplate(FormType.leave)));
    });
  });
}
