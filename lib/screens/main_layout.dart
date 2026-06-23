import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'leave_form_screen.dart';
import 'leave_history_screen.dart';
import 'user_management_screen.dart';
import 'personnel_screen.dart';
import 'report_overview_screen.dart';
import 'login_screen.dart';
import 'mobile/mobile_profile_screen.dart';
import 'login_logs_screen.dart'; // 🛡️ นำเข้าหน้าประวัติการเข้าใช้งาน 🥇🏆
import 'calendar_screen.dart'; // 📅 นำเข้าหน้าปฏิทินกิจกรรม 🥇🏆

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String _currentUser = 'ผู้ดูแลระบบ';
  String _userRole = 'ครู';
  List<int>? _allowedMenus;
  int _pendingResetCount = 0; // จำนวนคำขอรีเซ็ตรหัสที่รออยู่
  Map<String, dynamic>? _editData; // 📝 ข้อมูลสำหรับแก้ไขใบลาครับ

  Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove('isLoggedIn');
    await prefs.remove('loginAt');
    await prefs.remove('currentUser');
    await prefs.remove('userRole');
    await prefs.remove('userFullDataJson');
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
    _listenToPendingResets();
  }

  // 🔔 ฟังการแจ้งเตือนลืมรหัสแบบ Real-time
  void _listenToPendingResets() {
    FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'school')
        .collection('Teachers')
        .where('forgotPasswordStatus', isEqualTo: 'waiting')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _pendingResetCount = snapshot.docs.length);
      }
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    String cUser = prefs.getString('currentUser') ?? 'ผู้ดูแลระบบ';
    String role = prefs.getString('userRole') ?? '';

    // 🔥 บังคับโหลดสิทธิ์ใหม่จาก Firestore ทุกครั้งเพื่อให้มั่นใจว่า Role ถูกต้องครับ 🥇🏆
    try {
      final db = FirebaseFirestore.instanceFor(
          app: Firebase.app(), databaseId: 'school');

      // ค้นหาจากฟิลด์ fullName ก่อน หากไม่พบให้ค้นหาจากฟิลด์ name (เพื่อรองรับรูปแบบของแอดมิน)
      var query = await db
          .collection('Teachers')
          .where('fullName', isEqualTo: cUser)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await db
            .collection('Teachers')
            .where('name', isEqualTo: cUser)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first.data();
        role = (doc['role'] ?? doc['permission'] ?? 'ครู').toString().trim();
        await prefs.setString('userRole', role);
      } else {
        role = 'ครู'; // ถ้าระบบหาในฐานข้อมูลไม่เจอจริงๆ ถึงจะให้เป็นค่าเริ่มต้น
      }
    } catch (_) {
      role = role.isEmpty ? 'ครู' : role;
    }

    setState(() {
      _currentUser = cUser;
      _userRole = role;
    });
  }

  bool _hasAccess(int index) {
    // 👑 แอดมินต้องเห็นเมนูจัดการระบบเสมอ (index 4) เพื่อแก้สิทธิ์คืนได้ครับ 🛡️
    if (index == 4 &&
        (_userRole.contains('ผู้ดูแลระบบ') || _currentUser == 'ผู้ดูแลระบบ'))
      return true;

    // 🛡️ สำหรับเมนูอื่นๆ ให้ดูตามรายการที่ได้รับอนุญาตจริงจากฐานข้อมูลครับ
    if (_allowedMenus == null) return false;
    return _allowedMenus!.contains(index);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearSessionPrefs(prefs);
    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (ctx) => const LoginScreen()));
    }
  }

  List<Widget> _getScreens() {
    return [
      DashboardScreen(
        onNavigate: (index) {
          if (mounted) {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
      ),
      const ReportOverviewScreen(),
      LeaveFormScreen(
        key: ValueKey('edit_${_editData?['requestId'] ?? 'new'}'),
        initialData: _editData,
        onComplete: () {
          setState(() {
            _editData = null;
            _selectedIndex = 3; // กลับไปหน้าประวัติครับ
          });
        },
      ),
      LeaveHistoryScreen(
        onEdit: (data) {
          setState(() {
            _editData = data;
            _selectedIndex = 2; // ไปหน้าส่งใบลาครับ
          });
        },
      ),
      const UserManagementScreen(),
      const PersonnelScreen(),
      const Center(child: Text('จัดการข้อมูลครูเวน (เร็วๆ นี้)')),
      const LoginLogsScreen(), // 🛡️ หน้าประวัติการเข้าใช้งาน 🥇🏆
      const CalendarScreen(), // 📅 หน้าปฏิทินกิจกรรม 🥇🏆
    ];
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              centerTitle: true,
              title: Text('ระบบวันลา',
                  style: GoogleFonts.sarabun(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              actions: [
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded,
                      size: 20, color: Colors.blueGrey),
                ),
              ],
            )
          : null,
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instanceFor(
                  app: Firebase.app(), databaseId: 'school')
              .collection(
                  'Permissions') // 🛡️ แก้ไขกลับไปใช้ Permissions เพื่อให้ตรงกับฐานข้อมูลการกำหนดสิทธิ์ 🥇🏆
              .doc(_userRole)
              .snapshots(),
          builder: (context, snapshot) {
            final screens = _getScreens();
            // กำหนด index ที่จะแสดง
            int effectiveIndex = _selectedIndex;
            if (_userRole.contains('ครู') && effectiveIndex == 0)
              effectiveIndex = 2;
            if (effectiveIndex >= screens.length) effectiveIndex = 0;

            // ถ้ากำลังโหลดอยู่ แสดง loading
            if (snapshot.connectionState == ConnectionState.waiting &&
                _userRole.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // ถ้าเกิดข้อผิดพลาดหรือไม่มีข้อมูล ให้สิทธิ์พื้นฐาน (ส่งใบลา + ประวัติ)
            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              final defaultAllowed = (_userRole.contains('ผู้ดูแลระบบ') ||
                      _currentUser == 'ผู้ดูแลระบบ')
                  ? [0, 1, 2, 3, 4, 5, 6, 7, 8]
                  : [0, 2, 3];
              return Row(
                children: [
                  if (!isMobile) _buildSidebar(true, defaultAllowed),
                  Expanded(
                    child: Material(
                      color: const Color(0xFFF1F5F9),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        child: _selectedIndex == -1
                            ? const MobileProfileScreen()
                            : screens[effectiveIndex],
                      ),
                    ),
                  ),
                ],
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            List<int> allowed = [];

            for (int i = 0; i <= 8; i++) {
              final val = data[i.toString()];
              if (val == true || val.toString().toUpperCase() == 'TRUE')
                allowed.add(i);
            }

            final Map<String, int> oldMapping = {
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
            oldMapping.forEach((key, idx) {
              if (!allowed.contains(idx) &&
                  (data[key] == true ||
                      data[key].toString().toUpperCase() == 'TRUE')) {
                allowed.add(idx);
              }
            });

            if (_userRole.contains('ผู้ดูแลระบบ') ||
                _currentUser == 'ผู้ดูแลระบบ') {
              if (!allowed.contains(4)) allowed.add(4);
            }
            if (_userRole.contains('ครู')) allowed.remove(0);
            allowed.sort();

            return Row(
              children: [
                if (!isMobile) _buildSidebar(true, allowed),
                Expanded(
                  child: Material(
                    color: const Color(0xFFF1F5F9),
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: _selectedIndex == -1
                          ? const MobileProfileScreen()
                          : screens[effectiveIndex],
                    ),
                  ),
                ),
              ],
            );
          }),
      bottomNavigationBar: isMobile
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2))
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _getMobileIndex(_selectedIndex),
                onTap: (index) =>
                    setState(() => _selectedIndex = _getGlobalIndex(index)),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFF0F172A),
                unselectedItemColor: Colors.black26,
                selectedLabelStyle: GoogleFonts.sarabun(
                    fontSize: 12, fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.sarabun(fontSize: 12),
                items: const [
                  BottomNavigationBarItem(
                      icon: Icon(Icons.add_circle_outline),
                      activeIcon: Icon(Icons.add_circle),
                      label: 'ส่งใบลา'),
                  BottomNavigationBarItem(
                      icon: Icon(Icons.history),
                      activeIcon: Icon(Icons.history_rounded),
                      label: 'ประวัติการลา'),
                ],
              ),
            )
          : null,
    );
  }

  int _getMobileIndex(int index) {
    if (index == 2) return 0;
    if (index == 3) return 1;
    return 0;
  }

  int _getGlobalIndex(int mobileIndex) {
    if (mobileIndex == 0) return 2;
    if (mobileIndex == 1) return 3;
    return 2;
  }

  Widget _buildSidebar(bool isWeb, List<int> allowedMenus) {
    return Container(
      width: 280,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isWeb
            ? Border(right: BorderSide(color: Colors.black.withOpacity(0.05)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.dashboard_customize,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ระบบวันลา',
                        style: GoogleFonts.sarabun(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    Text('ระบบข้อมูลสำหรับครู',
                        style: GoogleFonts.sarabun(
                            fontSize: 10,
                            color: Colors.black38,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (allowedMenus.contains(0))
                  _buildMenuItem(0, Icons.dashboard_outlined, 'แดชบอร์ด'),
                if (allowedMenus.contains(1))
                  _buildMenuItem(1, Icons.bar_chart_rounded, 'รายงานสรุปการลา'),
                if (allowedMenus.contains(2))
                  _buildMenuItem(2, Icons.add_circle_outline, 'ส่งใบลา'),
                if (allowedMenus.contains(3))
                  _buildMenuItem(3, Icons.history_rounded, 'ประวัติการลา'),
                if (allowedMenus.contains(4))
                  _buildMenuItem(4, Icons.settings_outlined, 'จัดการระบบ',
                      badge: _pendingResetCount),
                if (allowedMenus.contains(5))
                  _buildMenuItem(
                      5, Icons.people_outline, 'บุคลากร (กลุ่มสาระ)'),
                if (allowedMenus.contains(6))
                  _buildMenuItem(
                      6, Icons.assignment_ind_outlined, 'จัดการข้อมูลครูเวร'),
                if (allowedMenus.contains(7))
                  _buildMenuItem(
                      7, Icons.security_rounded, 'ประวัติการเข้าใช้งาน'),
                if (allowedMenus.contains(8))
                  _buildMenuItem(
                      8, Icons.calendar_month_rounded, 'ปฏิทินกิจกรรมส่วนกลาง'),
              ],
            ),
          ),

          // Footer Profile
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _selectedIndex == -1
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedIndex = -1),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(10)),
                          child: Center(
                              child: Text(
                                  _currentUser.isNotEmpty
                                      ? _currentUser[0]
                                      : '?',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_currentUser,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                  _currentUser == 'ผู้ดูแลระบบ'
                                      ? 'ผู้ดูแลระบบ'
                                      : _userRole,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 11, color: Colors.black38)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded,
                      size: 18, color: Colors.black38),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String label,
      {int badge = 0}) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          if (Navigator.canPop(context)) Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF8FAFC) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? const Border(
                    left: BorderSide(color: Color(0xFF0F172A), width: 3))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 22,
                  color: isSelected ? const Color(0xFF0F172A) : Colors.black45),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.sarabun(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color:
                        isSelected ? const Color(0xFF0F172A) : Colors.black45,
                  ),
                ),
              ),
              // 🔴 Badge แจ้งเตือนจำนวนคำขอรีเซ็ตรหัสที่รออยู่
              if (badge > 0)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
