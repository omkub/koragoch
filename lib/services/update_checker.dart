import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

/// ตรวจว่ามีเวอร์ชันใหม่บนเว็บไหม (ไม่บังคับอัปเดต — แค่บอก ผู้ใช้กดเองเมื่อพร้อม)
///
/// ทุกครั้งที่ deploy, CI ฝังรหัส commit ลงในแอป (--dart-define=APP_BUILD)
/// และเขียนไฟล์ app-version.json ข้างแอป (.github/workflows/deploy-pages.yml)
/// แอปเทียบสองค่านี้: ตอนเปิด, ทุก 10 นาที, และทุกครั้งที่สลับกลับเข้าแอป
/// (บนมือถือแอปที่ติดตั้งไว้มักไม่ถูกปิดจริงเป็นวัน ๆ จึงต้องคอยเช็ก)
///
/// รัน/บิลด์เองในเครื่อง (ไม่มี APP_BUILD) = ไม่เช็ก
class UpdateChecker {
  UpdateChecker._();
  static final instance = UpdateChecker._();

  static const currentBuild = String.fromEnvironment('APP_BUILD');

  /// true = เว็บมีเวอร์ชันใหม่กว่าที่รันอยู่
  final available = ValueNotifier<bool>(false);

  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  bool _checking = false;

  void start() {
    if (!kIsWeb || currentBuild.isEmpty || _timer != null) return;
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => check());
    _lifecycle = AppLifecycleListener(onResume: check);
    Future.delayed(const Duration(seconds: 20), check);
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    _timer = null;
  }

  Future<void> check() async {
    if (_checking || available.value) return;
    _checking = true;
    try {
      // app-version.json อยู่ข้าง index.html — ใส่เวลาต่อท้ายกันได้ไฟล์จากแคช
      final url = Uri.base
          .resolve('app-version.json')
          .replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final latest = (jsonDecode(res.body) as Map)['build']?.toString() ?? '';
      if (latest.isNotEmpty && latest != currentBuild) available.value = true;
    } catch (e) {
      debugPrint('ℹ️  เช็กเวอร์ชันใหม่ไม่สำเร็จ: $e');
    } finally {
      _checking = false;
    }
  }
}
