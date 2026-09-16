// ═══════════════════════════════════════════════════════════════
// ตัวกลางจัดการ "ลิงก์รูป" จากฐานข้อมูล (รูปโปรไฟล์ / ใบรับรองแพทย์)
//
// เดิมแต่ละหน้าเขียน regex + สร้าง URL เองคนละแบบ (lh3 / wsrv.nl /
// uc?export=view / thumbnail) ทำให้บางหน้าแสดงรูปได้ บางหน้าไม่ได้
// ไฟล์นี้รวมตรรกะไว้ที่เดียว ทุกหน้าเรียกใช้ตัวเดียวกันครับ 🥇🏆
// ═══════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';

/// โฮสต์ของ Google Drive ที่เจอในฐานข้อมูล
bool _isDriveLink(String url) =>
    url.contains('drive.google.com') ||
    url.contains('drive.usercontent.google.com') ||
    url.contains('docs.google.com');

/// ดึง file id ออกจากลิงก์ Google Drive ทุกรูปแบบที่ระบบเคยบันทึกไว้
/// - https://drive.google.com/file/d/<ID>/view?usp=sharing
/// - https://drive.google.com/open?id=<ID>
/// - https://drive.google.com/uc?export=view&id=<ID>   (จาก Apps Script)
/// - https://drive.google.com/thumbnail?id=<ID>&sz=w200
String? extractDriveFileId(String url) {
  if (!_isDriveLink(url)) return null;

  // ใช้ {10,} กันไม่ให้ไปแมตช์เศษ path สั้น ๆ ที่ไม่ใช่ file id
  final byPath = RegExp(r'/d/([a-zA-Z0-9_-]{10,})').firstMatch(url);
  if (byPath != null) return byPath.group(1);

  // ต้องมี ? หรือ & นำหน้า กันแมตช์คำอย่าง folderid= / userid=
  final byQuery = RegExp(r'[?&]id=([a-zA-Z0-9_-]{10,})').firstMatch(url);
  return byQuery?.group(1);
}

/// ลิงก์หลัก: ผ่านพร็อกซี wsrv.nl
///
/// ทำไมไม่ยิง Google ตรง ๆ:
/// - `uc?export=view` และ `thumbnail?id=` ไม่ส่ง header CORS → ติด CORS บนเว็บ
/// - `lh3.googleusercontent.com/d/<id>` ส่ง CORS มาก็จริง แต่มี rate limit
///   ต่อเครื่องผู้ใช้ พอหน้าจอโหลดรูปพร้อมกันหลายรูปบ่อย ๆ Google จะตอบ
///   HTTP 429 แล้วรูป "หายทั้งหน้า" (นี่คือสาเหตุที่รูปโปรไฟล์ติด ๆ ดับ ๆ)
/// wsrv.nl แคชรูปไว้บน CDN ของตัวเอง จึงไม่โดนจำกัดและโหลดเร็วกว่าครับ 🏆
String driveDirectUrl(String fileId) =>
    'https://wsrv.nl/?url=drive.google.com/uc%3Fid%3D$fileId';

/// ลิงก์สำรอง: ยิงตรงไป Google (ใช้ตอนพร็อกซีล่ม)
String driveProxyUrl(String fileId) =>
    'https://lh3.googleusercontent.com/d/$fileId';

/// แปลงค่าที่เก็บในฐานข้อมูล → URL ที่เอาไปใส่ Image.network ได้เลย
/// คืน null เมื่อไม่มีรูป (ผู้ใช้ยังไม่เคยอัปโหลด)
String? resolveDisplayImageUrl(dynamic raw) {
  final url = (raw ?? '').toString().trim();
  if (url.isEmpty) return null;
  if (url.startsWith('data:image')) return url; // รูปที่เพิ่งเลือกจากเครื่อง
  if (!url.startsWith('http')) return null;

  final fileId = extractDriveFileId(url);
  return fileId != null ? driveDirectUrl(fileId) : url;
}

/// รูปโปรไฟล์ทรงกลมที่ใช้ร่วมกันทุกหน้า
///
/// - ไม่มีลิงก์ → แสดงตัวอักษรแรกของชื่อ (หรือไอคอนคน ถ้าไม่ส่งชื่อมา)
/// - โหลด lh3 ไม่ขึ้น → สลับไปพร็อกซี wsrv.nl ให้อัตโนมัติ
/// - พร็อกซีก็ไม่ขึ้น → กลับไปแสดงตัวอักษรแรก
class ProfileAvatar extends StatefulWidget {
  final dynamic imageUrl; // ค่าดิบจากฐานข้อมูล (profileImage)
  final double size;
  final String? name; // ใช้ทำตัวอักษรแรกตอนไม่มีรูป
  final Color? backgroundColor;
  final Color? foregroundColor;
  final BorderRadius? borderRadius; // ไม่ใส่ = วงกลม

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.name,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  // 0 = พร็อกซีหลัก, 1 = ลิงก์สำรอง, 2 = ยอมแพ้ แสดงตัวอักษรแทน
  int _attempt = 0;

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) _attempt = 0;
  }

  void _nextAttempt() {
    if (!mounted || _attempt >= 2) return;
    // errorBuilder ถูกเรียกระหว่าง build จึงต้องรอให้เฟรมนี้จบก่อน
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _attempt++);
    });
  }

  String? get _currentUrl {
    final resolved = resolveDisplayImageUrl(widget.imageUrl);
    if (resolved == null || _attempt >= 2) return null;
    if (_attempt == 0) return resolved;

    final fileId = extractDriveFileId(widget.imageUrl.toString().trim());
    return fileId != null ? driveProxyUrl(fileId) : null;
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? const Color(0xFFF1F5F9);
    final fg = widget.foregroundColor ?? Colors.blueGrey;
    final initial = (widget.name ?? '').trim();

    final Widget fallback = ColoredBox(
      color: bg,
      child: Center(
        child: initial.isEmpty
            ? Icon(Icons.person_outline, color: fg, size: widget.size * 0.5)
            : Text(
                initial.characters.first,
                style: TextStyle(
                  fontSize: widget.size * 0.4,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
      ),
    );

    final url = _currentUrl;
    final Widget content = url == null
        ? fallback
        : Image.network(
            url,
            // บนเว็บให้วาดผ่าน <img> ตรง ๆ เลี่ยงการ fetch bytes ที่ติด CORS
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            errorBuilder: (context, error, stack) {
              _nextAttempt();
              return fallback;
            },
          );

    return ClipRRect(
      borderRadius:
          widget.borderRadius ?? BorderRadius.circular(widget.size / 2),
      child: SizedBox(width: widget.size, height: widget.size, child: content),
    );
  }
}
