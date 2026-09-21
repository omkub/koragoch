/// ของสำหรับแพลตฟอร์มที่ไม่ใช่เว็บ (มือถือ/เดสก์ท็อป) และตอนรัน `flutter test`
///
/// บนมือถือไม่มีข้อจำกัดเรื่อง CORS จึงเรียก http ตรง ๆ ได้เลย ง่ายกว่าเว็บมาก
/// ส่วนความสามารถที่ผูกกับเบราว์เซอร์จริง ๆ (เปิดแท็บใหม่ สั่งดาวน์โหลด เลือกรูป)
/// ยังไม่รองรับ เพราะหน้าจอที่เรียกใช้เป็นหน้าเวอร์ชันเว็บซึ่งมือถือมีหน้าของตัวเอง
/// อยู่แล้ว — คืนค่าที่บอกว่า "ทำไม่ได้" เพื่อให้หน้าจอแจ้งผู้ใช้ได้อย่างตรงไปตรงมา
/// แทนที่จะพังเงียบ ๆ
///
/// ดูเหตุผลที่ต้องแยกไฟล์ได้ที่ web_platform.dart
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// ยิง GET ทิ้งไว้ ไม่สนใจผลลัพธ์ (มือถือไม่ติด CORS จึงเรียกตรงได้)
void fireAndForgetGet(String url) {
  http.get(Uri.parse(url)).timeout(const Duration(seconds: 10)).catchError(
    (Object e) {
      debugPrint('fireAndForgetGet ล้มเหลว: $e');
      return http.Response('', 599);
    },
  );
}

/// เรียก Apps Script แล้วอ่าน JSON กลับมาตรง ๆ ไม่ต้องใช้ JSONP
Future<Map<String, dynamic>> jsonpGet(
  String url, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  try {
    final response = await http.get(Uri.parse(url)).timeout(timeout);
    // Apps Script ตอบ 302 เป็นปกติ ไม่ใช่ข้อผิดพลาด
    if (response.statusCode != 200 && response.statusCode != 302) {
      return {
        'status': 'error',
        'message': 'Server error: ${response.statusCode}',
      };
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List) {
      return {'status': 'error', 'isList': true, 'data': decoded};
    }
    return {'status': 'error', 'message': 'Invalid response'};
  } catch (e) {
    return {'status': 'error', 'message': e.toString()};
  }
}

/// ข้อมูลอุปกรณ์สำหรับเก็บลงประวัติการเข้าใช้งาน
String get platformUserAgent => 'Mobile App';

/// ไม่รองรับนอกเว็บ — หน้าจอที่เรียกจะแจ้งผู้ใช้เองเมื่อได้ false
bool openHtmlInNewTab(String htmlContent) {
  debugPrint('openHtmlInNewTab: รองรับเฉพาะบนเว็บ');
  return false;
}

/// ไม่รองรับนอกเว็บ — หน้าจอที่เรียกจะแจ้งผู้ใช้เองเมื่อได้ false
bool downloadBytes(List<int> bytes, String fileName, String mimeType) {
  debugPrint('downloadBytes: รองรับเฉพาะบนเว็บ');
  return false;
}

/// ไม่รองรับนอกเว็บ — มือถือมีหน้าโปรไฟล์ของตัวเองที่อัปรูปได้อยู่แล้ว
Future<String?> pickAndCompressImage({
  int maxSize = 350,
  double quality = 0.85,
}) async {
  debugPrint('pickAndCompressImage: รองรับเฉพาะบนเว็บ');
  return null;
}
