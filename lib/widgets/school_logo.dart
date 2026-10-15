import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../utils/profile_image.dart';

/// โลโก้โรงเรียน (Schools.logo) — ไม่มีโลโก้ / โหลดไม่ขึ้น = ไอคอนโรงเรียนกลาง ๆ
///
/// ค่าในฐานข้อมูลเป็นลิงก์ Google Drive (โฟลเดอร์ LogoRPB ตั้งที่เว็บส่วนกลาง)
/// แสดงผ่านพร็อกซีแบบเดียวกับรูปโปรไฟล์ (profile_image.dart) ถ้าไม่ขึ้นลองลิงก์
/// สำรองของ Google — ค่าเก่าที่เป็น data URL ยังแสดงได้
class SchoolLogo extends StatefulWidget {
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
  State<SchoolLogo> createState() => _SchoolLogoState();
}

class _SchoolLogoState extends State<SchoolLogo> {
  // 0 = พร็อกซีหลัก, 1 = ลิงก์สำรองของ Google, 2 = ยอมแพ้ แสดงไอคอน
  int _attempt = 0;

  @override
  void didUpdateWidget(covariant SchoolLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataUrl != widget.dataUrl) _attempt = 0;
  }

  Widget get _fallback => Icon(Icons.school_rounded,
      size: widget.size * 0.6, color: widget.iconColor);

  @override
  Widget build(BuildContext context) {
    final raw = widget.dataUrl;
    final bytes = SchoolLogo.decode(raw);
    if (bytes != null) {
      return Image.memory(bytes,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _fallback);
    }

    String? url;
    if (raw != null && raw.startsWith('http') && _attempt < 2) {
      if (_attempt == 0) {
        url = resolveDisplayImageUrl(raw);
      } else {
        final id = extractDriveFileId(raw);
        url = id == null ? null : driveProxyUrl(id);
      }
    }
    if (url == null) return _fallback;

    return Image.network(
      url,
      // บนเว็บวาดผ่าน <img> ตรง ๆ เลี่ยง CORS ของ Google Drive
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        if (_attempt < 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _attempt++);
          });
        }
        return _fallback;
      },
    );
  }
}
