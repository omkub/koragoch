import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/web_platform.dart' as platform;

/// แจ้งเตือนแบบแอปจริง (Web Push) — ทุกคนเปิดได้ เด้งที่เครื่องแม้ปิดแอปอยู่
///   - ผู้ดูแลระบบ: ใบลาใหม่ของโรงเรียน + ผลการอนุมัติใบลาของตัวเอง
///   - ครู / ผู้บริหาร / อื่น ๆ: ผลการอนุมัติใบลาของตัวเองเท่านั้น
///   (ฐานข้อมูลเลือกผู้รับ — supabase/push_for_everyone.sql)
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
      // ขอสิทธิ์ก่อนโหลดอะไร — Safari ยอมเฉพาะตอนที่ยังนับว่าผู้ใช้เพิ่งแตะปุ่ม
      final permission = await platform.pushPermission();
      if (permission == 'denied') {
        return 'ไม่ได้อนุญาตการแจ้งเตือน — เปิดได้ที่การตั้งค่าเว็บไซต์ของเบราว์เซอร์';
      }

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

  static const _askedKey = 'pushOfferAsked';

  /// หลังล็อกอินเข้าแอป: ถามครั้งเดียวต่อเครื่องว่าจะเปิดแจ้งเตือนไหม
  ///
  /// ไม่ถาม: เคยถามแล้ว / เบราว์เซอร์ไม่รองรับ / iPhone ที่ยังไม่ได้ติดตั้งลง
  /// หน้าจอโฮม (เปิดไม่ได้อยู่ดี) / เคยบล็อกไว้แล้ว
  /// เคยอนุญาตไว้แล้วแต่เครื่องนี้ยังไม่ได้สมัคร (เช่น ล็อกอินบัญชีใหม่) → เปิดให้เงียบ ๆ
  /// ตอบ "ไว้ทีหลัง" แล้วเปิดเองได้ที่หน้าบัญชี
  Future<void> offerOnce(BuildContext context, {required bool isAdmin}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) == true) return;

    final s = await state();
    if (s != 'off') {
      if (s == 'on' || s == 'denied') await prefs.setBool(_askedKey, true);
      return;
    }
    if (platform.pushPermissionState() == 'granted') {
      await prefs.setBool(_askedKey, true);
      await enable();
      return;
    }
    if (!context.mounted) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_rounded,
            color: Color(0xFF2563EB), size: 36),
        title: const Text('เปิดการแจ้งเตือน?'),
        content: Text(isAdmin
            ? 'แจ้งเตือนจะเด้งที่เครื่องนี้แม้ปิดแอปอยู่ เมื่อมีใบลาใหม่ '
                'และเมื่อใบลาของคุณได้รับอนุมัติหรือไม่อนุมัติ'
            : 'แจ้งเตือนจะเด้งที่เครื่องนี้แม้ปิดแอปอยู่ '
                'เมื่อใบลาของคุณได้รับอนุมัติหรือไม่อนุมัติ'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ไว้ทีหลัง')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('เปิดแจ้งเตือน')),
        ],
      ),
    );
    await prefs.setBool(_askedKey, true);
    if (yes != true) return;

    final error = await enable();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      backgroundColor: error == null ? null : Colors.red.shade700,
      content: Text(error ?? 'เปิดแจ้งเตือนแล้ว — ปิดได้ที่หน้าบัญชี'),
    ));
  }

  /// ส่งแจ้งเตือนทดสอบไปทุกเครื่องของตัวเอง — คืนจำนวนเครื่องที่ส่งถึง
  Future<int> test() async {
    final res =
        await _client.functions.invoke(function, body: {'action': 'test'});
    return int.tryParse('${(res.data as Map?)?['sent']}') ?? 0;
  }
}
