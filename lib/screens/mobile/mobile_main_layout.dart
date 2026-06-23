import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard_screen.dart';
import '../login_logs_screen.dart';
import '../personnel_screen.dart';
import '../report_overview_screen.dart';
import '../user_management_screen.dart';
import 'mobile_calendar_screen.dart';
import 'mobile_history_screen.dart';
import 'mobile_leave_form_screen.dart';
import 'mobile_profile_screen.dart';

class MobileMainLayout extends StatefulWidget {
  const MobileMainLayout({super.key});

  @override
  State<MobileMainLayout> createState() => _MobileMainLayoutState();
}

class _MobileMainLayoutState extends State<MobileMainLayout> {
  int _selectedMenuIndex = 2;
  String _currentUser = '';
  String _userRole = 'ครู';
  bool _isLoading = true;
  Map<String, dynamic>? _editData;

  bool get _isAdmin =>
      _userRole.contains('ผู้ดูแลระบบ') || _currentUser == 'ผู้ดูแลระบบ';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUser = prefs.getString('currentUser') ?? '';
      _userRole = prefs.getString('userRole') ?? 'ครู';
      _isLoading = false;
    });
  }

  List<int> _defaultAllowedMenus() {
    final allowed = _isAdmin
        ? [...List<int>.generate(9, (index) => index), -1]
        : [0, 2, 3, -1];
    if (_userRole.contains('ครู')) allowed.remove(0);
    return allowed;
  }

  List<int> _allowedMenusFromData(Map<String, dynamic> data) {
    final allowed = <int>[];
    for (int i = 0; i <= 8; i++) {
      final val = data[i.toString()];
      if (val == true || val.toString().toUpperCase() == 'TRUE') {
        allowed.add(i);
      }
    }

    final oldMapping = <String, int>{
      'แดชบอร์ด': 0,
      'รายงานสรุปการลา': 1,
      'ส่งใบลา': 2,
      'ประวัติการลา': 3,
      'จัดการระบบ (รายชื่อบุคลากร)': 4,
      'จัดการระบบ': 4,
      'บุคลากร (กลุ่มสาระ)': 5,
      'จัดการข้อมูลครูเวร': 6,
      'ประวัติการเข้าใช้งาน': 7,
      'ปฏิทินกิจกรรมส่วนกลาง': 8,
    };

    oldMapping.forEach((key, index) {
      final val = data[key];
      if (!allowed.contains(index) &&
          (val == true || val.toString().toUpperCase() == 'TRUE')) {
        allowed.add(index);
      }
    });

    final hasAccountField = data.containsKey('-1') || data.containsKey('บัญชี');
    final accountValue = data['-1'] ?? data['บัญชี'];
    if (hasAccountField) {
      if (accountValue == true ||
          accountValue.toString().toUpperCase() == 'TRUE') {
        allowed.add(-1);
      }
    } else {
      allowed.add(-1);
    }

    if (_isAdmin && !allowed.contains(4)) allowed.add(4);
    if (_userRole.contains('ครู')) allowed.remove(0);
    allowed.sort((a, b) {
      if (a == -1) return 1;
      if (b == -1) return -1;
      return a.compareTo(b);
    });
    return allowed.isEmpty ? _defaultAllowedMenus() : allowed;
  }

  int _effectiveMenuIndex(List<int> allowedMenus) {
    if (_selectedMenuIndex == -1) return -1;
    if (allowedMenus.contains(_selectedMenuIndex)) return _selectedMenuIndex;
    return allowedMenus.isNotEmpty ? allowedMenus.first : 2;
  }

  Widget _buildPage(int menuIndex) {
    switch (menuIndex) {
      case 0:
        return DashboardScreen(
          onNavigate: (index) => setState(() => _selectedMenuIndex = index),
        );
      case 1:
        return const ReportOverviewScreen();
      case 2:
        return MobileLeaveFormScreen(
          key: ValueKey('edit_${_editData?['requestId'] ?? 'new'}'),
          initialData: _editData,
          onComplete: () {
            setState(() {
              _editData = null;
              _selectedMenuIndex = 3;
            });
          },
        );
      case 3:
        return MobileHistoryScreen(
          onEdit: (data) {
            setState(() {
              _editData = data;
              _selectedMenuIndex = 2;
            });
          },
        );
      case 4:
        return const UserManagementScreen();
      case 5:
        return const PersonnelScreen();
      case 6:
        return const Center(child: Text('จัดการข้อมูลครูเวน (เร็วๆ นี้)'));
      case 7:
        return const LoginLogsScreen();
      case 8:
        return const MobileCalendarScreen();
      case -1:
        return const MobileProfileScreen();
      default:
        return const MobileLeaveFormScreen();
    }
  }

  IconData _menuIcon(int menuIndex, {bool active = false}) {
    switch (menuIndex) {
      case 0:
        return active ? Icons.dashboard_rounded : Icons.dashboard_outlined;
      case 1:
        return Icons.bar_chart_rounded;
      case 2:
        return active
            ? Icons.add_circle_rounded
            : Icons.add_circle_outline_rounded;
      case 3:
        return active ? Icons.manage_history_rounded : Icons.history_rounded;
      case 4:
        return active ? Icons.settings_rounded : Icons.settings_outlined;
      case 5:
        return active ? Icons.people_alt_rounded : Icons.people_outline;
      case 6:
        return active
            ? Icons.assignment_ind_rounded
            : Icons.assignment_ind_outlined;
      case 7:
        return Icons.security_rounded;
      case 8:
        return active
            ? Icons.calendar_month_rounded
            : Icons.calendar_month_outlined;
      case -1:
        return active ? Icons.person_rounded : Icons.person_outline_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  String _menuLabel(int menuIndex) {
    switch (menuIndex) {
      case 0:
        return 'สรุปผล';
      case 1:
        return 'รายงาน';
      case 2:
        return 'ส่งใบลา';
      case 3:
        return 'ประวัติ';
      case 4:
        return 'ระบบ';
      case 5:
        return 'บุคลากร';
      case 6:
        return 'ครูเวร';
      case 7:
        return 'เข้าใช้งาน';
      case 8:
        return 'ปฏิทิน';
      case -1:
        return 'บัญชี';
      default:
        return '';
    }
  }

  BottomNavigationBarItem _buildNavItem(int menuIndex) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(_menuIcon(menuIndex), size: 24),
      ),
      activeIcon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(_menuIcon(menuIndex, active: true), size: 26),
      ),
      label: _menuLabel(menuIndex),
    );
  }

  Widget _buildMobileScaffold(Map<String, dynamic>? permissionData) {
    var allowedMenus = _defaultAllowedMenus();
    if (permissionData != null) {
      allowedMenus = _allowedMenusFromData(permissionData);
    }

    final effectiveMenuIndex = _effectiveMenuIndex(allowedMenus);
    final navMenus = allowedMenus;
    final currentNavIndex = navMenus.indexOf(effectiveMenuIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree(
          key: ValueKey('mobile_menu_$effectiveMenuIndex'),
          child: _buildPage(effectiveMenuIndex),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: BottomNavigationBar(
              currentIndex: currentNavIndex < 0 ? 0 : currentNavIndex,
              onTap: (index) {
                setState(() => _selectedMenuIndex = navMenus[index]);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: const Color(0xFF2563EB),
              unselectedItemColor: const Color(0xFF94A3B8),
              selectedLabelStyle: GoogleFonts.sarabun(
                  fontWeight: FontWeight.w700, fontSize: 11),
              unselectedLabelStyle: GoogleFonts.sarabun(
                  fontWeight: FontWeight.w500, fontSize: 11),
              type: BottomNavigationBarType.fixed,
              items: navMenus.map(_buildNavItem).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instanceFor(
              app: Firebase.app(), databaseId: 'school')
          .collection('MobilePermissions')
          .doc(_userRole)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildMobileScaffold(data);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instanceFor(
                  app: Firebase.app(), databaseId: 'school')
              .collection('Permissions')
              .doc(_userRole)
              .snapshots(),
          builder: (context, fallbackSnapshot) {
            if (fallbackSnapshot.hasData && fallbackSnapshot.data!.exists) {
              final data =
                  fallbackSnapshot.data!.data() as Map<String, dynamic>;
              return _buildMobileScaffold(data);
            }

            return _buildMobileScaffold(null);
          },
        );
      },
    );
  }
}
