/// หน้าบัญชีและตั้งค่าสำหรับมือถือแบบใหม่ (mobile_v2)
/// แยกออกจาก lib/screens/mobile/ เพื่อไม่ให้กระทบหน้าจอมือถือแบบเก่า
///
/// จัดระเบียบเป็น 4 หมวดหมู่ที่สบายตา:
///   1) การ์ดโปรไฟล์และรูปประจำตัว
///   2) หมวดข้อมูลส่วนตัวและรหัสผ่าน
///   3) หมวดเครื่องมือผู้ดูแลระบบ (เฉพาะแอดมิน)
///   4) หมวดการตั้งค่าแอปและออกจากระบบ
library;

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/firebase_service.dart';
import '../login_screen.dart';
import '../personnel_screen.dart';
import '../mobile/mobile_password_reset_screen.dart';
import '../user_management_screen.dart';
import '../../utils/profile_image.dart';
import '../../utils/school_info.dart';
import '../../widgets/install_app_button.dart';
import '../../widgets/push_toggle_tile.dart';
import 'mobile_pages.dart';

class MobileProfileV2 extends StatefulWidget {
  const MobileProfileV2({super.key});

  @override
  State<MobileProfileV2> createState() => _MobileProfileV2State();
}

class _MobileProfileV2State extends State<MobileProfileV2> {
  final FirebaseService _firebaseService = FirebaseService();

  String _currentUserName = "";
  Map<String, dynamic>? _teacherData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  String _userRole = "";

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

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

  Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove('isLoggedIn');
    await prefs.remove('loginAt');
    await prefs.remove('currentUser');
    await prefs.remove('userRole');
    await prefs.remove('userFullDataJson');
  }

  Future<void> _loadUserAndData() async {
    try {
      final results = await Future.wait([
        _firebaseService.getAcademics(),
        _firebaseService.getDepartments(),
        _firebaseService.getPositions(),
      ]);

      if (mounted) {
        setState(() {
          if (results[0].isNotEmpty) _academicsList = results[0];
          if (!_academicsList.contains('ไม่มีวิทยฐานะ')) {
            _academicsList.insert(0, 'ไม่มีวิทยฐานะ');
          }
          _departmentsList = results[1];
          _positionsList = results[2];
        });
      }
    } catch (e) {
      debugPrint("Error loading dropdown data: $e");
    }

    final prefs = await SharedPreferences.getInstance();

    final cachedJson = prefs.getString('userFullDataJson');
    if (cachedJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cachedJson);
        setState(() {
          _teacherData = decoded;
          _currentUserName = decoded['fullName'] ?? decoded['name'] ?? '';
          _userRole = prefs.getString('userRole') ??
              decoded['role'] ??
              decoded['permission'] ??
              'ครู';

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

    if (_teacherData == null && mounted) {
      setState(() => _isLoading = true);
    }

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

      await _firebaseService.updateTeacherById(docId, newData);

      final prefs = await SharedPreferences.getInstance();
      final updatedData = {..._teacherData!, ...newData};

      final safeJson = jsonEncode(updatedData, toEncodable: (item) {
        if (item is DateTime) return item.toIso8601String();
        return item.toString();
      });
      await prefs.setString('userFullDataJson', safeJson);

      setState(() {
        _teacherData = updatedData;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('บันทึกข้อมูลสำเร็จแล้วครับ'),
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
    }
  }

  Future<void> _pickAndUploadProfileImage() async {
    if (_teacherData == null) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        imageQuality: 35,
      );

      if (image != null) {
        setState(() => _isUploadingImage = true);

        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        final extension = image.name.split('.').last;
        final dataUrl = "data:image/$extension;base64,$base64String";

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
                Text('กำลังส่งรูปโปรไฟล์ขึ้นระบบ...'),
              ],
            ),
            duration: Duration(minutes: 1),
          ));
        }

        final resData = await _firebaseService.uploadDriveFile(
          fileData: dataUrl,
          fileName:
              '${DateTime.now().millisecondsSinceEpoch}_Profile_$_currentUserName.$extension',
          mimeType: 'image/$extension',
          folderType: 'profile',
          folderId: FirebaseService.driveProfileFolderId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final String imageUrl = resData['url'];
        final String oldImageUrl = _teacherData?['profileImage'] ?? '';

        await _firebaseService
            .updateTeacherData(_currentUserName, {'profileImage': imageUrl});

        if (oldImageUrl.isNotEmpty && oldImageUrl != imageUrl) {
          await _firebaseService.deleteDriveFileStrict(oldImageUrl);
        }

        final prefs = await SharedPreferences.getInstance();
        final updatedData = {..._teacherData!, 'profileImage': imageUrl};

        final safeJson = jsonEncode(updatedData, toEncodable: (item) {
          if (item is DateTime) return item.toIso8601String();
          return item.toString();
        });
        await prefs.setString('userFullDataJson', safeJson);

        await _loadUserAndData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('อัปเดตรูปโปรไฟล์สำเร็จแล้วครับ'),
              backgroundColor: Color(0xFF10B981)));
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('อัปโหลดล้มเหลว'),
          content:
              Text('เกิดข้อผิดพลาด: $e\n(คำแนะนำ: ลองเลือกรูปใหม่อีกครั้งครับ)'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('ตกลง'))
          ],
        ),
      );
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
              child:
                  Text("ยกเลิก", style: GoogleFonts.sarabun(color: Colors.grey))),
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

      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('⚠️  ออกจากระบบ Supabase ไม่สำเร็จ: $e');
      }
      SchoolInfo.reset();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    }
  }

  void _openSubPage(String title, Widget child) {
    Navigator.of(context).push(CupertinoPageRoute(
      builder: (_) => MobileSubPage(title: title, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: mobileBg,
        body: Center(child: CircularProgressIndicator(color: mobileAccent)),
      );
    }

    return Material(
      color: mobileBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── การ์ดโปรไฟล์ด้านบน ──
          _buildProfileCard(),
          const SizedBox(height: 22),

          // ── หมวดที่ 1: ข้อมูลส่วนตัวและรหัสผ่าน ──
          const MobileSectionHeader(
            icon: Icons.badge_outlined,
            title: 'ข้อมูลส่วนตัวและรหัสผ่าน',
          ),
          _buildInfoSection(),
          const SizedBox(height: 22),

          // ── หมวดที่ 2: เครื่องมือผู้ดูแลระบบ (เฉพาะแอดมิน) ──
          if (_userRole.contains('ผู้ดูแลระบบ')) ...[
            const MobileSectionHeader(
              icon: Icons.admin_panel_settings_outlined,
              title: 'เครื่องมือผู้ดูแลระบบ',
              iconColor: Color(0xFFD97706),
            ),
            _buildAdminSection(),
            const SizedBox(height: 22),
          ],

          // ── หมวดที่ 3: การตั้งค่าแอปและบัญชี ──
          const MobileSectionHeader(
            icon: Icons.tune_rounded,
            title: 'การตั้งค่าแอปและบัญชี',
            iconColor: Color(0xFF475569),
          ),
          const InstallAppButton(tile: true),
          const SizedBox(height: 8),
          PushToggleTile(isAdmin: _userRole.contains('ผู้ดูแลระบบ')),
          const SizedBox(height: 12),
          _buildLogoutTile(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final String? profileImg = _teacherData?['profileImage'];
    final String dept =
        (_teacherData?['department'] ?? 'กลุ่มสาระการเรียนรู้').toString();
    final String roleLabel = (_teacherData?['role'] ?? _userRole).toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mobileLine),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: mobileLine, width: 2),
                ),
                child: ClipOval(
                  child: _isUploadingImage
                      ? const Center(child: CircularProgressIndicator())
                      : ProfileAvatar(
                          imageUrl: profileImg,
                          size: 92,
                          name: _currentUserName.isNotEmpty
                              ? _currentUserName
                              : '?',
                          backgroundColor: const Color(0xFFDBEAFE),
                          foregroundColor: mobileAccent,
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadProfileImage,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: mobileAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _currentUserName,
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: mobileInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dept,
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(
              fontSize: 13.5,
              color: mobileMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _badgeChip(Icons.verified_user_outlined,
                  roleLabel.isEmpty ? 'ครู' : roleLabel),
              _badgeChip(Icons.school_outlined, SchoolInfo.namePart1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: mobileLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: mobileAccent),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.sarabun(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: mobileInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mobileLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "รายละเอียดบุคลากร",
                style: GoogleFonts.sarabun(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: mobileInk,
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: _isEditing
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFEFF6FF),
                  foregroundColor:
                      _isEditing ? const Color(0xFF15803D) : mobileAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (_isEditing) {
                    _saveProfile();
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_rounded,
                    size: 16),
                label: Text(
                  _isEditing ? "บันทึกข้อมูล" : "แก้ไขข้อมูล",
                  style: GoogleFonts.sarabun(
                      fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoItem(
            Icons.person_outline_rounded,
            "ชื่อ-นามสกุล",
            _fullNameController,
            isEdit: _isEditing,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  Icons.account_circle_outlined,
                  "ชื่อผู้ใช้ (Username)",
                  _usernameController,
                  isEdit: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildPasswordItem()),
            ],
          ),
          const SizedBox(height: 14),
          _buildDropdownItem(
            Icons.work_outline_rounded,
            "ตำแหน่ง",
            _selectedPosition,
            _positionsList,
            (v) => setState(() => _selectedPosition = v),
          ),
          const SizedBox(height: 14),
          _buildDropdownItem(
            Icons.business_outlined,
            "กลุ่มสาระการเรียนรู้",
            _selectedDepartment,
            _departmentsList,
            (v) => setState(() => _selectedDepartment = v),
          ),
          const SizedBox(height: 14),
          _buildAcademicStandingDropdown(),
          const SizedBox(height: 14),
          _buildInfoItem(
            Icons.phone_iphone_rounded,
            "เบอร์โทรศัพท์",
            _phoneController,
            isEdit: _isEditing,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordItem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(
              'รหัสผ่าน',
              style: GoogleFonts.sarabun(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mobileMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _showChangePasswordDialog,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mobileLine),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'เปลี่ยนรหัส',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sarabun(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: mobileAccent,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: mobileAccent),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
                content: Text('เปลี่ยนรหัสผ่านเรียบร้อยแล้วครับ',
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
                  backgroundColor: mobileAccent,
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

  Future<String?> _changePassword(String current, String next) async {
    final username = (_teacherData?['username'] ?? '').toString().trim();
    if (username.isEmpty) return 'ไม่พบชื่อผู้ใช้ของคุณครูครับ';

    final supabase = Supabase.instance.client;
    final email = FirebaseService.authEmailForUsername(username);

    try {
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

    try {
      final docId = (_teacherData?['docId'] ?? _teacherData?['id'])?.toString();
      if (docId != null && docId.isNotEmpty) {
        await _firebaseService.updateTeacherById(docId, {'password': next});
      }
    } catch (e) {
      debugPrint('⚠️  ซิงก์รหัสผ่านลงตาราง Teachers ไม่สำเร็จ: $e');
    }

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
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mobileMuted)),
          ],
        ),
        const SizedBox(height: 6),
        isEdit
            ? TextField(
                controller: ctrl,
                keyboardType: keyboardType,
                style: GoogleFonts.sarabun(
                    fontSize: 14.5,
                    color: mobileInk,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: mobileLine)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: mobileLine)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(ctrl.text.isEmpty ? "-" : ctrl.text,
                    style: GoogleFonts.sarabun(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: mobileInk)),
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
            const SizedBox(width: 6),
            Text("วิทยฐานะ",
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mobileMuted)),
          ],
        ),
        const SizedBox(height: 6),
        _isEditing
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: mobileLine)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _academicsList.contains(_selectedAcademicStanding)
                        ? _selectedAcademicStanding
                        : _academicsList.first,
                    isExpanded: true,
                    style: GoogleFonts.sarabun(
                        fontSize: 14.5,
                        color: mobileInk,
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
                padding: const EdgeInsets.only(left: 20),
                child: Text(_selectedAcademicStanding ?? "-",
                    style: GoogleFonts.sarabun(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: mobileInk)),
              ),
      ],
    );
  }

  Widget _buildDropdownItem(IconData icon, String label, String? value,
      List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mobileMuted)),
          ],
        ),
        const SizedBox(height: 6),
        _isEditing
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: mobileLine)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: items.contains(value) ? value : null,
                    hint: Text("---เลือก---",
                        style: GoogleFonts.sarabun(
                            fontSize: 14, color: Colors.grey)),
                    isExpanded: true,
                    style: GoogleFonts.sarabun(
                        fontSize: 14.5,
                        color: mobileInk,
                        fontWeight: FontWeight.w600),
                    items: items
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text((value != null && value.isNotEmpty) ? value : "-",
                    style: GoogleFonts.sarabun(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: mobileInk)),
              ),
      ],
    );
  }

  Widget _buildAdminSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mobileLine),
      ),
      child: Column(
        children: [
          _buildAdminTile(
            icon: Icons.lock_reset_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEE2E2),
            title: "อนุมัติรีเซ็ตรหัสผ่าน",
            subtitle: "ตรวจสอบและออกรหัสชั่วคราวให้บุคลากร",
            onTap: () => _openSubPage(
              'อนุมัติรีเซ็ตรหัสผ่าน',
              const MobilePasswordResetScreen(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildAdminTile(
            icon: Icons.manage_accounts_rounded,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFEF3C7),
            title: "จัดการระบบและผู้ใช้งาน",
            subtitle: "เพิ่ม/แก้ไขบุคลากร สิทธิ์เมนู และตั้งค่า",
            onTap: () => _openSubPage(
              'จัดการระบบ',
              const UserManagementScreen(),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildAdminTile(
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFD1FAE5),
            title: "ทำเนียบบุคลากร",
            subtitle: "ดูรายชื่อแยกตามกลุ่มสาระการเรียนรู้",
            onTap: () => _openSubPage(
              'ทำเนียบบุคลากร',
              const PersonnelScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.sarabun(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: mobileInk,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.sarabun(
                      fontSize: 12,
                      color: mobileMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: mobileMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded,
              color: Color(0xFFDC2626), size: 19),
        ),
        title: Text(
          'ออกจากระบบ',
          style: GoogleFonts.sarabun(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFDC2626),
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFF87171)),
        onTap: _logout,
      ),
    );
  }
}
