import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/web_platform.dart' as platform;

/// แจ้งเตือนแบบแอปจริง (Web Push) — เฉพาะผู้ดูแลระบบ / ผู้ดูแลส่วนกลาง
///
/// เปิดแล้ว ใบลาใหม่จะเด้งที่เครื่องแม้ปิดแอปอยู่ (เหมือนแอป LINE)
///   - เครื่อง: web/index.html (koragochPush*) + web/sw.js (แสดงแจ้งเตือน)
///   - ฐานข้อมูล: PushSubscriptions + trigger (supabase/push_notifications.sql)
///   - ส่ง: Edge Function push-notify
///
/// iPhone ต้องติดตั้งแอปลงหน้าจอโฮมก่อน (iOS 16.4+) ถึงจะเปิดได้
class PushService {
  PushService._();
  static final instance = PushService._();

  static const function = 'push-notify';

  SupabaseClient get _client => Supabase.instance.client;

  /// 'on' | 'off' | 'denied' | 'unsupported' | 'needs-install'
  Future<String> state() => platform.pushState();

  Future<int?> _myId() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString('userFullDataJson') ?? '{}')
          as Map<String, dynamic>;
      return int.tryParse('${raw['id_user']}');
    } catch (_) {
      return null;
    }
  }

  /// เปิดแจ้งเตือนบนเครื่องนี้ — คืนข้อความผิดพลาด หรือ null ถ้าสำเร็จ
  Future<String?> enable() async {
    try {
      final key = await _client.functions
          .invoke(function, body: {'action': 'public_key'});
      final publicKey = (key.data as Map?)?['publicKey']?.toString() ?? '';
      if (publicKey.isEmpty) return 'ยังไม่ได้ติดตั้งระบบแจ้งเตือนบนเซิร์ฟเวอร์';

      final result = await platform.pushEnable(publicKey);
      if (result == 'denied') {
        return 'ไม่ได้อนุญาตการแจ้งเตือน — เปิดได้ที่การตั้งค่าเว็บไซต์ของเบราว์เซอร์';
      }
      if (result.startsWith('error:')) return 'เปิดแจ้งเตือนไม่สำเร็จ (${result.substring(6)})';

      final sub = jsonDecode(result) as Map<String, dynamic>;
      final keys = (sub['keys'] as Map?) ?? const {};
      final myId = await _myId();
      if (myId == null) return 'ไม่พบข้อมูลผู้ใช้ — ออกจากระบบแล้วเข้าใหม่';

      await _client.from('PushSubscriptions').upsert({
        'id_user': myId,
        'endpoint': sub['endpoint'],
        'p256dh': keys['p256dh'],
        'auth': keys['auth'],
        'user_agent': defaultTargetPlatform.name,
      }, onConflict: 'endpoint');
      return null;
    } catch (e) {
      debugPrint('❌ เปิดแจ้งเตือนไม่สำเร็จ: $e');
      return e.toString().contains('PushSubscriptions')
          ? 'ต้องรัน supabase/push_notifications.sql ก่อน'
          : 'เปิดแจ้งเตือนไม่สำเร็จ: $e';
    }
  }

  /// ปิดแจ้งเตือนบนเครื่องนี้ (เครื่องอื่นของคนเดียวกันยังได้รับ)
  Future<void> disable() async {
    final endpoint = await platform.pushDisable();
    if (endpoint.isEmpty) return;
    try {
      await _client.from('PushSubscriptions').delete().eq('endpoint', endpoint);
    } catch (e) {
      debugPrint('⚠️  ลบการสมัครแจ้งเตือนไม่สำเร็จ: $e');
    }
  }

  /// ส่งแจ้งเตือนทดสอบไปทุกเครื่องของตัวเอง — คืนจำนวนเครื่องที่ส่งถึง
  Future<int> test() async {
    final res =
        await _client.functions.invoke(function, body: {'action': 'test'});
    return int.tryParse('${(res.data as Map?)?['sent']}') ?? 0;
  }
}
