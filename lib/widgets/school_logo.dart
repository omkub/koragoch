import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// โลโก้โรงเรียน (data URL จาก Schools.logo) — ไม่มีโลโก้ / ถอดรหัสไม่ได้
/// = ไอคอนโรงเรียนกลาง ๆ แทน
///
/// ตั้งโลโก้ที่เว็บส่วนกลาง > โรงเรียน (supabase/school_logo.sql)
class SchoolLogo extends StatelessWidget {
  final String? dataUrl;
  final double size;

  /// สีไอคอนสำรอง (หน้าล็อกอินพื้นเข้มใช้สีขาว)
  final Color iconColor;

  const SchoolLogo({
    super.key,
    required this.dataUrl,
    required this.size,
    this.iconColor = const Color(0xFF64748B),
  });

  static final Map<String, Uint8List> _cache = {};

  /// ถอด base64 ครั้งเดียวต่อรูป (rebuild บ่อย ไม่ต้องถอดใหม่ทุกครั้ง)
  static Uint8List? decode(String? dataUrl) {
    if (dataUrl == null || !dataUrl.startsWith('data:image')) return null;
    final cached = _cache[dataUrl];
    if (cached != null) return cached;
    final comma = dataUrl.indexOf(',');
    if (comma < 0) return null;
    try {
      final bytes = base64Decode(dataUrl.substring(comma + 1));
      if (_cache.length > 4) _cache.clear();
      return _cache[dataUrl] = bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = decode(dataUrl);
    if (bytes == null) {
      return Icon(Icons.school_rounded, size: size * 0.6, color: iconColor);
    }
    return Image.memory(bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.school_rounded, size: size * 0.6, color: iconColor));
  }
}
