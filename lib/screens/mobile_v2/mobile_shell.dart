/// หน้าจอมือถือ (จอแคบกว่า 1100px — ดู ResponsiveLayout)
/// แบบใหม่ — ปรับแต่งประสบการณ์ใช้งานให้เป็น Mobile Application อย่างแท้จริง:
///   - แถบล่าง 4 ปุ่ม: หน้าหลัก · ส่งใบลา · ประวัติ · บัญชี
///   - Badge แสดงตัวเลขอัปเดตแจ้งเตือนและรายการค้างดำเนินการ
///   - แอนิเมชันเปลี่ยนหน้าแบบลื่นไหล
///   - Haptic feedback เวลาแตะปุ่มเพื่อประสบการณ์แบบ Native App
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firebase_service.dart';
import '../../services/push_service.dart';
import '../../widgets/notification_bell.dart';
import 'menu_access.dart';
import 'mobile_home_screen.dart';
import 'mobile_leave_form.dart';
import 'mobile_leave_history.dart';
import 'mobile_pages.dart';
import 'mobile_profile.dart';
import '../../theme/app_tokens.dart';

enum _Tab { home, leave, history, account }

class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  MenuAccess? _access;
  _Tab _tab = _Tab.home;

  /// ใบลาที่กำลังแก้ (เปิดจากประวัติ) — null = ใบใหม่
  Map<String, dynamic>? _editData;

  /// เพิ่มเมื่อส่งใบลาเสร็จ ให้หน้าประวัติโหลดใหม่
  int _historyVersion = 0;

  /// จำนวนงานรอพิจารณาสำหรับ Badge บนแท็บประวัติ
  int _pendingCount = 0;
  VoidCallback? _stopLive;

  @override
  void initState() {
    super.initState();
    MenuAccess.load().then((a) {
      if (!mounted) return;
      setState(() => _access = a);
      PushService.instance.offerOnce(context, isAdmin: a.isAdmin);
      _listenPendingCount(a);
    });
  }

  @override
  void dispose() {
    _stopLive?.call();
    super.dispose();
  }

  void _listenPendingCount(MenuAccess access) {
    if (!access.isAdmin && !access.seesSchoolOverview) return;
    final service = FirebaseService();
    _fetchPending(service);
    _stopLive = service.onLeavesChanged(() => _fetchPending(service));
  }

  Future<void> _fetchPending(FirebaseService service) async {
    try {
      final leaves = await service.getLeaveRequestsFromSupabase();
      if (!mounted) return;
      final pending = leaves.where((l) {
        final s = (l['status'] ?? '').toString();
        return s.contains('รอ') || s.contains('พิจารณา');
      }).length;
      setState(() => _pendingCount = pending);
    } catch (_) {}
  }

  List<_Tab> get _tabs => [
        _Tab.home,
        if (_access!.can(2)) _Tab.leave,
        if (_access!.can(3)) _Tab.history,
        _Tab.account,
      ];

  void _go(_Tab tab) {
    if (_tab != tab) {
      HapticFeedback.lightImpact();
      setState(() => _tab = tab);
    }
  }

  String _title(_Tab tab) => switch (tab) {
        _Tab.home => 'หน้าหลัก',
        _Tab.leave => _editData == null ? 'ส่งใบลา' : 'แก้ไขใบลา',
        _Tab.history => 'ประวัติและรายการลา',
        _Tab.account => 'โปรไฟล์และตั้งค่า',
      };

  Widget _page(_Tab tab) {
    switch (tab) {
      case _Tab.home:
        return MobileHomeScreen(
          access: _access!,
          onGoTab: (i) => _go(_Tab.values[i]),
        );
      case _Tab.leave:
        return MobileLeaveFormV2(
          key: ValueKey('leave_${_editData?['requestId'] ?? 'new'}'),
          initialData: _editData,
          onComplete: () => setState(() {
            _editData = null;
            _historyVersion++;
            _tab = _Tab.history;
          }),
        );
      case _Tab.history:
        return MobileLeaveHistory(
          key: ValueKey('history_$_historyVersion'),
          access: _access!,
          onEdit: (data) => setState(() {
            _editData = data;
            _tab = _Tab.leave;
          }),
        );
      case _Tab.account:
        return const MobileProfileV2();
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    if (access == null) {
      return const Scaffold(
        backgroundColor: mobileBg,
        body: Center(
          child: CircularProgressIndicator(color: mobileAccent),
        ),
      );
    }
    final tabs = _tabs;
    final current = tabs.contains(_tab) ? _tab : _Tab.home;

    return PopScope(
      canPop: current == _Tab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_Tab.home);
      },
      child: Scaffold(
        backgroundColor: mobileBg,
        appBar: mobileAppBar(
          _title(current),
          showLogo: true,
          actions: [
            NotificationBell(onOpenLeaves: () => _go(_Tab.history)),
          ],
        ),
        body: IndexedStack(
          index: tabs.indexOf(current),
          children: [for (final t in tabs) _page(t)],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 66,
              child: Row(
                children: [
                  for (final t in tabs)
                    Expanded(
                      child: _buildNavItem(
                        tab: t,
                        isSelected: current == t,
                        onTap: () => _go(t),
                        badgeCount: t == _Tab.history && _pendingCount > 0 ? _pendingCount : 0,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required _Tab tab,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final (icon, activeIcon, label) = switch (tab) {
      _Tab.home => (Icons.home_outlined, Icons.home_rounded, 'หน้าหลัก'),
      _Tab.leave => (Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'ส่งใบลา'),
      _Tab.history => (Icons.history_rounded, Icons.manage_history_rounded, 'ประวัติ'),
      _Tab.account => (Icons.person_outline_rounded, Icons.person_rounded, 'บัญชี'),
    };

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: SizedBox(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 22,
                    color: isSelected ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.negative,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sarabun(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.sarabun(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: isSelected ? AppColors.accent : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
