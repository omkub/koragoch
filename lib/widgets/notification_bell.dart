import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════
// กระดิ่งแจ้งเตือนใน app (เฉพาะผู้ดูแลระบบ)
//
// แจ้งเตือนสร้างโดยฐานข้อมูลเอง (supabase/notifications.sql) เมื่อมีใบลาใหม่
// ฝั่ง app แค่ฟังตาราง AppNotifications แบบ realtime แล้วแสดงตัวเลข
// + เด้งข้อความสั้น ๆ เมื่อมีแจ้งเตือนใหม่เข้ามาระหว่างเปิด app อยู่
// RLS ให้เห็นเฉพาะแจ้งเตือนของตัวเอง
// ═══════════════════════════════════════════════════════════════

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

class NotificationBell extends StatefulWidget {
  /// กดแจ้งเตือนใบลา → ไปหน้าประวัติการลา
  final VoidCallback onOpenLeaves;
  final double size;

  const NotificationBell({super.key, required this.onOpenLeaves, this.size = 22});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  static const _limit = 50;

  SupabaseClient get _client => Supabase.instance.client;

  int? _myId;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _items = [];
  int? _latestSeenId; // กันเด้งข้อความซ้ำ / ไม่เด้งของเก่าตอนเปิด app

  int get _unread => _items.where((n) => n['read_at'] == null).length;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final cached = prefs.getString('userFullDataJson');
      final raw = cached == null ? null : (jsonDecode(cached) as Map)['id_user'];
      _myId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    } catch (_) {}
    if (_myId == null || !mounted) return;
    setState(() {});

    _sub = _client
        .from('AppNotifications')
        .stream(primaryKey: ['id_notification'])
        .eq('recipient_id', _myId!)
        .order('createdAt')
        .limit(_limit)
        .listen(_onData, onError: (Object e) {
      debugPrint('⚠️  ฟังแจ้งเตือนไม่สำเร็จ: $e');
    });
  }

  void _onData(List<Map<String, dynamic>> rows) {
    if (!mounted) return;
    final sorted = [...rows]
      ..sort((a, b) => (b['id_notification'] as int)
          .compareTo(a['id_notification'] as int));
    final newest = sorted.isEmpty ? null : sorted.first['id_notification'] as int;

    // ไม่ใช่รอบแรก + มีแจ้งเตือนใหม่ที่ยังไม่อ่าน → เด้งข้อความ
    if (_latestSeenId != null && newest != null && newest > _latestSeenId!) {
      final fresh = sorted.where((n) =>
          (n['id_notification'] as int) > _latestSeenId! && n['read_at'] == null);
      if (fresh.isNotEmpty) _toast(fresh.first, fresh.length);
    }
    _latestSeenId = newest ?? _latestSeenId ?? 0;
    setState(() => _items = sorted);
  }

  void _toast(Map<String, dynamic> n, int count) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _ink,
      duration: const Duration(seconds: 6),
      content: Row(children: [
        const Icon(Icons.notifications_active_rounded, color: Colors.amber),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
              count > 1
                  ? '${n['title']} และอีก ${count - 1} รายการ'
                  : n['title'].toString(),
              style: GoogleFonts.sarabun(color: Colors.white)),
        ),
      ]),
      action: SnackBarAction(
          label: 'ดู', textColor: Colors.amber, onPressed: _openPanel),
    ));
  }

  // ─── การกระทำ ───────────────────────────────────────────────

  Future<void> _markRead(Iterable<int> ids) async {
    if (ids.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String();
    // อัปเดตบนจอทันที ไม่ต้องรอ realtime
    setState(() => _items = [
          for (final n in _items)
            ids.contains(n['id_notification']) && n['read_at'] == null
                ? {...n, 'read_at': now}
                : n
        ]);
    try {
      await _client
          .from('AppNotifications')
          .update({'read_at': now})
          .inFilter('id_notification', ids.toList())
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint('⚠️  บันทึกว่าอ่านแล้วไม่สำเร็จ: $e');
    }
  }

  Future<void> _clearRead() async {
    setState(() => _items = _items.where((n) => n['read_at'] == null).toList());
    try {
      await _client
          .from('AppNotifications')
          .delete()
          .eq('recipient_id', _myId!)
          .not('read_at', 'is', null);
    } catch (e) {
      debugPrint('⚠️  ลบแจ้งเตือนไม่สำเร็จ: $e');
    }
  }

  void _openPanel() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setPanel) {
        Future<void> run(Future<void> Function() action) async {
          await action();
          setPanel(() {});
        }

        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
            child: Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 440, maxHeight: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(children: [
                        Expanded(
                          child: Text('แจ้งเตือน',
                              style: GoogleFonts.sarabun(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        if (_unread > 0)
                          TextButton(
                            onPressed: () => run(() => _markRead(_items
                                .where((n) => n['read_at'] == null)
                                .map((n) => n['id_notification'] as int))),
                            child: const Text('อ่านทั้งหมด'),
                          ),
                        if (_items.any((n) => n['read_at'] != null))
                          TextButton(
                            onPressed: () => run(_clearRead),
                            child: const Text('ล้างที่อ่านแล้ว'),
                          ),
                      ]),
                    ),
                    const Divider(height: 1),
                    if (_items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text('ยังไม่มีแจ้งเตือน',
                            style: GoogleFonts.sarabun(color: _muted)),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 56),
                          itemBuilder: (_, i) {
                            final n = _items[i];
                            final unread = n['read_at'] == null;
                            return ListTile(
                              tileColor:
                                  unread ? const Color(0xFFEFF6FF) : null,
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: unread
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFFE2E8F0),
                                child: Icon(Icons.event_note_rounded,
                                    size: 18,
                                    color: unread ? Colors.white : _muted),
                              ),
                              title: Text(n['title'].toString(),
                                  style: GoogleFonts.sarabun(
                                      fontWeight: unread
                                          ? FontWeight.bold
                                          : FontWeight.w500)),
                              subtitle: Text(
                                  [
                                    if ((n['body'] ?? '').toString().isNotEmpty)
                                      n['body'].toString(),
                                    _ago(n['createdAt']),
                                  ].join('\n'),
                                  style: GoogleFonts.sarabun(
                                      fontSize: 12, color: _muted)),
                              isThreeLine:
                                  (n['body'] ?? '').toString().isNotEmpty,
                              onTap: () {
                                _markRead([n['id_notification'] as int]);
                                Navigator.pop(ctx);
                                if (n['ref_table'] == 'Leaves') {
                                  widget.onOpenLeaves();
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  static String _ago(dynamic iso) {
    final t = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) return '${diff.inHours} ชั่วโมงที่แล้ว';
    if (diff.inDays < 7) return '${diff.inDays} วันที่แล้ว';
    return '${t.day}/${t.month}/${t.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    if (_myId == null) return const SizedBox.shrink();
    final unread = _unread;
    return Tooltip(
      message: unread > 0 ? 'แจ้งเตือนใหม่ $unread รายการ' : 'แจ้งเตือน',
      child: IconButton(
        onPressed: _openPanel,
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: Icon(
              unread > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              size: widget.size,
              color: unread > 0 ? const Color(0xFF2563EB) : _muted),
        ),
      ),
    );
  }
}
