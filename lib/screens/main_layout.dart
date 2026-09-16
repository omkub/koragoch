import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
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
import '../utils/profile_image.dart';

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
  int _pendingResetCount = 0;
  Map<String, dynamic>? _editData;
  Map<String, dynamic>? _permissionData;
  final _firebaseService = FirebaseService();
  late final List<Widget> _cachedScreens = _buildScreens();

  // 🔍 ระดับการซูมของเนื้อหา (body) — ไม่กระทบแถบเมนูด้านซ้าย
  static const double _minZoom = 0.6;
  static const double _maxZoom = 1.6;
  static const double _zoomStep = 0.1;
  double _bodyZoom = 1.0;

  // ข้อมูลผู้ใช้ที่ล็อกอิน สำหรับการ์ดโปรไฟล์ท้ายแถบเมนู
  String _userFullName = '';
  String _userAcademicStanding = '';
  String _userProfileImage = '';
  // ตัวระบุตัวตนจาก cache ใช้หาแถวใน Teachers ตอนรีเฟรชข้อมูลจากคลาวด์
  dynamic _cachedIdUser;
  String _cachedUsername = '';

  void _changeZoom(double delta) {
    final next = (_bodyZoom + delta).clamp(_minZoom, _maxZoom);
    if (next != _bodyZoom) setState(() => _bodyZoom = next);
  }

  void _resetZoom() {
    if (_bodyZoom != 1.0) setState(() => _bodyZoom = 1.0);
  }

  /// ห่อเนื้อหาให้ย่อ/ขยายได้ โดยยังจัด layout ตามพื้นที่จริง
  /// (ให้ความรู้สึกเหมือนซูมของเบราว์เซอร์ ไม่ใช่แค่ขยายภาพจนล้นขอบ)
  ///
  /// สำคัญ: หลายหน้าจัด layout จาก MediaQuery.size ไม่ใช่ constraints
  /// (เช่น ความกว้างตารางในหน้าประวัติการลา) ถ้าไม่ขยาย MediaQuery ให้ด้วย
  /// เนื้อหาจะถูกย่อลงแต่ไม่ขยายกลับมาเต็มกรอบ เหลือพื้นที่ว่างด้านข้าง
  Widget _buildZoomableBody(Widget child) {
    if (_bodyZoom == 1.0) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.of(context);
        final logicalWidth = constraints.maxWidth / _bodyZoom;
        final logicalHeight = constraints.maxHeight / _bodyZoom;

        // ใช้ FittedBox แทน Transform + OverflowBox:
        // Transform ส่ง constraints เดิมต่อให้ลูก ต้องปลดด้วย OverflowBox ก่อน
        // แต่ OverflowBox มีขนาดเท่าพื้นที่จริง ทำให้การกดใกล้ขอบขวา/ล่าง
        // ถูกตีว่าอยู่นอกกรอบจนกดไม่ติด (เช่น ปุ่มสามจุดท้ายแถว)
        // FittedBox ให้ลูกกำหนดขนาดเองแล้วย่อทั้งก้อน พร้อมแปลงพิกัดสัมผัส
        // ให้ตรงกับที่เห็นบนจอ ทุกจุดจึงกดได้ตามปกติ
        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: logicalWidth,
            height: logicalHeight,
            child: MediaQuery(
              data: mq.copyWith(
                size: Size(
                    mq.size.width / _bodyZoom, mq.size.height / _bodyZoom),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

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
    _loadPendingResets();
  }

  Future<void> _loadPendingResets() async {
    final count = await _firebaseService.getPendingResetCountFromSupabase();
    if (mounted) setState(() => _pendingResetCount = count);
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    String cUser = prefs.getString('currentUser') ?? 'ผู้ดูแลระบบ';
    String role = prefs.getString('userRole') ?? '';

    if (role.isEmpty) role = 'ครู';

    // ข้อมูลเต็มของผู้ใช้ถูกเก็บไว้ตอนเข้าสู่ระบบ และอัปเดตทุกครั้งที่แก้โปรไฟล์
    String fullName = '';
    String standing = '';
    String photo = '';
    final cachedJson = prefs.getString('userFullDataJson');
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        _cachedIdUser = decoded['id_user'];
        _cachedUsername = (decoded['username'] ?? '').toString().trim();
        fullName =
            (decoded['fullName'] ?? decoded['name'] ?? '').toString().trim();
        standing = (decoded['academicStanding'] ??
                decoded['วิทยฐานะ'] ??
                '')
            .toString()
            .trim();
        photo = (decoded['profileImage'] ?? '').toString().trim();
      } catch (e) {
        debugPrint('⚠️  อ่านข้อมูลผู้ใช้จากเครื่องไม่สำเร็จ: $e');
      }
    }

    setState(() {
      _currentUser = cUser;
      _userRole = role;
      _userFullName = fullName;
      _userAcademicStanding = standing;
      _userProfileImage = photo;
    });

    _loadPermissions();
    _refreshUserFromCloud(cUser);
  }

  /// ข้อมูลใน SharedPreferences เป็นสแนปช็อตตอนล็อกอิน ถ้าผู้ใช้เพิ่งอัปโหลด
  /// รูปโปรไฟล์ (หรือแอดมินเพิ่งตั้งให้) รูปจะยังไม่ขึ้นจนกว่าจะล็อกอินใหม่
  /// จึงดึงข้อมูลล่าสุดจาก Supabase มาทับเบื้องหลังครับ 🥇🏆
  Future<void> _refreshUserFromCloud(String fullName) async {
    try {
      final serverData = await _firebaseService.findTeacher(
        idUser: _cachedIdUser,
        username: _cachedUsername,
        fullName: fullName.isNotEmpty ? fullName : _userFullName,
      );
      if (serverData == null || !mounted) return;

      final photo = (serverData['profileImage'] ?? '').toString().trim();
      if (photo != _userProfileImage) {
        setState(() => _userProfileImage = photo);
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('userFullDataJson');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) {
          final merged = Map<String, dynamic>.from(decoded)
            ..['profileImage'] = photo;
          await prefs.setString('userFullDataJson', jsonEncode(merged));
        }
      }
    } catch (e) {
      debugPrint('⚠️  รีเฟรชรูปโปรไฟล์จากคลาวด์ไม่สำเร็จ: $e');
    }
  }

  /// ชื่อที่แสดงในการ์ดโปรไฟล์ — ใช้ชื่อ-นามสกุลจริงถ้ามี
  String get _displayName =>
      _userFullName.isNotEmpty ? _userFullName : _currentUser;

  /// บรรทัดใต้ชื่อ: "ครู ชำนาญการพิเศษ" (ถ้าไม่มีวิทยฐานะก็แสดงแค่บทบาท)
  String get _displaySubtitle {
    final role = _currentUser == 'ผู้ดูแลระบบ' ? 'ผู้ดูแลระบบ' : _userRole;
    if (_userAcademicStanding.isEmpty ||
        _userAcademicStanding.contains('ไม่มี') ||
        _userAcademicStanding.contains('เลือก')) {
      return role;
    }
    return '$role $_userAcademicStanding';
  }

  Future<void> _loadPermissions() async {
    final data = await _firebaseService.getPermissionDocFromSupabase(
        'Permissions', _userRole);
    if (mounted) setState(() => _permissionData = data);
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

  List<Widget> _buildScreens() {
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
      const SizedBox.shrink(), // placeholder — LeaveFormScreen สร้างแยกเพราะมี editData
      LeaveHistoryScreen(
        onEdit: (data) {
          setState(() {
            _editData = data;
            _selectedIndex = 2;
          });
        },
      ),
      const UserManagementScreen(),
      const PersonnelScreen(),
      const Center(child: Text('จัดการข้อมูลครูเวน (เร็วๆ นี้)')),
      const LoginLogsScreen(),
      const CalendarScreen(),
    ];
  }

  Widget _getScreen(int index) {
    if (index == 2) {
      return LeaveFormScreen(
        key: ValueKey('edit_${_editData?['requestId'] ?? 'new'}'),
        initialData: _editData,
        onComplete: () {
          setState(() {
            _editData = null;
            _selectedIndex = 3;
          });
        },
      );
    }
    return _cachedScreens[index];
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
      body: Builder(
          builder: (context) {
            int effectiveIndex = _selectedIndex;
            if (_userRole.contains('ครู') && effectiveIndex == 0)
              effectiveIndex = 2;
            if (effectiveIndex >= _cachedScreens.length) effectiveIndex = 0;

            if (_permissionData == null) {
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
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: _buildZoomableBody(_selectedIndex == -1
                            ? const MobileProfileScreen()
                            : _getScreen(effectiveIndex)),
                      ),
                    ),
                  ),
                ],
              );
            }

            final data = _permissionData!;
            List<int> allowed = [];

            bool isTruthy(dynamic v) {
              if (v == null) return false;
              if (v == true || v == 1) return true;
              final s = v.toString().trim().toUpperCase();
              return s == 'TRUE' || s == '1';
            }

            for (int i = 0; i <= 8; i++) {
              final val = data[i.toString()];
              if (isTruthy(val)) allowed.add(i);
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
              if (!allowed.contains(idx) && isTruthy(data[key])) {
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
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: _buildZoomableBody(_selectedIndex == -1
                          ? const MobileProfileScreen()
                          : _getScreen(effectiveIndex)),
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
                      color: Colors.black.withValues(alpha: 0.05),
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

  // 🔍 ปุ่มย่อ/ขยายเนื้อหา — มีผลเฉพาะ body ไม่กระทบแถบเมนูนี้
  Widget _buildZoomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildZoomButton(
            icon: Icons.remove_rounded,
            tooltip: 'ย่อขนาดเนื้อหา',
            onPressed: _bodyZoom > _minZoom ? () => _changeZoom(-_zoomStep) : null,
          ),
          Expanded(
            child: InkWell(
              onTap: _resetZoom,
              borderRadius: BorderRadius.circular(8),
              child: Tooltip(
                message: 'คลิกเพื่อกลับเป็น 100%',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${(_bodyZoom * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sarabun(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildZoomButton(
            icon: Icons.add_rounded,
            tooltip: 'ขยายขนาดเนื้อหา',
            onPressed: _bodyZoom < _maxZoom ? () => _changeZoom(_zoomStep) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Icon(icon,
              size: 20,
              color: enabled ? const Color(0xFF0F172A) : Colors.black26),
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isWeb, List<int> allowedMenus) {
    return Container(
      width: 280,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isWeb
            ? Border(right: BorderSide(color: Colors.black.withValues(alpha: 0.05)))
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
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)
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
                  clipBehavior: Clip.antiAlias,
                  // โลโก้เดียวกับหน้าเข้าสู่ระบบ
                  child: Image.asset('image/Logo.jpg', fit: BoxFit.cover),
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

          // 🔍 แถบปรับขนาดเนื้อหา
          _buildZoomBar(),
          const SizedBox(height: 12),

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
                        ProfileAvatar(
                          imageUrl: _userProfileImage,
                          size: 36,
                          name: _displayName.isNotEmpty ? _displayName : '?',
                          backgroundColor: const Color(0xFFE2E8F0),
                          foregroundColor: Colors.black87,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_displayName,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                              Text(_displaySubtitle,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 11, color: Colors.black38),
                                  overflow: TextOverflow.ellipsis),
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
          // กลับออกจากหน้าโปรไฟล์ = อาจเพิ่งเปลี่ยนรูป จึงโหลดข้อมูลใหม่
          final wasOnProfile = _selectedIndex == -1;
          setState(() => _selectedIndex = index);
          if (wasOnProfile) _loadUser();
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
