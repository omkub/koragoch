/// โหลดแม่แบบฟอร์มที่ใช้จริงของโรงเรียน จากตาราง FormTemplates
///
/// ลำดับเดียวกับ web (resolveTemplate) และฟังก์ชัน current_form_template ในฐานข้อมูล:
///   แม่แบบของโรงเรียน → แม่แบบกลาง → แม่แบบเริ่มต้นในโค้ด
///
/// ไม่โยน error ออกไป — โหลดไม่ได้ก็ยังได้แม่แบบเริ่มต้น ใบลาพิมพ์ได้เสมอ
/// เก็บผลไว้ [cacheFor] ต่อ (ประเภทฟอร์ม, โรงเรียน) ไม่ต้องถามฐานข้อมูลทุกครั้งที่วาด
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../forms/default_templates.dart';
import '../forms/form_template.dart';
import '../utils/school_info.dart';

/// ที่มาของแม่แบบที่ได้
enum TemplateSource {
  /// แม่แบบเฉพาะโรงเรียน
  school,

  /// แม่แบบกลาง (ทุกโรงเรียนที่ไม่มีของตัวเอง)
  global,

  /// แม่แบบเริ่มต้นในโค้ด (ฐานข้อมูลยังไม่มี หรือโหลดไม่ได้)
  builtIn,
}

class ResolvedTemplate {
  final FormTemplate template;
  final TemplateSource source;

  /// เลขเวอร์ชันในฐานข้อมูล (null = แม่แบบเริ่มต้นในโค้ด)
  final int? version;

  const ResolvedTemplate(this.template, this.source, this.version);
}

/// แถวจาก current_form_template — 0 แถว = ยังไม่มีแม่แบบในฐานข้อมูล
typedef TemplateRowFetcher = Future<List<Map<String, dynamic>>> Function(
    FormType type, int? schoolId);

class FormTemplateService {
  FormTemplateService._(this._fetch);

  static final FormTemplateService instance =
      FormTemplateService._(_fetchFromSupabase);

  /// สำหรับเทส — ส่งตัวดึงข้อมูลปลอมเข้ามาแทนฐานข้อมูล
  @visibleForTesting
  factory FormTemplateService.withFetcher(TemplateRowFetcher fetch) =>
      FormTemplateService._(fetch);

  static const Duration cacheFor = Duration(minutes: 5);
  static const Duration _timeout = Duration(seconds: 8);

  final TemplateRowFetcher _fetch;
  final Map<String, ({ResolvedTemplate value, DateTime at})> _cache = {};
  final Map<String, Future<ResolvedTemplate>> _inFlight = {};

  static Future<List<Map<String, dynamic>>> _fetchFromSupabase(
      FormType type, int? schoolId) async {
    final rows = await Supabase.instance.client.rpc('current_form_template',
        params: {'p_form_type': type.key, 'p_school': schoolId});
    return [
      for (final r in rows as List) Map<String, dynamic>.from(r as Map),
    ];
  }

  /// แม่แบบที่ใช้จริงของ [type] สำหรับโรงเรียน [schoolId]
  /// (ไม่ส่ง = โรงเรียนของผู้ที่ล็อกอิน)
  ///
  /// [refresh] = ไม่ใช้ผลที่เก็บไว้ (เช่น หลังผู้ดูแลแก้แม่แบบที่ web)
  Future<ResolvedTemplate> resolve(FormType type,
      {int? schoolId, bool refresh = false, DateTime? now}) {
    final school = schoolId ?? SchoolInfo.currentSchoolId;
    final key = '${type.key}:${school ?? '-'}';
    final time = now ?? DateTime.now();

    final cached = _cache[key];
    if (!refresh && cached != null && time.difference(cached.at) < cacheFor) {
      return Future.value(cached.value);
    }
    // หลายหน้าจอขอพร้อมกัน = ถามฐานข้อมูลครั้งเดียว
    // (ห้ามเขียนแบบ => _inFlight.remove(key) เพราะจะคืน Future ตัวนี้เอง
    // ให้ whenComplete รอ — รอตัวเองไม่มีวันจบ)
    return _inFlight[key] ??= _load(type, school, key, time, cached?.value)
        .whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<ResolvedTemplate> _load(FormType type, int? school, String key,
      DateTime time, ResolvedTemplate? stale) async {
    final fallback = builtInTemplate(type);
    try {
      final rows = await _fetch(type, school).timeout(_timeout);
      final row = rows.isEmpty ? null : rows.first;
      final resolved = row == null || row['template'] == null
          ? ResolvedTemplate(fallback, TemplateSource.builtIn, null)
          : ResolvedTemplate(
              FormTemplate.normalize(row['template'], fallback),
              row['id_school'] == null
                  ? TemplateSource.global
                  : TemplateSource.school,
              row['version'] is int
                  ? row['version'] as int
                  : int.tryParse('${row['version']}'),
            );
      _cache[key] = (value: resolved, at: time);
      return resolved;
    } catch (e) {
      // ยังไม่ได้รัน form_templates.sql / เน็ตหลุด — ใช้ของเดิมที่เคยโหลด
      // ถ้าไม่เคยโหลดเลยใช้แม่แบบเริ่มต้น (ไม่เก็บผลนี้ไว้ ครั้งหน้าลองใหม่)
      debugPrint('⚠️  โหลดแม่แบบ${type.key}ไม่สำเร็จ ใช้แม่แบบสำรอง: $e');
      return stale ?? ResolvedTemplate(fallback, TemplateSource.builtIn, null);
    }
  }

  /// ล้างที่เก็บไว้ทั้งหมด (เช่น ตอนออกจากระบบ)
  void clearCache() => _cache.clear();
}
