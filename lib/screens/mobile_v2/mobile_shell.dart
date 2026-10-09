/// หน้าจอมือถือแบบใหม่ (ทดลอง) — เปิดได้ที่หน้าบัญชี (MobileUiPreference)
///
/// โครงแบบแอปมือถือ:
///   - แถบล่าง 4 ปุ่ม: หน้าหลัก · ส่งใบลา · ประวัติ · บัญชี
///   - แถบหัวบนทุกแท็บ (ชื่อหน้า + กระดิ่งแจ้งเตือนของผู้ดูแลระบบ)
///   - เมนูอื่นเปิดจากทางลัดในหน้าหลัก เลื่อนเข้าจากขวา (mobile_pages.dart)
///   - ปุ่มย้อนกลับของเครื่อง/เบราว์เซอร์ที่แท็บอื่น = กลับหน้าหลักก่อน
///   - สลับแท็บแล้วสิ่งที่กรอกค้างไว้ไม่หาย (IndexedStack)
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/notification_bell.dart';
import '../mobile/mobile_history_screen.dart';
import '../mobile/mobile_leave_form_screen.dart';
import '../mobile/mobile_profile_screen.dart';
import 'menu_access.dart';
import 'mobile_home_screen.dart';
import 'mobile_pages.dart';

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

  @override
  void initState() {
    super.initState();
    MenuAccess.load().then((a) {
      if (mounted) setState(() => _access = a);
    });
  }

  List<_Tab> get _tabs => [
        _Tab.home,
        if (_access!.can(2)) _Tab.leave,
        if (_access!.can(3)) _Tab.history,
        _Tab.account,
      ];

  void _go(_Tab tab) => setState(() => _tab = tab);

  String _title(_Tab tab) => switch (tab) {
        _Tab.home => 'หน้าหลัก',
        _Tab.leave => _editData == null ? 'ส่งใบลา' : 'แก้ไขใบลา',
        _Tab.history => 'ประวัติ',
        _Tab.account => 'บัญชี',
      };

  Widget _page(_Tab tab) {
    switch (tab) {
      case _Tab.home:
        return MobileHomeScreen(access: _access!, onGoTab: (i) => _go(_Tab.values[i]));
      case _Tab.leave:
        return MobileLeaveFormScreen(
          key: ValueKey('leave_${_editData?['requestId'] ?? 'new'}'),
          initialData: _editData,
          onComplete: () => setState(() {
            _editData = null;
            _historyVersion++;
            _tab = _Tab.history;
          }),
        );
      case _Tab.history:
        return MobileHistoryScreen(
          key: ValueKey('history_$_historyVersion'),
          onEdit: (data) => setState(() {
            _editData = data;
            _tab = _Tab.leave;
          }),
        );
      case _Tab.account:
        return const MobileProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    if (access == null) {
      return const Scaffold(
          backgroundColor: mobileBg,
          body: Center(child: CircularProgressIndicator()));
    }
    final tabs = _tabs;
    final current = tabs.contains(_tab) ? _tab : _Tab.home;

    return PopScope(
      // ย้อนกลับที่แท็บอื่น = กลับหน้าหลัก (ไม่ใช่ออกจากแอป)
      canPop: current == _Tab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_Tab.home);
      },
      child: Scaffold(
        backgroundColor: mobileBg,
        appBar: mobileAppBar(_title(current), actions: [
          if (access.isAdmin)
            NotificationBell(onOpenLeaves: () => _go(_Tab.history)),
        ]),
        body: IndexedStack(
          index: tabs.indexOf(current),
          children: [for (final t in tabs) _page(t)],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tabs.indexOf(current),
          onDestinationSelected: (i) => _go(tabs[i]),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          indicatorColor: const Color(0xFFDBEAFE),
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((s) =>
              GoogleFonts.sarabun(
                  fontSize: 12,
                  fontWeight: s.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: s.contains(WidgetState.selected)
                      ? mobileAccent
                      : mobileMuted)),
          destinations: [
            for (final t in tabs)
              switch (t) {
                _Tab.home => const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded, color: mobileAccent),
                    label: 'หน้าหลัก'),
                _Tab.leave => const NavigationDestination(
                    icon: Icon(Icons.add_circle_outline_rounded),
                    selectedIcon:
                        Icon(Icons.add_circle_rounded, color: mobileAccent),
                    label: 'ส่งใบลา'),
                _Tab.history => const NavigationDestination(
                    icon: Icon(Icons.history_rounded),
                    selectedIcon:
                        Icon(Icons.manage_history_rounded, color: mobileAccent),
                    label: 'ประวัติ'),
                _Tab.account => const NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon:
                        Icon(Icons.person_rounded, color: mobileAccent),
                    label: 'บัญชี'),
              },
          ],
        ),
      ),
    );
  }
}
