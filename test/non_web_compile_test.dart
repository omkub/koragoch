// เทสกันไม่ให้โค้ดเฉพาะเว็บหลุดกลับเข้ามาอีก
//
// เทสของ Flutter รันบน Dart VM ไม่ใช่เบราว์เซอร์ ไฟล์ที่ import
// `package:web` หรือ `dart:js_interop` ตรง ๆ จึงคอมไพล์ที่นี่ไม่ผ่าน
// แค่ import ไฟล์เหล่านี้เข้ามาได้ก็ถือว่าผ่านแล้ว — ถ้าใครเผลอเอา
// `package:web` กลับเข้าไปในไฟล์ไหน เทสนี้จะตกทันทีตอนคอมไพล์
//
// ทั้ง 5 ไฟล์นี้เคยเรียก DOM ตรง ๆ ตอนนี้ผ่าน utils/web_platform.dart แทน

import 'package:flutter_test/flutter_test.dart';

import 'package:school_leave_app/screens/leave_history_screen.dart';
import 'package:school_leave_app/screens/line_settings_screen.dart';
import 'package:school_leave_app/screens/report_overview_screen.dart';
import 'package:school_leave_app/screens/user_management_screen.dart';
import 'package:school_leave_app/services/firebase_service.dart';
import 'package:school_leave_app/utils/web_platform.dart' as platform;

void main() {
  test('ไฟล์ที่เคยใช้ DOM คอมไพล์บนแพลตฟอร์มที่ไม่ใช่เว็บได้', () {
    // อ้างถึงแต่ละไฟล์อย่างละนิดเพื่อไม่ให้ import ถูกมองว่าไม่ได้ใช้
    expect(FirebaseService.authEmailForUsername('SomChai'),
        'somchai@leave.local');
    expect(const LeaveHistoryScreen(), isNotNull);
    expect(const LineSettingsScreen(), isNotNull);
    expect(const ReportOverviewScreen(), isNotNull);
    expect(const UserManagementScreen(), isNotNull);
  });

  test('ฝั่งที่ไม่ใช่เว็บบอกตรง ๆ ว่าทำอะไรไม่ได้ แทนที่จะพังเงียบ ๆ', () {
    expect(platform.platformUserAgent, 'Mobile App');
    expect(platform.openHtmlInNewTab('<html></html>'), isFalse);
    expect(platform.downloadBytes(const [1, 2, 3], 'a.xlsx', 'text/plain'),
        isFalse);
  });

  test('เลือกรูปบนอุปกรณ์ที่ไม่ใช่เว็บคืน null', () async {
    expect(await platform.pickAndCompressImage(), isNull);
  });
}
