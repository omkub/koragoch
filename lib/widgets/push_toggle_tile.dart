import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/push_service.dart';

/// สวิตช์ "แจ้งเตือนบนเครื่องนี้" (Web Push) — แสดงเฉพาะผู้ดูแลระบบ
/// ผู้เรียกเป็นคนเช็กสิทธิ์ (หน้าบัญชี: ส่วนผู้ดูแลระบบ) ฐานข้อมูลกันซ้ำอีกชั้น
class PushToggleTile extends StatefulWidget {
  const PushToggleTile({super.key});

  @override
  State<PushToggleTile> createState() => _PushToggleTileState();
}

class _PushToggleTileState extends State<PushToggleTile> {
  String? _state; // null = กำลังโหลด
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await PushService.instance.state();
    if (mounted) setState(() => _state = s);
  }

  void _snack(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: error ? Colors.red.shade700 : null,
          content: Text(text)));

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    if (on) {
      final error = await PushService.instance.enable();
      if (!mounted) return;
      if (error != null) {
        _snack(error, error: true);
      } else {
        _snack('เปิดแจ้งเตือนแล้ว — ใบลาใหม่จะเด้งที่เครื่องนี้');
      }
    } else {
      await PushService.instance.disable();
      if (mounted) _snack('ปิดแจ้งเตือนบนเครื่องนี้แล้ว');
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final sent = await PushService.instance.test();
      if (mounted) {
        _snack(sent > 0
            ? 'ส่งแจ้งเตือนทดสอบแล้ว ($sent เครื่อง)'
            : 'ไม่มีเครื่องที่รับแจ้งเตือน — ลองปิดแล้วเปิดใหม่');
      }
    } catch (e) {
      if (mounted) _snack('ส่งทดสอบไม่สำเร็จ: $e', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final on = s == 'on';
    final String subtitle = switch (s) {
      null => 'กำลังตรวจสอบ...',
      'on' => 'ใบลาใหม่จะเด้งที่เครื่องนี้ แม้ปิดแอปอยู่',
      'denied' => 'เบราว์เซอร์บล็อกการแจ้งเตือนไว้ — เปิดได้ที่การตั้งค่าเว็บไซต์',
      'needs-install' => 'iPhone: กด "เพิ่มไปยังหน้าจอโฮม" ก่อน แล้วเปิดจากไอคอนแอป',
      'unsupported' => 'เบราว์เซอร์นี้ไม่รองรับ — ใช้ Chrome / Edge / Safari',
      _ => 'เปิดเพื่อให้ใบลาใหม่เด้งที่เครื่องนี้ เหมือนแอปทั่วไป',
    };
    final canToggle = s == 'on' || s == 'off';

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
                on
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                color: on ? const Color(0xFF2563EB) : Colors.blueGrey),
            title: Text('แจ้งเตือนบนเครื่องนี้',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
            subtitle: Text(subtitle, style: GoogleFonts.sarabun(fontSize: 12)),
            value: on,
            onChanged: (!canToggle || _busy) ? null : _toggle,
          ),
          if (on)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
                child: TextButton.icon(
                  onPressed: _busy ? null : _test,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('ส่งแจ้งเตือนทดสอบ'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
