import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/firebase_service.dart';
import '../login_screen.dart';
import '../personnel_screen.dart';
import 'mobile_password_reset_screen.dart'; // 🔐 เพิ่ม Import สำหรับหน้าอนุมัติรีเซ็ตรหัสครับ 🥇
import '../user_management_screen.dart'; // 👤 เพิ่มหน้าจัดการผู้ใช้ครับ
import '../../utils/profile_image.dart';

class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  // User Data
  String _currentUserName = "";
  Map<String, dynamic>? _teacherData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  bool _showPasswordReset = false;
  String _userRole = ""; // 🔥 เพิ่มตัวแปรเก็บ Role ครับ 🕵️‍♂️🥇
  bool _showPersonnel = false; // 🔥 ตัวแปรสำหรับคุมการแสดงหน้าย่อยครับ 🥇🏆
  bool _showUserManagement = false; // 👤 เพิ่มตัวแปรคุมหน้าจัดการผู้ใช้ครับ 🥇

  Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove('isLoggedIn');
    await prefs.remove('loginAt');
    await prefs.remove('currentUser');
    await prefs.remove('userRole');
    await prefs.remove('userFullDataJson');
  }

  // Controllers for editing
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  // 📝 Dropdown Data & Selection
  String? _selectedAcademicStanding;
  String? _selectedDepartment;
  String? _selectedPosition;

  List<String> _academicsList = ['ไม่มีวิทยฐานะ'];
  List<String> _departmentsList = [];
  List<String> _positionsList = [];

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _fullNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    // 🚀 โหลดข้อมูล Dropdown จากฐานข้อมูลก่อนครับ 🥇🏆
    try {
      final results = await Future.wait([
        _firebaseService.getAcademics(),
        _firebaseService.getDepartments(),
        _firebaseService.getPositions(),
      ]);

      setState(() {
        if (results[0].isNotEmpty) _academicsList = results[0];
        if (!_academicsList.contains('ไม่มีวิทยฐานะ'))
          _academicsList.insert(0, 'ไม่มีวิทยฐานะ');
        _departmentsList = results[1];
        _positionsList = results[2];
      });
    } catch (e) {
      debugPrint("Error loading dropdown data: $e");
    }

    final prefs = await SharedPreferences.getInstance();

    // 🚀 ขั้นที่ 1: ดึงจาก Cache มาโชว์ทันที (0 วินาที!) 🥇🏆
    final cachedJson = prefs.getString('userFullDataJson');
    if (cachedJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        setState(() {
          _teacherData = decoded;
          _currentUserName = decoded['fullName'] ?? decoded['name'] ?? '';
          _userRole = decoded['role'] ?? decoded['permission'] ?? 'ครู';

          _phoneController.text =
              decoded['phone'] ?? decoded['phoneNumber'] ?? '';
          _fullNameController.text =
              decoded['fullName'] ?? decoded['name'] ?? '';
          _usernameController.text = decoded['username'] ?? '';

          final dbStanding = decoded['academicStanding']?.toString() ?? '';
          _selectedAcademicStanding = _academicsList.contains(dbStanding)
              ? dbStanding
              : _academicsList.first;

          final dbDept = decoded['department']?.toString() ?? '';
          _selectedDepartment =
              _departmentsList.contains(dbDept) ? dbDept : null;

          final dbPos = decoded['position']?.toString() ?? '';
          _selectedPosition = _positionsList.contains(dbPos) ? dbPos : null;

          _isLoading = false;
        });
      } catch (e) {
        debugPrint("Cache decode error: $e");
      }
    }

    // 🚀 ขั้นที่ 2: ถ้าไม่มี Cache เลย ค่อยเปิด Loading ครับ
    if (_teacherData == null) {
      setState(() => _isLoading = true);
    }

    // 🚀 ขั้นที่ 3: แอบ Sync ข้อมูลล่าสุดจาก Cloud อยู่เบื้องหลัง (Background Sync)
    _currentUserName = prefs.getString('currentUser') ?? '';
    if (_currentUserName.isNotEmpty) {
      try {
        final serverData =
            await _firebaseService.searchTeacherByName(_currentUserName);
        if (serverData != null && mounted) {
          setState(() {
            _teacherData = serverData;
            _phoneController.text =
                serverData['phone'] ?? serverData['phoneNumber'] ?? '';
            _fullNameController.text =
                serverData['fullName'] ?? serverData['name'] ?? '';
            _usernameController.text = serverData['username'] ?? '';

            final cloudStanding =
                serverData['academicStanding']?.toString() ?? '';
            _selectedAcademicStanding = _academicsList.contains(cloudStanding)
                ? cloudStanding
                : _academicsList.first;

            final cloudDept = serverData['department']?.toString() ?? '';
            _selectedDepartment =
                _departmentsList.contains(cloudDept) ? cloudDept : null;

            final cloudPos = serverData['position']?.toString() ?? '';
            _selectedPosition =
                _positionsList.contains(cloudPos) ? cloudPos : null;

            _isLoading = false;
          });

          // 🛡️ อัปเดต Cache ให้เป็นปัจจุบันที่สุดด้วยระบบป้องกัน JSON Error ขั้นสูงสุด 🥇🏆🏎️
          final safeJson = jsonEncode(serverData, toEncodable: (item) {
            if (item is DateTime) return item.toIso8601String();
            return item.toString();
          });
          await prefs.setString('userFullDataJson', safeJson);
        }
      } catch (e) {
        debugPrint("Background sync error: $e");
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_teacherData == null) return;
    setState(() => _isSaving = true);

    try {
      final docId = _teacherData!['docId'] ?? _teacherData!['id'];
      if (docId == null) throw "ไม่พบ ID ของข้อมูลครับ";

      final newData = {
        'phone': _phoneController.text.trim(),
        'position': _selectedPosition,
        'fullName': _fullNameController.text.trim(),
        'department': _selectedDepartment,
        'academicStanding': _selectedAcademicStanding,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // 🚀 ขั้นที่ 1: อัปเดตไปยัง Cloud ตรงๆ ด้วย ID ครับ (ไวสุดๆ)
      await _firebaseService.updateTeacherById(docId, newData);

      // 🚀 ขั้นที่ 2: อัปเดต Cache ในเครื่องเพื่อให้หน้าอื่นๆ (เช่น ส่งใบลา) เห็นข้อมูลใหม่ทันทีครับ 🥇🏆
      final prefs = await SharedPreferences.getInstance();
      final updatedData = {..._teacherData!, ...newData};

      // 🛡️ ป้องกัน Json Encode Error สไตล์ครอบจักรวาลครับ 🥇🏆🏎️
      final safeJson = jsonEncode(updatedData, toEncodable: (item) {
        if (item is DateTime) return item.toIso8601String();
        return item.toString();
      });
      await prefs.setString('userFullDataJson', safeJson);

      // 🚀 ขั้นที่ 3: อัปเดต UI ทันทีไม่ต้องรอโหลดใหม่ครับ
      setState(() {
        _teacherData = updatedData;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('บันทึกข้อมูลสำเร็จแล้วครับ! 🎉'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    if (_teacherData == null) return;

    try {
      final ImagePicker picker = ImagePicker();

      // 🚀 แสดงตัวเลือกให้คุณครูครับ
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600, // ควบคุมขนาดภาพไม่ให้ใหญ่เกินความจำเป็นครับ
        imageQuality: 35, // บีบอัดคุณภาพเหลือ 35% เพื่อความไวสูงสุดครับ ⚡
      );

      if (image != null) {
        setState(() => _isUploadingImage = true);

        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final extension = image.name.split('.').last;
        final dataUrl = "data:image/$extension;base64,$base64String";

        // 🚀 แสดงสถานะกำลังอัปโหลด
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Row(
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 16),
                Text('กำลังส่งรูปโปรไฟล์ขึ้นระบบ... ✅'),
              ],
            ),
            duration: Duration(minutes: 1),
          ));
        }

        final resData = await _firebaseService.uploadDriveFile(
          fileData: dataUrl,
          fileName:
              '${DateTime.now().millisecondsSinceEpoch}_Profile_${_currentUserName}.$extension',
          mimeType: 'image/$extension',
          folderType: 'profile',
          folderId: FirebaseService.driveProfileFolderId,
        );
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final String imageUrl = resData['url'];
        final String oldImageUrl = _teacherData?['profileImage'] ?? '';

        await _firebaseService
            .updateTeacherData(_currentUserName, {'profileImage': imageUrl});

        // 🔥 ลบรูปเดิมใน Drive ทิ้งเพื่อไม่ให้หนักเครื่องครับ 🥇🏆
        if (oldImageUrl.isNotEmpty && oldImageUrl != imageUrl) {
          await _firebaseService.deleteDriveFileStrict(oldImageUrl);
        }

        final prefs = await SharedPreferences.getInstance();
        final updatedData = {..._teacherData!, 'profileImage': imageUrl};

        // 🛡️ ป้องกัน Json Encode Error แบบ 100% ครอบจักรวาลครับ (minified:hl / Timestamp) 🥇🏆🏎️
        final safeJson = jsonEncode(updatedData, toEncodable: (item) {
          if (item is DateTime) return item.toIso8601String();
          return item.toString();
        });
        await prefs.setString('userFullDataJson', safeJson);

        await _loadUserAndData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('อัปเดตรูปโปรไฟล์สำเร็จแล้วครับ! ✨'),
              backgroundColor: Color(0xFF10B981)));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('อัปโหลดล้มเหลว'),
            content: Text(
                'เกิดข้อผิดพลาด: $e\n(คำแนะนำ: ลองเลือกรูปใหม่อีกครั้งครับ)'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ตกลง'))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("ออกจากระบบ",
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: Text("คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบบัญชีของคุณ?",
            style: GoogleFonts.sarabun(fontSize: 15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("ยกเลิก",
                  style: GoogleFonts.sarabun(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: Text("ยืนยัน",
                style: GoogleFonts.sarabun(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await _clearSessionPrefs(prefs);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    }
  }

  // 🖼️ การแปลงลิงก์รูปย้ายไปอยู่ที่ lib/utils/profile_image.dart แล้ว
  // ใช้ widget ProfileAvatar แทน (เดิมต่อ ?t=timestamp ท้าย URL ทำให้ URL
  // เปลี่ยนทุกครั้งที่ build → โหลดรูปใหม่ไม่หยุดและภาพกระพริบครับ)

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB))));

    return Material(
      color: const Color(0xFFF4F7FC),
      child: SafeArea(
        bottom: false,
        child: _showPasswordReset
            ? MobilePasswordResetScreen(
                onBack: () => setState(() => _showPasswordReset = false))
            : _showUserManagement
                ? UserManagementScreen(
                    onBack: () => setState(() => _showUserManagement = false))
                : _showPersonnel
                    ? PersonnelScreen(
                        onBack: () => setState(() => _showPersonnel = false))
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            _buildProfileCard(),
                            const SizedBox(height: 24),
                            _buildInfoSection(),
                            const SizedBox(height: 24),

                            // 🔥 ส่วนเมนูสำหรับแอดมิน (Admin Tools) 🕵️‍♂️🥇
                            if (_userRole.contains('ผู้ดูแลระบบ'))
                              _buildAdminSection(),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("จัดการบัญชี",
                  style: GoogleFonts.sarabun(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              Text("โปรไฟล์ส่วนตัว",
                  style: GoogleFonts.sarabun(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -1)),
            ],
          ),
          IconButton(
            onPressed: _logout,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.logout_rounded,
                  color: Color(0xFFEF4444), size: 24),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final String? profileImg = _teacherData?['profileImage'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)
                  ],
                ),
                child: ClipOval(
                  child: _isUploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : ProfileAvatar(
                          imageUrl: profileImg,
                          size: 122, // 130 ลบขอบขาว 4 ด้าน
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF94A3B8),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadProfileImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3)),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(_currentUserName,
              style: GoogleFonts.sarabun(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(_teacherData?['department'] ?? 'กลุ่มสาระการเรียนรู้',
              style: GoogleFonts.sarabun(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatItem("ประเภท", _teacherData?['role'] ?? 'ครู'),
              Container(
                  width: 1,
                  height: 30,
                  color: Colors.grey.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 24)),
              _buildStatItem("สังกัด", "สพฐ."),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.sarabun(
                fontSize: 11,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.sarabun(
                fontSize: 15,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ข้อมูลส่วนตัว",
                  style: GoogleFonts.sarabun(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A))),
              TextButton.icon(
                onPressed: () {
                  if (_isEditing) {
                    _saveProfile();
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_rounded,
                    size: 18, color: const Color(0xFF2563EB)),
                label: Text(_isEditing ? "บันทึก" : "แก้ไข",
                    style: GoogleFonts.sarabun(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInfoItem(
              Icons.person_outline_rounded, "ชื่อ-นามสกุล", _fullNameController,
              isEdit: _isEditing),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildInfoItem(Icons.account_circle_outlined,
                      "ชื่อผู้ใช้งาน (Username)", _usernameController,
                      isEdit: false)),
              const SizedBox(width: 16),
              Expanded(child: _buildPasswordItem()),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdownItem(
              Icons.work_outline_rounded,
              "ตำแหน่ง",
              _selectedPosition,
              _positionsList,
              (v) => setState(() => _selectedPosition = v)),
          const SizedBox(height: 16),
          _buildDropdownItem(
              Icons.business_outlined,
              "กลุ่มสาระการเรียนรู้",
              _selectedDepartment,
              _departmentsList,
              (v) => setState(() => _selectedDepartment = v)),
          const SizedBox(height: 16),
          _buildAcademicStandingDropdown(),
          const SizedBox(height: 16),
          _buildInfoItem(
              Icons.phone_iphone_rounded, "เบอร์โทรศัพท์", _phoneController,
              isEdit: _isEditing, keyboardType: TextInputType.phone),
        ],
      ),
    );
  }

  /// ช่องรหัสผ่าน — ไม่แสดงรหัสจริงอีกต่อไป
  ///
  /// ตั้งแต่ย้ายไป Supabase Auth รหัสผ่านถูกแฮชด้วย bcrypt ไม่มีใครอ่านกลับได้
  /// (รวมถึงแอดมิน) จึงเปลี่ยนจาก "ช่องแก้ข้อความ" เป็นปุ่มตั้งรหัสใหม่แทน
  ///
  /// ของเดิมเป็นช่องที่แก้ได้แต่ _saveProfile ไม่เคยส่งค่าไปบันทึก ครูแก้แล้ว
  /// ค่าเด้งกลับทุกครั้ง — ถือเป็นบั๊กที่มีมาก่อนหน้านี้
  Widget _buildPasswordItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text('รหัสผ่าน',
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showChangePasswordDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Text('••••••••',
                    style: GoogleFonts.sarabun(
                        fontSize: 15,
                        letterSpacing: 2,
                        color: const Color(0xFF94A3B8))),
                const Spacer(),
                Text('เปลี่ยนรหัสผ่าน',
                    style: GoogleFonts.sarabun(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2563EB))),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFF2563EB)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// หน้าต่างตั้งรหัสผ่านใหม่ — ยืนยันด้วยรหัสปัจจุบันก่อนเสมอ
  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final current = currentCtrl.text.trim();
            final next = newCtrl.text.trim();
            final confirm = confirmCtrl.text.trim();

            if (current.isEmpty || next.isEmpty) {
              setLocal(() => errorText = 'กรุณากรอกให้ครบทุกช่องครับ');
              return;
            }
            if (next.length < 6) {
              setLocal(() => errorText = 'รหัสผ่านใหม่ต้องยาวอย่างน้อย 6 ตัว');
              return;
            }
            if (next != confirm) {
              setLocal(() => errorText = 'รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน');
              return;
            }

            setLocal(() {
              isSaving = true;
              errorText = null;
            });

            final message = await _changePassword(current, next);

            if (message != null) {
              setLocal(() {
                isSaving = false;
                errorText = message;
              });
              return;
            }

            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('✅ เปลี่ยนรหัสผ่านเรียบร้อยแล้วครับ',
                    style: GoogleFonts.sarabun()),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ));
            }
          }

          Widget field(String label, TextEditingController ctrl) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: ctrl,
                  obscureText: true,
                  enabled: !isSaving,
                  style: GoogleFonts.sarabun(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: GoogleFonts.sarabun(fontSize: 13),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              );

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('เปลี่ยนรหัสผ่าน',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field('รหัสผ่านปัจจุบัน', currentCtrl),
                field('รหัสผ่านใหม่', newCtrl),
                field('ยืนยันรหัสผ่านใหม่', confirmCtrl),
                if (errorText != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(errorText!,
                        style: GoogleFonts.sarabun(
                            fontSize: 12, color: Colors.red.shade700)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text('ยกเลิก',
                    style: GoogleFonts.sarabun(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('บันทึก',
                        style:
                            GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// เปลี่ยนรหัสผ่านจริง — คืน null ถ้าสำเร็จ หรือข้อความบอกสาเหตุถ้าไม่สำเร็จ
  Future<String?> _changePassword(String current, String next) async {
    final username = (_teacherData?['username'] ?? '').toString().trim();
    if (username.isEmpty) return 'ไม่พบชื่อผู้ใช้ของคุณครูครับ';

    final supabase = Supabase.instance.client;
    final email = FirebaseService.authEmailForUsername(username);

    try {
      // ยืนยันตัวตนด้วยรหัสปัจจุบันก่อน (และได้ session มาใช้ตั้งรหัสใหม่ด้วย)
      await supabase.auth.signInWithPassword(email: email, password: current);
    } on AuthException {
      return 'รหัสผ่านปัจจุบันไม่ถูกต้องครับ';
    } catch (e) {
      return 'เชื่อมต่อระบบยืนยันตัวตนไม่สำเร็จ: $e';
    }

    try {
      await supabase.auth.updateUser(UserAttributes(password: next));
    } catch (e) {
      return 'ตั้งรหัสผ่านใหม่ไม่สำเร็จ: $e';
    }

    // ซิงก์คอลัมน์เดิมไว้ด้วย เพื่อให้ "ทางถอย" ในหน้าล็อกอินยังใช้ได้
    // ระหว่างช่วงเปลี่ยนผ่าน (จะเลิกใช้เมื่อเปิด RLS แล้ว)
    try {
      final docId = (_teacherData?['docId'] ?? _teacherData?['id'])?.toString();
      if (docId != null && docId.isNotEmpty) {
        await _firebaseService.updateTeacherById(docId, {'password': next});
      }
    } catch (e) {
      debugPrint('⚠️  ซิงก์รหัสผ่านลงตาราง Teachers ไม่สำเร็จ: $e');
    }

    // อัปเดตรหัสที่ฟังก์ชัน "จำรหัสผ่าน" เก็บไว้ด้วย ไม่งั้นครั้งหน้าหน้าล็อกอิน
    // จะเติมรหัสเก่าให้อัตโนมัติ แล้วเข้าระบบไม่ได้ทั้งที่ดูเหมือนกรอกครบแล้ว
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('remember_me') ?? false) {
        await prefs.setString('saved_password', next);
      }
    } catch (e) {
      debugPrint('⚠️  อัปเดตรหัสที่จำไว้ไม่สำเร็จ: $e');
    }

    return null;
  }

  Widget _buildInfoItem(IconData icon, String label, TextEditingController ctrl,
      {bool isEdit = false, TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 8),
        isEdit
            ? TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                style: GoogleFonts.sarabun(
                    fontSize: 15,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(ctrl.text.isEmpty ? "-" : ctrl.text,
                    style: GoogleFonts.sarabun(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A))),
              ),
      ],
    );
  }

  Widget _buildAcademicStandingDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.military_tech_outlined,
                size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text("วิทยฐานะ",
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 8),
        _isEditing
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _academicsList.contains(_selectedAcademicStanding)
                        ? _selectedAcademicStanding
                        : _academicsList.first,
                    isExpanded: true,
                    style: GoogleFonts.sarabun(
                        fontSize: 15,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600),
                    items: _academicsList
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedAcademicStanding = v),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(_selectedAcademicStanding ?? "-",
                    style: GoogleFonts.sarabun(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A))),
              ),
      ],
    );
  }

  // 🛠️ Helper สำหรับสร้าง Dropdown แบบมาตรฐานครับ 🥇🏆🏎️
  Widget _buildDropdownItem(IconData icon, String label, String? value,
      List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 8),
        _isEditing
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : null,
                    hint: Text("---เลือก---",
                        style: GoogleFonts.sarabun(
                            fontSize: 14, color: Colors.grey)),
                    isExpanded: true,
                    style: GoogleFonts.sarabun(
                        fontSize: 15,
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600),
                    items: items
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text((value != null && value.isNotEmpty) ? value : "-",
                    style: GoogleFonts.sarabun(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A))),
              ),
      ],
    );
  }

  // 🛠️ เมนูพิเศษสำหรับผู้ดูแลระบบบนมือถือ 🕵️‍♂️🥇🏆
  Widget _buildAdminSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark elegant background for admin
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded,
                  color: Colors.amber, size: 22),
              const SizedBox(width: 12),
              Text("การจัดการสำหรับผู้ดูแลระบบ",
                  style: GoogleFonts.sarabun(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
          const SizedBox(height: 20),
          _buildAdminMenuItem(
            icon: Icons.manage_accounts_rounded,
            title: "จัดการข้อมูลผู้ใช้งาน",
            subtitle: "เพิ่ม/แก้ไข/ลบ และสิทธิการใช้งาน",
            onTap: () => setState(() => _showUserManagement = true),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          _buildAdminMenuItem(
            icon: Icons.people_alt_rounded,
            title: "ทำเนียบบุคลากร",
            subtitle: "ดูรายชื่อแยกตามกลุ่มสาระ",
            onTap: () => setState(() => _showPersonnel = true),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          _buildAdminMenuItem(
            icon: Icons.lock_reset_rounded,
            title: "อนุมัติรีเซ็ตรหัสผ่าน",
            subtitle: "ตรวจสอบและอนุมัติคำขอรีเซ็ตรหัสจากครู",
            onTap: () => setState(() => _showPasswordReset = true),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMenuItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.sarabun(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text(subtitle,
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        ],
      ),
    );
  }
}
