import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html; // 🔥 เพิ่มการจัดการไฟล์สำหรับเว็บคครับ 🥇🏆
import 'line_settings_screen.dart';
import '../widgets/thai_buddhist_calendar_widget.dart';

class UserManagementScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const UserManagementScreen({super.key, this.onBack});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  // Controllers
  final _nameController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _adminPosController = TextEditingController();
  final _yearController = TextEditingController();
  final _roundController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _photoController =
      TextEditingController(); // 📸 ตัวแปรสำหรับลิ้งค์รูปภาพโปรไฟล์จาก Drive ครับ
  bool _isUploading = false; // 🔄 สถานะกำลังอัปโหลดรูปขึ้น Cloud ครับ 🥇🏆
  final _scriptUrl =
      'https://script.google.com/macros/s/AKfycbx480ohowHypG_MdHVx_BBjNZ54bkZ-cMY4ryntLwbfK-qi8T30JFe3dU6EMVET_0OP/exec';
  final _profileFolderId =
      '1Gor8_V0nRjHU5qLYGke4EE86L1c2dB2k'; // 📂 โฟลเดอร์สำหรับเก็บรูปโปรไฟล์โดยเฉพาะครับ 🥇
  final _syncUrlController = TextEditingController(
      text:
          'https://docs.google.com/spreadsheets/d/1rei51ixTtvXGhxHkrApum6M_lpfGxDGr-QFMqB0_4c4/edit?gid=1827790500#gid=1827790500');
  final _scrollController = ScrollController();
  final _syncHorizontalScrollController =
      ScrollController(); // สำหรับตารางนำเข้าข้อมูลครับ 🥇

  String? _selectedPos = '---เลือก---';
  String? _selectedDept = '---เลือก---';
  String? _selectedRank = '---เลือก---';
  String? _selectedRole = 'ครู';
  bool _isEditing = false;
  String? _editingId;
  String _oldPhotoUrl =
      ''; // 🔥 ตัวแปรเก็บลิ้งค์รูปภาพเดิมเพื่อเปรียบเทียบตอนลบขยะจากโฮสต์ครับ 🥇🏆

  // Sync State
  List<Map<String, dynamic>> _syncPreview = [];
  bool _isFetchingSync = false;
  bool _isPerformingSync = false;
  String? _syncStatusMsg;

  int _currentTab =
      0; // 0: ผู้ใช้งาน, 1: ข้อมูลพื้นฐาน, 2: สิทธิ์การเข้าถึง, 3: นำเข้าข้อมูล, 4: LINE, 5: ปีงบประมาณ, 6: วันหยุด, 7: วันทำงานพิเศษ
  int _permissionViewTab = 0; // 0: หน้า PC, 1: หน้ามือถือ

  // สีหลักตามสไตล์พรีเมียม
  final Color primaryColor = const Color(0xFF0F172A); // Slate 900
  final Color accentColor = const Color(0xFF3B82F6); // Blue 500
  final Color bgColor = const Color(0xFFF1F5F9); // Slate 100
  final Color cardColor = Colors.white;

  List<String> _positions = ['---เลือก---'];
  List<String> _departments = ['---เลือก---'];
  List<String> _ranks = ['---เลือก---'];
  List<String> _roles = ['ครู'];
  List<String> _adminPositions = ['ไม่มีตำแหน่งบริหาร'];
  List<String> _leaveTypes = []; // 🔥 ตัวแปรสำหรับประเภทการลาครับ 🥇🏆
  bool _isLoadingDropdowns = true;
  String _searchText = ''; // 🔥 ตัวแปรสำหรับค้นหาแบบ Real-time ครับ 🥇🏆
  int _masterSubTab = 0; // 🔥 ตัวแปรสำหรับสลับหมวดหมู่ข้อมูลพื้นฐานครับ 🥇🏆

  // 📅 ตัวแปรสำหรับจัดการรอบงบประมาณ (ดีไซน์ใหม่) ครับ 🥇🏆
  final List<String> _thaiMonths = [
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม'
  ];
  String _selectedRound = '1';
  DateTime _roundStartDate = DateTime.now();
  DateTime _roundEndDate = DateTime.now();
  DateTime _holidayDate = DateTime.now();
  DateTime _specialWorkingDate = DateTime.now();
  final _holidayTitleController = TextEditingController();
  final _specialWorkingTitleController = TextEditingController();
  bool _isInstallingHolidays = false;
  bool _isRecalculatingLeaves = false;

  // 🔢 นิยามรหัสเมนูมาตรฐาน (ID Mapping) เพื่อความเสถียรครับ 🥇🏆🏎️
  final Map<int, String> _menuIdMapping = {
    0: 'แดชบอร์ด',
    1: 'รายงานสรุปการลา',
    2: 'ส่งใบลา',
    3: 'ประวัติการลา',
    4: 'จัดการระบบ', // 🔥 ปรับชื่อให้ตรงกับ Sidebar ด้านซ้าย 100% ครับ
    5: 'บุคลากร (กลุ่มสาระ)',
    6: 'จัดการข้อมูลครูเวร',
    7: 'ประวัติการเข้าใช้งาน',
    8: 'ปฏิทินกิจกรรมส่วนกลาง',
  };

  final Map<int, String> _mobileMenuIdMapping = {
    0: 'สรุปผล',
    1: 'รายงาน',
    2: 'ส่งใบลา',
    3: 'ประวัติ',
    4: 'ระบบ',
    5: 'บุคลากร',
    6: 'ครูเวร',
    7: 'เข้าใช้งาน',
    8: 'ปฏิทิน',
    -1: 'บัญชี',
  };

  // 🔥 รายชื่อเมนู/สิทธิ์ที่ต้องการควบคุมครับ 🔐
  final List<Map<String, dynamic>> _appFeatures = [
    {
      'id': 'user_mgmt',
      'name': 'การจัดการผู้ใช้',
      'icon': Icons.people_rounded
    },
    {
      'id': 'base_data',
      'name': 'ข้อมูลพื้นฐานระบบ',
      'icon': Icons.storage_rounded
    },
    {
      'id': 'approve_leave',
      'name': 'พิจารณาการลา',
      'icon': Icons.fact_check_rounded
    },
    {'id': 'reports', 'name': 'ดูรายงานสรุป', 'icon': Icons.assessment_rounded},
    {
      'id': 'calendar',
      'name': 'ปฏิทินส่วนกลาง',
      'icon': Icons.calendar_month_rounded
    },
  ];

  // 🔥 รายชื่อบทบาทหลักจาก Database (ใช้สำหรับ Column ตารางสิทธิ์)
  final List<String> _permissionRoles = ['ผู้ดูแลระบบ', 'ผู้บริหาร', 'ครู'];

  // 🔥 เก็บสถานะสิทธิ์การเข้าถึงแบบ Real-time ครับ (Page ID -> Role -> bool) 🥇🏆
  final Map<String, Map<String, bool>> _rolePermsState = {};

  @override
  void initState() {
    super.initState();
    _syncCurrentUserRole().whenComplete(_loadDropdownData);
    _loadLineSettings();
  }

  Future<void> _loadLineSettings() async {
    // ย้ายไปที่ LineSettingsScreen แล้วครับ
  }

  String _resolveEffectiveRole(Iterable<dynamic> values) {
    final roles = values
        .where((value) => value != null)
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (roles.contains('ผู้ดูแลระบบ')) return 'ผู้ดูแลระบบ';
    if (roles.contains('ผู้บริหาร')) return 'ผู้บริหาร';
    if (roles.contains('ครู')) return 'ครู';
    return roles.isNotEmpty ? roles.first : 'ครู';
  }

  Future<bool> _syncCurrentUserRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      final currentUser = (prefs.getString('currentUser') ?? '').trim();
      final cachedJson = prefs.getString('userFullDataJson') ?? '';
      Map<String, dynamic> cachedUser = <String, dynamic>{};
      if (cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) cachedUser = Map<String, dynamic>.from(decoded);
      }

      final cachedDocId = (cachedUser['id'] ?? '').toString().trim();
      final cachedUsername = (cachedUser['username'] ?? '').toString().trim();
      final cachedRole = _resolveEffectiveRole([
        cachedUser['role'],
        cachedUser['permission'],
        prefs.getString('userRole'),
      ]);

      DocumentSnapshot<Map<String, dynamic>>? teacherDoc;

      if (cachedDocId.isNotEmpty) {
        final snap = await _firebaseService.db
            .collection('Teachers')
            .doc(cachedDocId)
            .get();
        if (snap.exists) teacherDoc = snap;
      }

      if (teacherDoc == null && cachedUsername.isNotEmpty) {
        final query = await _firebaseService.db
            .collection('Teachers')
            .where('username', isEqualTo: cachedUsername)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) teacherDoc = query.docs.first;
      }

      if (teacherDoc == null && currentUser.isNotEmpty) {
        var query = await _firebaseService.db
            .collection('Teachers')
            .where('fullName', isEqualTo: currentUser)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          query = await _firebaseService.db
              .collection('Teachers')
              .where('name', isEqualTo: currentUser)
              .limit(1)
              .get();
        }

        if (query.docs.isNotEmpty) teacherDoc = query.docs.first;
      }

      if (teacherDoc == null) return false;

      final data = teacherDoc.data() ?? <String, dynamic>{};
      final role = _resolveEffectiveRole([
        data['role'],
        data['permission'],
        cachedRole,
      ]);
      final fullName =
          (data['fullName'] ?? data['name'] ?? currentUser).toString();

      await _firebaseService.db
          .collection('Teachers')
          .doc(teacherDoc.id)
          .update({
        'firebase_uid': uid,
        'role': role,
        'permission': role,
        'lastSyncAt': FieldValue.serverTimestamp(),
      });

      await _firebaseService.db.collection('UserRoles').doc(uid).set({
        'role': role,
        'permission': role,
        'fullName': fullName,
        'teacherDocId': teacherDoc.id,
        'lastSyncAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Role sync failed: $e');
    }
    return false;
  }

  Future<void> _loadDropdownData() async {
    try {
      // 🛡️ ดึงข้อมูลทั้งหมดแบบ "ขนาน" (Parallel) เพื่อความรวดเร็วสูงสุดครับ 🏎️🚀
      final results = await Future.wait([
        _firebaseService.getPositions(),
        _firebaseService.getDepartments(),
        _firebaseService.getAcademics(),
        _firebaseService.getPermissions(),
        _firebaseService.getAdminRoles(),
        _firebaseService.getLeaveTypes(),
      ]);

      final pos = results[0];
      final dep = results[1];
      final rnk = results[2];
      final pms = results[3];
      final adm = results[4];
      final lvt = results[5];

      setState(() {
        if (pos.isNotEmpty) _positions = ['---เลือก---', ...pos];
        if (dep.isNotEmpty) _departments = ['---เลือก---', ...dep];
        if (rnk.isNotEmpty) _ranks = ['---เลือก---', ...rnk];
        if (pms.isNotEmpty) _roles = pms;
        if (adm.isNotEmpty) _adminPositions = adm;
        if (lvt.isNotEmpty) _leaveTypes = lvt; // 🥇 เชื่อมต่อข้อมูล

        // 🔥 เริ่มต้นสถานะสิทธิ์สำหรับแต่ละบทบาทครับ
        for (var role in _roles) {
          if (role.contains('เลือก')) continue;
          _rolePermsState[role] = {};
          for (var feature in _appFeatures) {
            String fid = feature['id'];
            // ค่าเริ่มต้น: แอดมินได้หมด ครู/ทำได้แค่บางส่วน
            bool hasInitial = role == 'ผู้ดูแลระบบ' ||
                (role == 'ผู้บริหาร' && fid != 'user_mgmt');
            _rolePermsState[role]![fid] = hasInitial;
          }
        }

        _isLoadingDropdowns = false;
      });
    } catch (e) {
      debugPrint("Error loading dropdowns: $e");
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  Future<void> _saveUser() async {
    if (_nameController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty ||
        _selectedDept == '---เลือก---' ||
        _selectedPos == '---เลือก---') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วนครับ')));
      return;
    }

    final data = {
      'fullName': _nameController.text,
      'username': _userController.text,
      'password': _passController.text,
      'position': _selectedPos,
      'department': _selectedDept,
      'academicStanding': _selectedRank,
      'role': _selectedRole, // 🔥 เปลี่ยนมาใช้ role เป็นหลักครับ 🥇🏆
      'permission': _selectedRole, // ✅ ยังคงฟิลด์เดิมไว้กันบั๊กครับ
      'ตำแหน่งงานบริหาร': _adminPosController.text,
      'profileImage': _photoController.text, // 📸 บันทึกลิ้งค์รูปภาพ
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        throw Exception(
            'บัญชีนี้ยังไม่ได้เชื่อม Firebase Auth กรุณาออกจากระบบแล้วเข้าสู่ระบบใหม่อีกครั้ง');
      }
      final synced = await _syncCurrentUserRole();
      if (!synced) {
        throw Exception(
            'ยังซิงค์สิทธิ์ผู้ดูแลระบบของบัญชีนี้ไม่สำเร็จ กรุณาออกจากระบบแล้วเข้าสู่ระบบใหม่อีกครั้ง');
      }

      if (_isEditing && _editingId != null) {
        String newPhoto = _photoController.text;

        // 🔥 ถ้ามีการเปลี่ยน/ลบรูประหว่างโหมดแก้ไข ให้วิ่งไปลบสคริปต์ใน Google Drive ด้วยครับ 🥇
        if (_oldPhotoUrl.trim().isNotEmpty && _oldPhotoUrl != newPhoto) {
          await _firebaseService.deleteDriveFileStrict(_oldPhotoUrl);
        }

        await _firebaseService.updateUser(_editingId!, data);

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('แก้ไขข้อมูลเรียบร้อยแล้ว')));
      } else {
        await _firebaseService
            .addUser({...data, 'timestamp': DateTime.now().toIso8601String()});
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('บันทึกผู้ใช้ใหม่เรียบร้อยแล้ว')));
      }
      _resetForm();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  void _editUser(Map<String, dynamic> user) {
    setState(() {
      _isEditing = true;
      _editingId = user['id'];
      _nameController.text =
          user['fullName']?.toString() ?? user['name']?.toString() ?? '';
      _userController.text = user['username']?.toString() ?? '';
      _passController.text = user['password']?.toString() ?? '';
      _selectedPos = user['position'] ?? '---เลือก---';
      _selectedDept = user['department'] ?? '---เลือก---';
      _selectedRank = user['academicStanding'] ?? '---เลือก---';
      _selectedRole = user['role'] ??
          user['permission'] ??
          'ครู'; // 🔥 ตรวจสอบทั้งสองฟิลด์ครับ
      _adminPosController.text = user['ตำแหน่งงานบริหาร'] ?? '';
      _photoController.text = user['profileImage'] ?? ''; // 📸 ดึงข้อมูลรูปภาพ
      _oldPhotoUrl = _photoController
          .text; // 🥇 เก็บรูปภาพเดิมไว้เผื่อกรณีทีมีการลบ/เปลี่ยนรูป
    });
  }

  void _resetForm() {
    setState(() {
      _isEditing = false;
      _editingId = null;
      _nameController.clear();
      _userController.clear();
      _passController.clear();
      _adminPosController.clear();
      _selectedPos = '---เลือก---';
      _selectedDept = '---เลือก---';
      _selectedRank = '---เลือก---';
      _selectedRole = 'ครู';
      _adminPosController.text = 'ไม่มีตำแหน่งบริหาร';
      _photoController.clear(); // 📸 ล้างข้อมูลรูปภาพ
    });
  }

  // 🔥 ฟังก์ชันลบผู้ใช้งานพร้อมระบบยืนยันครับ 🥇🏆
  Future<void> _deleteUser(Map<String, dynamic> user) async {
    String? id = user['id'];
    String name = user['fullName'] ?? '';

    if (id == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการลบ',
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: Text(
            'คุณต้องการลบรายชื่อ $name ใช่หรือไม่?\nการดำเนินการนี้ไม่สามารถย้อนกลับได้ครับ',
            style: GoogleFonts.sarabun()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  const Text('ยกเลิก', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('ยืนยันลบข้อมูล')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 🔥 หลังจากลบใน Firebase แล้ว ก็สั่งลบขยะข้ามไปใน Google Drive ทิ้งด้วย 🥇
        final driveUrls = <String>{
          user['profileImage']?.toString() ?? '',
          user['photoUrl']?.toString() ?? '',
          user['profilePhoto']?.toString() ?? '',
          user['medicalCertificate']?.toString() ?? '',
        }..removeWhere((url) => url.trim().isEmpty);

        for (final url in driveUrls) {
          await _firebaseService.deleteDriveFileStrict(url);
        }

        await _firebaseService.deleteUser(id);

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ลบข้อมูลเรียบร้อยแล้วครับ')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
      }
    }
  }

  // 🔥 ฟังก์ชันเลือกรูปโปรไฟล์และส่งขึ้น Google Drive ผ่าน Script โดยตรงครับ (Real Cloud Storage) 🏎️🚀🏆
  void _pickProfileImage() {
    final html.FileUploadInputElement uploadInput =
        html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files!.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        reader.readAsDataUrl(file);

        reader.onLoadEnd.listen((e) async {
          final result = reader.result as String;

          // 🛠️ ย่อขนาดรูปก่อนส่งขึ้น Cloud ครับ 🥇
          final img = html.ImageElement(src: result);
          img.onLoad.listen((_) async {
            final canvas = html.CanvasElement();
            const int maxSize = 350; // เพิ่มความชัดขึ้นนิดหน่อยครับ
            int width = img.width!;
            int height = img.height!;
            if (width > height) {
              if (width > maxSize) {
                height = (height * maxSize / width).round();
                width = maxSize;
              }
            } else {
              if (height > maxSize) {
                width = (width * maxSize / height).round();
                height = maxSize;
              }
            }
            canvas.width = width;
            canvas.height = height;
            canvas.context2D.drawImageScaled(img, 0, 0, width, height);

            final compressedData = canvas.toDataUrl('image/jpeg', 0.85);

            // 🔄 เริ่มกระบวนการส่งขึ้น Google Drive ครับ 🏎️💨
            setState(() => _isUploading = true);

            try {
              final resBody = await _firebaseService.uploadDriveFile(
                fileData: compressedData,
                fileName:
                    "Profile_${DateTime.now().millisecondsSinceEpoch}.jpg",
                mimeType: "image/jpeg",
                folderType: 'profile',
                folderId: _profileFolderId,
              );

              setState(() {
                _photoController.text = resBody[
                    'url']; // 🥇 บันทึกลิ้งค์ Drive จริงๆ ลงฐานข้อมูลครับ
              });
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'อัปโหลดรูปภาพขึ้น Google Drive สำเร็จครับ! ☁️🥇')));
            } catch (err) {
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('เกิดข้อผิดพลาดในการอัปโหลด: $err')));
            } finally {
              if (mounted) setState(() => _isUploading = false);
            }
          });
        });
      }
    });
  }

  // 🚀 เมนูเลือกวิธีจัดการรูปโปรไฟล์ครับ 🥇🏆
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text('จัดการรูปโปรไฟล์',
                style: GoogleFonts.sarabun(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.add_a_photo_outlined,
                      color: Colors.blue)),
              title: Text('เลือกรูปภาพจากเครื่อง (ย่อขนาดอัตโนมัติ)',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
              subtitle: Text('อัปโหลดไฟล์จากในคอมพิวเตอร์หรือมือถือครับ',
                  style: GoogleFonts.sarabun(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfileImage();
              },
            ),
            const Divider(height: 24),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.link_rounded, color: Colors.orange)),
              title: Text('ใช้ลิ้งค์จาก Google Drive',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  'นำลิ้งก์แชร์จาก Drive มาวางเพื่อใช้งานแบบ Cloud ครับ',
                  style: GoogleFonts.sarabun(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx); /* เลื่อนไปโฟกัสช่องกรอกข้อมูล */
              },
            ),
            const Divider(height: 24),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red)),
              title: Text('ลบรูปภาพโปรไฟล์',
                  style: GoogleFonts.sarabun(
                      fontWeight: FontWeight.bold, color: Colors.red)),
              subtitle: Text(
                  'นำรูปภาพออกจากผู้พัฒนานี้เพื่อกลับไปใช้ค่าเริ่มต้นครับ',
                  style: GoogleFonts.sarabun(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _photoController.clear(); // 🗑️ ล้างลิ้งค์รูปภาพ
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('นำรูปภาพออกเรียบร้อยแล้วครับ 🗑️')));
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isWide = MediaQuery.of(context).size.width > 1200;
    bool isMedium = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firebaseService.getUsersStream(),
        builder: (context, snapshot) {
          final allUsers = snapshot.data ?? [];

          // 🔥 ระบบกรองข้อมูลแบบ Real-time ครับ
          final users = allUsers.where((u) {
            final name = (u['fullName'] ?? '').toString().toLowerCase();
            final search = _searchText.toLowerCase();
            return name.contains(search);
          }).toList();

          // 🔥 ปรับปรุงการจัดเรียงข้อมูลตามลำดับความสำคัญ (เวอร์ชันเสถียรที่สุด) 🥇🏆
          users.sort((a, b) {
            int getPriority(Map<String, dynamic> u) {
              // 0. 🔔 ผู้ที่ขอรีเซ็ตรหัสผ่าน (ความสำคัญสูงสุดเฉียบพลัน!) ต้องอยู่บนสุดครับ 🥇🏆
              if (u['forgotPasswordStatus'] == 'waiting') return -1;

              String pos = (u['position'] ?? '').toString();
              String adminPos = (u['ตำแหน่งงานบริหาร'] ?? '').toString();
              String rank = (u['academicStanding'] ?? '').toString();
              String role = (u['permission'] ?? '').toString();

              // 1. ผู้อำนวยการ (เช็คทั้งสองฟิลด์)
              if ((pos.contains('ผู้อำนวยการ') ||
                      adminPos.contains('ผู้อำนวยการ')) &&
                  !(pos.contains('รอง') || adminPos.contains('รอง'))) return 0;

              // 2. รองผู้อำนวยการ
              if (pos.contains('รองผู้อำนวยการ') ||
                  adminPos.contains('รองผู้อำนวยการ')) return 1;

              // 3. หัวหน้ากลุ่มงาน / ตำแหน่งบริหารงาน
              if (adminPos.isNotEmpty) return 2;

              // 4. สิทธิ์ผู้ดูแลระบบ
              if (role == 'ผู้ดูแลระบบ') return 3;

              // 5. วิทยฐานะ
              if (rank.contains('เชี่ยวชาญพิเศษ')) return 10;
              if (rank.contains('เชี่ยวชาญ')) return 20;
              if (rank.contains('ชำนาญการพิเศษ')) return 30;
              if (rank.contains('ชำนาญการ')) return 40;

              return 100; // ทั่วไป / ไม่มีวิทยฐานะ
            }

            return getPriority(a).compareTo(getPriority(b));
          });

          if (_isLoadingDropdowns) {
            return const Center(child: CircularProgressIndicator());
          }
          return Container(
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.symmetric(
              horizontal: isMedium ? 32 : 16,
              vertical: 40,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMedium),
                  const SizedBox(height: 32),

                  // สลับการแสดงผลตาม Tab ครับ 🕵️‍♂️🏎️🏆
                  if (_currentTab == 0) _buildUsersTab(users, isWide),
                  if (_currentTab == 1) _buildMasterTab(),
                  if (_currentTab == 2) _buildPermsTab(),
                  if (_currentTab == 3) _buildSyncTab(isWide),
                  if (_currentTab == 4) const LineSettingsScreen(),
                  if (_currentTab == 5) _buildBudgetTab(),
                  if (_currentTab == 6) _buildHolidayTab(),
                  if (_currentTab == 7) _buildSpecialWorkingDayTab(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 1: ระบบจัดการผู้ใช้งานแบบเดิม
  // ==========================================
  Widget _buildUsersTab(List<Map<String, dynamic>> users, bool isWide) {
    if (!isWide) {
      return Column(
        children: [
          _buildAddForm(true),
          const SizedBox(height: 24),
          SizedBox(height: 600, child: _buildUserList(true, users)),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: _buildAddForm(false),
        ),
        const SizedBox(width: 24),
        Expanded(
            flex: 8,
            child: SizedBox(height: 800, child: _buildUserList(false, users)))
      ],
    );
  }

  // ==========================================
  // TAB 2: ระบบจัดการข้อมูลพื้นฐาน (Master Data)
  // ==========================================
  Widget _buildMasterTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.settings_suggest, color: primaryColor, size: 28),
            const SizedBox(width: 12),
            Text("ตั้งค่าข้อมูลระบบพื้นฐาน",
                style: GoogleFonts.sarabun(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
          ],
        ),
        const SizedBox(height: 8),
        Text("บริหารจัดการตัวเลือกต่างๆ ในระบบให้ทันสมัยอยู่เสมอ",
            style: GoogleFonts.sarabun(color: Colors.blueGrey, fontSize: 14)),
        const SizedBox(height: 32),

        // แถบสลับหมวดหมู่ย่อย (Sub-Tabs) ครับ 🕵️‍♂️🏎️🏆
        Container(
          height: 50,
          margin: const EdgeInsets.only(bottom: 32),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildSubTabButton(0, "ตำแหน่ง", Icons.work_rounded, Colors.blue),
              _buildSubTabButton(
                  1, "วิทยฐานะ", Icons.stars_rounded, Colors.amber),
              _buildSubTabButton(
                  2, "กลุ่มสาระฯ", Icons.domain_rounded, Colors.teal),
              _buildSubTabButton(
                  3, "สิทธิ์การเข้าถึง", Icons.shield_rounded, Colors.purple),
              _buildSubTabButton(
                  4, "ตำแหน่งบริหาร", Icons.edit_document, Colors.orange),
              _buildSubTabButton(
                  5, "ประเภทการลา", Icons.description_rounded, Colors.pink),
            ],
          ),
        ),

        // แสดงผลเฉพาะหมวดหมู่ที่เลือกครับ 🥇
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildSelectedMasterView(),
        ),
      ],
    );
  }

  Widget _buildSubTabButton(
      int index, String label, IconData icon, Color color) {
    bool isActive = _masterSubTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => setState(() => _masterSubTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? color : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isActive ? color : Colors.blueGrey),
              const SizedBox(width: 10),
              Text(label,
                  style: GoogleFonts.sarabun(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? color : Colors.blueGrey,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedMasterView() {
    switch (_masterSubTab) {
      case 0:
        return _buildMasterCard(
            "จัดการตำแหน่ง", Icons.work_rounded, Colors.blue, _positions);
      case 1:
        return _buildMasterCard(
            "จัดการวิทยฐานะ", Icons.stars_rounded, Colors.amber, _ranks);
      case 2:
        return _buildMasterCard("จัดการกลุ่มสาระฯ", Icons.domain_rounded,
            Colors.teal, _departments);
      case 3:
        return _buildMasterCard("จัดการสิทธิ์การเข้าถึง", Icons.shield_rounded,
            Colors.purple, _roles);
      case 4:
        return _buildMasterCard("จัดการตำแหน่งบริหาร", Icons.edit_document,
            Colors.orange, _adminPositions);
      case 5:
        return _buildMasterCard("จัดการประเภทการลา", Icons.description_rounded,
            Colors.pink, _leaveTypes);
      default:
        return const SizedBox();
    }
  }

  String _masterCollectionForCurrentTab() {
    switch (_masterSubTab) {
      case 0:
        return 'Positions';
      case 1:
        return 'Academics';
      case 2:
        return 'Departments';
      case 3:
        return 'Roles';
      case 4:
        return 'AdminRoles';
      case 5:
        return 'LeaveTypes';
      default:
        return '';
    }
  }

  String _masterDropdownFieldForCurrentTab() {
    switch (_masterSubTab) {
      case 0:
        return 'positions';
      case 1:
        return 'ranks';
      case 2:
        return 'departments';
      case 3:
        return 'roles';
      case 4:
        return 'adminPositions';
      case 5:
        return 'leaveTypes';
      default:
        return '';
    }
  }

  List<String> _masterItemsForCurrentTab() {
    switch (_masterSubTab) {
      case 0:
        return _positions;
      case 1:
        return _ranks;
      case 2:
        return _departments;
      case 3:
        return _roles;
      case 4:
        return _adminPositions;
      case 5:
        return _leaveTypes;
      default:
        return const [];
    }
  }

  String _masterValueField(Map<String, dynamic> data, {String? matchValue}) {
    if (matchValue != null && matchValue.trim().isNotEmpty) {
      for (final entry in data.entries) {
        if (entry.value is String &&
            !entry.key.toUpperCase().contains('ID') &&
            entry.value.toString().trim() == matchValue.trim()) {
          return entry.key;
        }
      }
    }

    const candidates = ['Value', 'value', 'Name', 'name', 'Type Name'];
    for (final key in candidates) {
      if (data.containsKey(key)) return key;
    }
    return 'Value';
  }

  bool _masterDocMatchesValue(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String value,
  ) {
    if (doc.id == value) return true;
    final data = doc.data();
    for (final entry in data.entries) {
      if (entry.value is String && entry.value.toString().trim() == value) {
        return true;
      }
    }
    return false;
  }

  Future<void> _renameMasterItem(String oldValue, String newValue) async {
    final collection = _masterCollectionForCurrentTab();
    final dropdownField = _masterDropdownFieldForCurrentTab();
    if (collection.isEmpty || dropdownField.isEmpty) return;

    // 1. อัปเดตในคอลเลกชันมาสเตอร์ (เช่น Departments)
    final snapshot = await _firebaseService.db.collection(collection).get();
    final matches =
        snapshot.docs.where((doc) => _masterDocMatchesValue(doc, oldValue));

    if (matches.isNotEmpty) {
      for (var doc in matches) {
        final fieldName = _masterValueField(doc.data(), matchValue: oldValue);
        await _firebaseService.db.collection(collection).doc(doc.id).update({
          fieldName: newValue,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // 2. อัปเดตใน Settings/dropdowns (array)
    await _firebaseService.db.collection('Settings').doc('dropdowns').set({
      dropdownField: FieldValue.arrayRemove([oldValue]),
    }, SetOptions(merge: true));

    await _firebaseService.db.collection('Settings').doc('dropdowns').set({
      dropdownField: FieldValue.arrayUnion([newValue]),
    }, SetOptions(merge: true));

    await _loadDropdownData();
  }

  // 🔥 เพิ่มฟังก์ชันสำหรับลบข้อมูลพื้นฐานแบบถอนรากถอนโคนครับ 🥇🏆
  Future<void> _deleteMasterItem(String value) async {
    final collection = _masterCollectionForCurrentTab();
    final dropdownField = _masterDropdownFieldForCurrentTab();
    if (collection.isEmpty || dropdownField.isEmpty) return;

    // 1. ลบจากคอลเลกชันมาสเตอร์
    final snapshot = await _firebaseService.db.collection(collection).get();
    final matches =
        snapshot.docs.where((doc) => _masterDocMatchesValue(doc, value));

    for (var doc in matches) {
      await _firebaseService.db.collection(collection).doc(doc.id).delete();
    }

    // 2. ลบจาก Settings/dropdowns
    await _firebaseService.db.collection('Settings').doc('dropdowns').set({
      dropdownField: FieldValue.arrayRemove([value])
    }, SetOptions(merge: true));

    await _loadDropdownData();
  }

  Future<void> _showEditMasterItemDialog(
      String currentValue, Color color) async {
    final controller = TextEditingController(text: currentValue);
    final newValue = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('แก้ไขรายการ',
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ชื่อรายการ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newValue == null || newValue.isEmpty || newValue == currentValue)
      return;
    if (_masterItemsForCurrentTab().contains(newValue)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('มีรายการนี้อยู่แล้ว'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    try {
      await _renameMasterItem(currentValue, newValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('แก้ไขรายการเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('แก้ไขไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _buildMasterCard(
      String title, IconData icon, Color color, List<String> currentItems) {
    final TextEditingController masterCtrl = TextEditingController();
    final visibleItems = currentItems
        .where((item) => !item.contains('เลือก') && item.trim().isNotEmpty)
        .toList();

    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(height: 4, width: double.infinity, color: color),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.sarabun(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("รายการทั้งหมด ${visibleItems.length} รายการ",
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                IconButton(
                    onPressed: _loadDropdownData,
                    icon: const Icon(Icons.refresh_rounded,
                        size: 18, color: Colors.blueGrey))
              ],
            ),
          ),
          const Divider(height: 1),
          Container(
            height: 400,
            padding: const EdgeInsets.all(20),
            child: visibleItems.isEmpty
                ? Center(
                    child: Text(
                      'ยังไม่มีข้อมูลในหมวดนี้',
                      style: GoogleFonts.sarabun(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 56,
                          horizontalMargin: 16,
                          columnSpacing: 28,
                          dividerThickness: 0.8,
                          headingTextStyle: GoogleFonts.sarabun(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey.shade600,
                          ),
                          dataTextStyle: GoogleFonts.sarabun(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                          columns: const [
                            DataColumn(label: Text('ลำดับ')),
                            DataColumn(label: Text('รายการ')),
                            DataColumn(label: Text('สถานะ')),
                            DataColumn(label: Text('จัดการ')),
                          ],
                          rows: List.generate(visibleItems.length, (index) {
                            final item = visibleItems[index];
                            return DataRow(
                              color: WidgetStateProperty.resolveWith((states) {
                                return index.isEven
                                    ? Colors.white
                                    : const Color(0xFFFAFBFC);
                              }),
                              cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          item,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color:
                                              Colors.green.withOpacity(0.16)),
                                    ),
                                    child: Text(
                                      'ใช้งาน',
                                      style: GoogleFonts.sarabun(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'แก้ไข',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _showEditMasterItemDialog(
                                                item, color),
                                        icon: Icon(Icons.edit_outlined,
                                            size: 17, color: color),
                                      ),
                                      IconButton(
                                        tooltip: 'ลบ',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          bool confirm = await showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                        title: const Text(
                                                            'ยืนยันการลบ'),
                                                        content: Text(
                                                            'คุณครูแน่ใจนะครับว่าจะลบ "$item"?'),
                                                        actions: [
                                                          TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      ctx,
                                                                      false),
                                                              child: const Text(
                                                                  'ยกเลิก')),
                                                          TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      ctx,
                                                                      true),
                                                              child: const Text(
                                                                  'ลบเลย',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .red))),
                                                        ],
                                                      )) ??
                                              false;

                                          if (confirm) {
                                            try {
                                              await _deleteMasterItem(item);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                        const SnackBar(
                                                  content: Text(
                                                      'ลบรายการเรียบร้อยแล้ว'),
                                                  backgroundColor: Colors.green,
                                                ));
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                  content:
                                                      Text('ลบไม่สำเร็จ: $e'),
                                                  backgroundColor: Colors.red,
                                                ));
                                              }
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline,
                                            size: 17, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: masterCtrl,
                      style: GoogleFonts.sarabun(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "เพิ่ม $title ใหม่...",
                        hintStyle: GoogleFonts.sarabun(
                            fontSize: 13, color: Colors.black26),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 0),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: Colors.grey.shade100)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: Colors.grey.shade100)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final String val = masterCtrl.text.trim();
                    if (val.isEmpty) return;

                    String collection = '';
                    String fieldName = 'Value';

                    if (title.contains('ตำแหน่ง')) collection = 'Positions';
                    if (title.contains('กลุ่มสาระ')) collection = 'Departments';
                    if (title.contains('วิทยฐานะ')) collection = 'Academics';
                    if (title.contains('บริหาร')) collection = 'AdminRoles';
                    if (title.contains('สิทธิ์')) collection = 'Roles';
                    if (title.contains('ประเภทการลา'))
                      collection = 'LeaveTypes';

                    if (collection.isEmpty) return;

                    try {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('กำลังบันทึกข้อมูลลงฐานข้อมูล...'),
                        duration: Duration(seconds: 1),
                      ));

                      await _firebaseService.db.collection(collection).add({
                        fieldName: val,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      masterCtrl.clear();
                      if (mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('บันทึกข้อมูลใหม่สำเร็จแล้วครับ!'),
                          backgroundColor: Colors.green,
                        ));
                        _loadDropdownData();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('ล้มเหลว: $e'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 22),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: สิทธิ์การเข้าถึง (Permissions)
  // ==========================================
  String get _permissionCollectionName =>
      _permissionViewTab == 0 ? 'Permissions' : 'MobilePermissions';

  String get _permissionViewTitle =>
      _permissionViewTab == 0 ? 'หน้า PC' : 'หน้ามือถือ';

  Map<int, String> get _permissionMenuMapping =>
      _permissionViewTab == 0 ? _menuIdMapping : _mobileMenuIdMapping;

  bool _readPermissionValue(
      Map<String, dynamic> data, String pageId, String pageName) {
    final numericValue = data[pageId];
    final nameValue = data[pageName];
    return numericValue == true ||
        numericValue.toString().toUpperCase() == 'TRUE' ||
        nameValue == true ||
        nameValue.toString().toUpperCase() == 'TRUE';
  }

  Widget _buildPermissionScopeButton(int index, IconData icon, String title) {
    final isActive = _permissionViewTab == index;
    return InkWell(
      onTap: () => setState(() => _permissionViewTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive ? Colors.blue.shade100 : Colors.transparent),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18,
                color: isActive ? accentColor : Colors.blueGrey.shade400),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.sarabun(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? primaryColor : Colors.blueGrey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermsTab() {
    final menuEntries = _permissionMenuMapping.entries.toList();

    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: StreamBuilder<QuerySnapshot>(
        stream: _firebaseService.db
            .collection(_permissionCollectionName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(60),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.blueGrey)));
          }

          final Map<String, Map<String, dynamic>> rolePerms = {};
          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              rolePerms[doc.id] = doc.data() as Map<String, dynamic>;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("การกำหนดสิทธิ์",
                            style: GoogleFonts.sarabun(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: primaryColor)),
                        const SizedBox(height: 4),
                        Text("ตั้งค่าการมองเห็นเมนู$_permissionViewTitle",
                            style: const TextStyle(
                                color: Colors.blueGrey, fontSize: 13)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPermissionScopeButton(
                                  0, Icons.desktop_windows_rounded, 'หน้า PC'),
                              _buildPermissionScopeButton(
                                  1, Icons.phone_android_rounded, 'หน้ามือถือ'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        for (var role in _permissionRoles) {
                          final currentData = rolePerms[role] ?? {};
                          Map<String, dynamic> newData = {
                            'updatedAt': FieldValue.serverTimestamp()
                          };

                          for (final entry in menuEntries) {
                            final pageId = entry.key.toString();
                            final pageName = entry.value;
                            final val = _readPermissionValue(
                                currentData, pageId, pageName);
                            newData[pageId] = val;
                          }

                          await _firebaseService.db
                              .collection(_permissionCollectionName)
                              .doc(role)
                              .set(newData);
                        }
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'บันทึกและล้างข้อมูลเก่าเรียบร้อยครับ! 🏗️🥇')));
                      },
                      icon:
                          const Icon(Icons.cleaning_services_rounded, size: 18),
                      label: const Text("บันทึกและล้างข้อมูลเก่า"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // 💎 หัวตาราง
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                        bottom:
                            BorderSide(color: Color(0xFFE2E8F0), width: 1.5))),
                child: Row(
                  children: [
                    Expanded(
                        flex: 2,
                        child: Text(
                            _permissionViewTab == 0
                                ? 'รายการหน้าเมนูระบบ'
                                : 'รายการหน้าเมนูมือถือ',
                            style: GoogleFonts.sarabun(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Colors.blueGrey.shade700))),
                    ..._permissionRoles
                        .map((role) => Expanded(
                              child: Center(
                                child: Text(role,
                                    style: GoogleFonts.sarabun(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.blueGrey.shade500)),
                              ),
                            ))
                        .toList(),
                  ],
                ),
              ),

              // 💎 รายการสิทธิ์
              Column(
                children: menuEntries.map((entry) {
                  final idx = entry.key;
                  final pageName = entry.value;
                  final pageId = idx.toString();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                            bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 16, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(pageName,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sarabun(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF334155))),
                              ),
                            ],
                          ),
                        ),
                        ..._permissionRoles.map((role) {
                          final currentData = rolePerms[role] ?? {};
                          bool hasAccess = _readPermissionValue(
                              currentData, pageId, pageName);
                          bool isLockAdmin =
                              role == 'ผู้ดูแลระบบ' && (idx == 4);

                          return Expanded(
                            child: Center(
                              child: Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value: hasAccess,
                                  activeColor: accentColor,
                                  onChanged: isLockAdmin
                                      ? null
                                      : (val) async {
                                          await _firebaseService.db
                                              .collection(
                                                  _permissionCollectionName)
                                              .doc(role)
                                              .set({
                                            pageId: val,
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));
                                        },
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isMedium) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 20,
      runSpacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.black, size: 22),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B82F6), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: const Icon(Icons.people_alt,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "จัดการข้อมูลผู้ใช้",
                      style: GoogleFonts.sarabun(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: primaryColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "บริหารจัดการรายชื่อครู เจ้าหน้าที่ และกำหนดสิทธิ์การเข้าถึง",
                      style: GoogleFonts.sarabun(
                          fontSize: 14,
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Segmented Tabs (Glassmorphism style)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabButton(0, Icons.manage_accounts, "จัดการผู้ใช้งาน"),
                _buildTabButton(1, Icons.storage, "ข้อมูลพื้นฐานระบบ"),
                _buildTabButton(2, Icons.verified_user, "กำหนดสิทธิ์เข้าถึง"),
                _buildTabButton(3, Icons.cloud_download, "นำเข้าข้อมูล"),
                _buildTabButton(
                    4, Icons.notifications_active_rounded, "ตั้งค่า LINE"),
                _buildTabButton(
                    5, Icons.account_balance_wallet_rounded, "ปีงบประมาณ"),
                _buildTabButton(
                    6, Icons.event_available_rounded, "ตั้งค่าวันหยุด"),
                _buildTabButton(
                    7, Icons.calendar_today_rounded, "ตั้งค่าวันทำงานพิเศษ"),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, IconData icon, String title) {
    bool isActive = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive ? Colors.grey.shade200 : Colors.transparent),
          boxShadow: isActive
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.02), blurRadius: 4)
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: isActive ? accentColor : Colors.blueGrey.shade400),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.sarabun(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? primaryColor : Colors.blueGrey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddForm(bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 400,
      padding: const EdgeInsets.all(24), // ปรับระยะ Padding ให้กระชับขึ้นครับ
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 12),
              Text(_isEditing ? 'แก้ไขผู้ใช้งาน' : 'เพิ่มผู้ใช้งาน',
                  style: GoogleFonts.sarabun(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: InkWell(
              onTap:
                  _showPhotoOptions, // 📸 เปลี่ยนเมนูให้เลือกได้ว่าจะอัปโหลดหรือใช้ลิ้งค์ Drive ครับ
              borderRadius: BorderRadius.circular(50),
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10)
                        ]),
                    clipBehavior: Clip.antiAlias,
                    child: ValueListenableBuilder(
                        valueListenable: _photoController,
                        builder: (context, val, child) {
                          if (_isUploading) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.blue)));
                          }
                          String url = val.text;
                          if (url.isNotEmpty && url.startsWith('data:image')) {
                            return Image.network(url, fit: BoxFit.cover);
                          } else if (url.isNotEmpty && url.startsWith('http')) {
                            String imgUrl = url;
                            // 🔥 ใช้เทคนิค Thumbnail API ของ Google Drive เพื่อหลบ CORS และบีบอัดรูปให้โหลดเร็วขึ้น 🥇
                            if (url.contains('drive.google.com')) {
                              final regExp =
                                  RegExp(r'(?:id=|\/d\/)([a-zA-Z0-9-_]+)');
                              final match = regExp.firstMatch(url);
                              if (match != null) {
                                imgUrl =
                                    'https://wsrv.nl/?url=drive.google.com/uc%3Fid%3D${match.group(1)}';
                              }
                            }
                            return Image.network(imgUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => const Icon(
                                    Icons.people,
                                    size: 50,
                                    color: Colors.blueGrey));
                          }
                          return const Icon(Icons.people_alt_outlined,
                              color: Colors.blueGrey, size: 32);
                        }),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.edit_outlined,
                          color: Colors.white, size: 14),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldLabel(
              'ลิ้งค์รูปภาพโปรไฟล์ (ใช้ลิ้งค์ Google Drive เพื่อเก็บข้อมูลบน Cloud)'),
          _buildTextField(
              _photoController, 'วางลิ้งค์รูปภาพจาก Google Drive ที่นี่...'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
                '💡 แนะนำ: ใช้ลิ้งค์ Google Drive เพื่อการเชื่อมต่อกับ Google Sheets ที่สมบูรณ์แบบครับ',
                style: GoogleFonts.sarabun(
                    fontSize: 10, color: Colors.orange.shade800)),
          ),
          const SizedBox(height: 24),
          _buildFieldLabel('ชื่อ-นามสกุล'),
          _buildTextField(_nameController, 'เช่น ครูสมศรี เรียนดี'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _buildFieldLabel('ชื่อผู้ใช้'),
                    _buildTextField(_userController, 'user123')
                  ])),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _buildFieldLabel('รหัสผ่าน'),
                    _buildTextField(_passController, '********', obscure: true)
                  ])),
            ],
          ),
          const SizedBox(height: 20),
          _buildFieldLabel('ตำแหน่ง'),
          _buildDropdownField(
              items: _positions,
              val: _selectedPos,
              onC: (v) => setState(() => _selectedPos = v!),
              icon: Icons.business_center_outlined,
              hint: 'เลือกตำแหน่ง'),
          const SizedBox(height: 20),
          _buildFieldLabel('กลุ่มสาระการเรียนรู้'),
          _buildDropdownField(
              items: _departments,
              val: _selectedDept,
              onC: (v) => setState(() => _selectedDept = v!),
              icon: Icons.grid_view_outlined,
              hint: 'เลือกกลุ่มสาระการเรียนรู้'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('วิทยฐานะ'),
                    _buildDropdownField(
                        items: _ranks,
                        val: _selectedRank,
                        onC: (v) => setState(() => _selectedRank = v!),
                        hint: 'เลือกวิทยฐานะ'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('สิทธิ์ (ROLE)'),
                    _buildDropdownField(
                        items: _roles,
                        val: _selectedRole,
                        onC: (v) => setState(() => _selectedRole = v!),
                        hint: 'เลือกสิทธิ์'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text('ตำแหน่งงานบริหาร',
                  style: GoogleFonts.sarabun(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800)),
            ],
          ),
          const SizedBox(height: 8),
          _buildDropdownField(
              items: _adminPositions,
              val: _adminPosController.text,
              onC: (v) => setState(() => _adminPosController.text = v!),
              icon: Icons.stars_outlined,
              color: Colors.orange.shade50,
              iconColor: Colors.orange,
              hint: 'ไม่มีตำแหน่งบริหาร'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text('ระบบจะใช้ค่านี้เพื่อแสดงชื่อผู้ลงนามท้ายแบบฟอร์มใบลา',
                style:
                    GoogleFonts.sarabun(fontSize: 10, color: Colors.black26)),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _saveUser,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_isEditing ? 'แก้ไขข้อมูล' : 'บันทึกข้อมูลผู้ใช้',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUserList(bool isMobile, List<Map<String, dynamic>> users) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ]),
      child: Column(
        children: [
          _buildUserListHeader(users),
          const SizedBox(height: 16),
          // 🚨 แถบแจ้งเตือนด่วนสำหรับแอดมิน (Emergency Notification Bar) 🔔🥇🏆
          if (users.any((u) => u['forgotPasswordStatus'] == 'waiting'))
            _buildEmergencyAlertBar(users
                .where((u) => u['forgotPasswordStatus'] == 'waiting')
                .length),

          // 🔥 เพิ่มหัวตารางเพื่อให้ข้อมูลตรงกันครับ 🥇🏆
          if (!isMobile) _buildTableLabelHeader(),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          // 🔥 ส่วนรายการเลื่อนได้พร้อม Scrollbar ครับ
          Expanded(
            child: Scrollbar(
              controller: _scrollController, // เชื่อม Controller
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 6,
              radius: const Radius.circular(10),
              child: ListView.builder(
                controller: _scrollController, // เชื่อม Controller เดียวกัน
                padding: const EdgeInsets.only(right: 12),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _buildUserRow(user, isMobile);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListHeader(List<Map<String, dynamic>> users) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.people_alt_outlined,
                    size: 20, color: Colors.blueGrey)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รายชื่อผู้ใช้งาน',
                    style: GoogleFonts.sarabun(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text('บุคลากรทั้งหมด ${users.length} คน',
                    style: GoogleFonts.sarabun(
                        fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 180,
              height: 40,
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: TextField(
                onChanged: (val) => setState(() =>
                    _searchText = val), // 🔥 อัปเดตการค้นหาทันทีที่พิมพ์ครับ
                decoration: const InputDecoration(
                    hintText: 'ค้นหา...',
                    prefixIcon: Icon(Icons.search, size: 16),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10)),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 18),
                style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE2E8F0))))),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatar(Map<String, dynamic> user) {
    return Builder(builder: (context) {
      String? photoUrl = user['profileImage']?.toString();
      if (photoUrl != null && photoUrl.startsWith('http')) {
        String imgUrl = photoUrl;
        if (photoUrl.contains('drive.google.com')) {
          final regExp = RegExp(r'(?:id=|\/d\/)([a-zA-Z0-9-_]+)');
          final match = regExp.firstMatch(photoUrl);
          if (match != null) {
            imgUrl =
                'https://wsrv.nl/?url=drive.google.com/uc%3Fid%3D${match.group(1)}';
          }
        }
        return CircleAvatar(
          radius: 18,
          backgroundImage: NetworkImage(imgUrl),
          backgroundColor: const Color(0xFFF1F5F9),
          onBackgroundImageError: (exception, stackTrace) {},
          child: imgUrl.isNotEmpty
              ? null
              : Text(user['fullName']?[0] ?? '?',
                  style: const TextStyle(fontSize: 12)),
        );
      }
      return CircleAvatar(
        radius: 18,
        backgroundColor: const Color(0xFFF1F5F9),
        child: Text(user['fullName']?[0] ?? '?',
            style: const TextStyle(fontSize: 12)),
      );
    });
  }

  Widget _buildUserRow(Map<String, dynamic> user, bool isMobile) {
    bool isAdmin = user['permission'] == 'ผู้ดูแลระบบ';

    // 🔥 โมบายโหมด: เปลี่ยนเป็นรูปแบบ Card เพื่อให้กดปุ่ม Action ได้ครบถ้วนครับ 🥇🏆
    if (isMobile) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(user),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (user['forgotPasswordStatus'] == 'waiting')
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.notifications_active,
                                  color: Colors.orange, size: 16),
                            ),
                          Expanded(
                            child: Text(user['fullName'] ?? '-',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sarabun(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: user['forgotPasswordStatus'] ==
                                            'waiting'
                                        ? Colors.orange.shade800
                                        : Colors.black)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(user['position'] ?? 'ครู',
                          style: GoogleFonts.sarabun(
                              fontSize: 12, color: Colors.black54)),
                      if (user['ตำแหน่งงานบริหาร'] != null &&
                          user['ตำแหน่งงานบริหาร'].toString().isNotEmpty)
                        Text("${user['ตำแหน่งงานบริหาร']}",
                            style: GoogleFonts.sarabun(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _buildActionMenu(user),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('กลุ่มสาระฯ',
                          style: GoogleFonts.sarabun(
                              fontSize: 10, color: Colors.black38)),
                      Text(user['department'] ?? '-',
                          style: GoogleFonts.sarabun(
                              fontSize: 12, color: Colors.blueGrey)),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? const Color(0xFFFFF7ED)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user['permission'] ?? 'ครู',
                    style: GoogleFonts.sarabun(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isAdmin ? Colors.orange : Colors.blueGrey),
                  ),
                ),
              ],
            ),
            // 🔔 ปุ่มอนุมัติรีเซ็ตรหัส: แสดงเฉพาะเมื่อมีการแจ้งลืมรหัสรอดำเนินการครับ 🥇🏆
            if (user['forgotPasswordStatus'] == 'waiting') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _enablePasswordReset(user),
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: Text('อนุมัติการรีเซ็ตรหัสผ่าน',
                      style: GoogleFonts.sarabun(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          _buildAvatar(user),
          const SizedBox(width: 16),
          // ช่อง 1: ชื่อและตำแหน่ง (Flex 3)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (user['forgotPasswordStatus'] == 'waiting')
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.notifications_active,
                            color: Colors.orange, size: 16),
                      ),
                    Expanded(
                      child: Text(user['fullName'] ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sarabun(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: user['forgotPasswordStatus'] == 'waiting'
                                  ? Colors.orange.shade800
                                  : Colors.black)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (user['ตำแหน่งงานบริหาร'] != null &&
                        user['ตำแหน่งงานบริหาร'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text("${user['ตำแหน่งงานบริหาร']} /",
                            style: GoogleFonts.sarabun(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold)),
                      ),
                    Text(user['position'] ?? 'ครู',
                        style: GoogleFonts.sarabun(
                            fontSize: 11, color: Colors.black38)),
                  ],
                ),
              ],
            ),
          ),
          // ช่อง 2: กลุ่มสาระ (Flex 2)
          Expanded(
            flex: 2,
            child: Text(user['department'] ?? '-',
                style:
                    GoogleFonts.sarabun(fontSize: 12, color: Colors.blueGrey)),
          ),
          // ช่อง 3: วิทยฐานะ (Flex 2)
          Expanded(
            flex: 2,
            child: Text(
                user['academicStanding'] == '---เลือก---'
                    ? '-'
                    : (user['academicStanding'] ?? '-'),
                style: GoogleFonts.sarabun(
                    fontSize: 11,
                    color: Colors.blueGrey.shade400,
                    fontWeight: FontWeight.w500)),
          ),
          // ช่อง 4: สิทธิ์ (Flex 1)
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isAdmin ? const Color(0xFFFFF7ED) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user['permission'] ?? 'ครู',
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isAdmin ? Colors.orange : Colors.blueGrey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildActionMenu(user),
        ],
      ),
    );
  }

  // 🚨 แถบแจ้งเตือนด่วนสำหรับแอดมิน (Emergency Alert Bar) 🥇🏆
  Widget _buildEmergencyAlertBar(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFB91C1C)], // สีแดงสดตะโกนครับ!
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active,
                color: Colors.red, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('มีรายการแจ้งลืมรหัสผ่านรอการดำเนินการ',
                    style: GoogleFonts.sarabun(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(
                    'จำนวน $count รายการ กรุณารีเซ็ตรหัสผ่านเป็น 123456 เพื่อจัดการครับ',
                    style: GoogleFonts.sarabun(
                        color: Colors.white.withOpacity(0.9), fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // 🎢 เลื่อนไปจุดที่มีแจ้งเตือน (รายชื่อบนสุด) 🥇
              _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('ดูรายการ',
                style: GoogleFonts.sarabun(
                    fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTab(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSyncHeader(),
        const SizedBox(height: 32),
        if (!isWide) ...[
          _buildSyncInputCard(),
          const SizedBox(height: 24),
          _buildSyncPreviewCard(),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: _buildSyncInputCard()),
              const SizedBox(width: 24),
              Expanded(flex: 8, child: _buildSyncPreviewCard()),
            ],
          ),
      ],
    );
  }

  Widget _buildSyncHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.cloud_sync_rounded,
              color: Colors.blue, size: 28),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("นำเข้าข้อมูลบุคลากร",
                style: GoogleFonts.sarabun(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
            Text("เชื่อมต่อและดึงข้อมูลจาก Google Sheets อัตโนมัติ",
                style:
                    GoogleFonts.sarabun(fontSize: 13, color: Colors.blueGrey)),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncInputCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel('Apps Script URL (Web App)'),
          TextField(
            controller: _syncUrlController,
            decoration: InputDecoration(
              hintText: 'https://script.google.com/macros/s/.../exec',
              hintStyle: const TextStyle(fontSize: 11, color: Colors.black26),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              prefixIcon:
                  const Icon(Icons.link, size: 18, color: Colors.blueGrey),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 24),
          if (_syncStatusMsg != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: _syncStatusMsg!.contains('สำเร็จ')
                    ? Colors.green.withOpacity(0.05)
                    : Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _syncStatusMsg!.contains('สำเร็จ')
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    _syncStatusMsg!.contains('สำเร็จ')
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: _syncStatusMsg!.contains('สำเร็จ')
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_syncStatusMsg!,
                          style: GoogleFonts.sarabun(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _syncStatusMsg!.contains('สำเร็จ')
                                  ? Colors.green
                                  : Colors.orange))),
                ],
              ),
            ),
          ElevatedButton.icon(
            onPressed: _isFetchingSync ? null : _fetchSyncData,
            icon: _isFetchingSync
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(
                _isFetchingSync ? 'กำลังดึงข้อมูล...' : 'ตรวจสอบข้อมูลตัวอย่าง',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),
          if (_syncPreview.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _isPerformingSync ? null : _performSync,
              icon: _isPerformingSync
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                  _isPerformingSync
                      ? 'กำลังบันทึก...'
                      : 'บันทึกข้อมูลลงฐานข้อมูล',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSyncPreviewCard() {
    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ตัวอย่างข้อมูลที่จะนำเข้า',
                    style: GoogleFonts.sarabun(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (_syncPreview.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_syncPreview.length} รายการ',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_syncPreview.isNotEmpty)
            SizedBox(
              height:
                  500, // กำหนดความสูงที่แน่นอนเพื่อให้ DataTable แสดงผลได้ใน ScrollView ครับ 🥇
              child: Scrollbar(
                controller:
                    _syncHorizontalScrollController, // เชื่อมต่อ Controller แนวนอน
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller:
                      _syncHorizontalScrollController, // เชื่อมต่อ Controller แนวนอนเดียวกัน
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      dataRowMaxHeight: 50,
                      dataRowMinHeight: 40,
                      columnSpacing: 24,
                      headingTextStyle: GoogleFonts.sarabun(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey),
                      columns: [
                        const DataColumn(label: Text('#')),
                        // เลือกแสดงเฉพาะหัวตารางจริงๆ ที่ดึงมาครับ ไม่เอาคีย์ระบบมาปนให้งง 🥇
                        ...(_syncPreview[0]['_raw_headers'] as List<String>)
                            .map((k) =>
                                DataColumn(label: Text(k.toUpperCase()))),
                      ],
                      rows: List.generate(_syncPreview.length, (index) {
                        final item = _syncPreview[index];
                        final rawHeaders = item['_raw_headers'] as List<String>;

                        return DataRow(
                          cells: [
                            DataCell(Text((index + 1).toString(),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey))),
                            ...rawHeaders.map((h) {
                              String val = item[h]?.toString() ?? '-';
                              bool isMedicalCert =
                                  h.toLowerCase().contains('ใบรับรอง') ||
                                      h.toLowerCase().contains('แพทย์') ||
                                      h.toLowerCase().contains('medical');
                              bool isLink = val.startsWith('http');

                              Widget cellContent;
                              if (isMedicalCert && isLink) {
                                // 🕵️‍♂️ แปลงลิงก์ Google Drive ให้เป็นภาพตัวอย่าง (Thumbnail) ครับ 🥇🏆
                                String imgUrl = val;
                                if (val.contains('drive.google.com/file/d/')) {
                                  final regExp =
                                      RegExp(r'file/d/([a-zA-Z0-9-_]+)');
                                  final match = regExp.firstMatch(val);
                                  if (match != null) {
                                    imgUrl =
                                        'https://drive.google.com/uc?export=view&id=${match.group(1)}';
                                  }
                                }

                                cellContent = InkWell(
                                  onTap: () => launchUrl(
                                      Uri.parse(val)), // กดเพื่อดูไฟล์จริงครับ
                                  child: Container(
                                    width: 80,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.grey.withOpacity(0.2)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.network(
                                      imgUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => Center(
                                          child: Icon(
                                              Icons.insert_drive_file_outlined,
                                              size: 16,
                                              color: Colors.blue.shade300)),
                                      loadingBuilder: (ctx, child, progress) =>
                                          progress == null
                                              ? child
                                              : const Center(
                                                  child: SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: Colors
                                                                  .grey))),
                                    ),
                                  ),
                                );
                              } else {
                                cellContent = Text(val,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.sarabun(fontSize: 11));
                              }

                              return DataCell(Container(
                                constraints: BoxConstraints(
                                    maxWidth: isMedicalCert ? 100 : 200),
                                child: cellContent,
                              ));
                            }),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 500,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.table_rows_rounded,
                        size: 48, color: Colors.grey.shade200),
                    const SizedBox(height: 16),
                    Text('ยังไม่มีข้อมูลตัวอย่าง',
                        style: GoogleFonts.sarabun(
                            color: Colors.grey.shade400, fontSize: 13)),
                    Text('กรุณากดตรวจสอบข้อมูลด้านซ้ายครับ',
                        style: GoogleFonts.sarabun(
                            color: Colors.grey.shade300, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _fetchSyncData() async {
    String url = _syncUrlController.text.trim();
    if (url.isEmpty) {
      url =
          'https://docs.google.com/spreadsheets/d/1rei51ixTtvXGhxHkrApum6M_lpfGxDGr-QFMqB0_4c4/edit?gid=1827790500#gid=1827790500';
    }

    // 🕵️‍♂️ แปลงลิงก์ปกติให้เป็นลิงก์ Export CSV อัตโนมัติ (รองรับ GID ด้วยครับ) 🥇🏆
    if (url.contains('/spreadsheets/d/')) {
      final regExpId = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
      final regExpGid = RegExp(r'gid=([0-9]+)');

      final matchId = regExpId.firstMatch(url);
      final matchGid = regExpGid.firstMatch(url);

      if (matchId != null) {
        final id = matchId.group(1);
        final gid = matchGid != null ? matchGid.group(1) : '0';
        url =
            'https://docs.google.com/spreadsheets/d/$id/export?format=csv&gid=$gid';
      }
    }

    setState(() {
      _isFetchingSync = true;
      _syncStatusMsg = 'กำลังดึงข้อมูลจาก Google Sheets...';
      _syncPreview = [];
    });

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // 🔥 แกะข้อมูล CSV แบบ Super Robust 🥇🏆
        final csvString = utf8.decode(response.bodyBytes);

        // จัดการเรื่อง Line Break (รองรับทุก OS)
        final List<String> lines = csvString.split(RegExp(r'\r?\n'));
        if (lines.isEmpty || (lines.length == 1 && lines[0].trim().isEmpty)) {
          throw Exception('ไม่พบข้อมูลใดๆ ในไฟล์ครับ');
        }

        // ค้นหาหัวตารางและตัวคั่นข้อมูล (Comma หรือ Semicolon)
        String firstLine = lines[0];
        String delimiter = ',';
        if (!firstLine.contains(',') && firstLine.contains(';')) {
          delimiter = ';';
        }

        // ฟังก์ชันช่วย Map หัวตาราง (อัปเกรดให้รองรับข้อมูลการลาครับ! 🥇🏆)
        String mapKey(String h) {
          String raw = h.toLowerCase().trim();
          if (raw.contains('ชื่อ') &&
              (raw.contains('สกุล') || raw.contains('นาม'))) return 'fullName';
          if (raw.contains('ชื่อ') && raw.length <= 5) return 'fullName';
          if (raw.contains('ประเภท') && raw.contains('ลา')) return 'leaveType';
          if (raw.contains('เริ่ม')) return 'startDate';
          if (raw.contains('สิ้นสุด') || raw.contains('ถึง')) return 'endDate';
          if (raw.contains('เหตุผล')) return 'reason';
          if (raw.contains('สถานะ')) return 'status';
          if (raw.contains('id') || raw.contains('รหัส')) return 'requestId';
          if (raw.contains('ปีงบ')) return 'year';
          if (raw.contains('วัน') || raw.contains('total')) return 'days';
          if (raw.contains('ผู้ยื่น') || raw.contains('ผู้ยืน'))
            return 'submitter';
          if (raw.contains('ข้อมูล') || raw.contains('ติดต่อ'))
            return 'contact';
          if (raw.contains('ใบรับรอง') || raw.contains('แพทย์'))
            return 'medicalCertificate';
          if (raw.contains('ผู้ใช้') || raw.contains('username'))
            return 'username';
          return '';
        }

        // แยกหัวตารางดิบ (ใช้ RegExp เดียวกันกับแถวครับ เพื่อความชัวร์!)
        final RegExp headerExp =
            RegExp(delimiter + r'(?=(?:(?:[^"]*"){2})*[^"]*$)');
        final List<String> rawHeaders = firstLine
            .split(headerExp)
            .map((e) => e.trim().replaceAll('"', ''))
            .toList();
        final List<String> internalKeys =
            rawHeaders.map((e) => mapKey(e)).toList();
        final previewData = <Map<String, dynamic>>[];

        for (var i = 1; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          final RegExp rowExp = RegExp(delimiter +
              r'(?=(?:(?:[^**]*"){2})*[^**]*$)'.replaceAll('**', '"'));
          final List<String> rowItems = line
              .split(rowExp)
              .map((e) => e.trim().replaceAll('"', ''))
              .toList();
          if (rowItems.isEmpty || (rowItems.length == 1 && rowItems[0].isEmpty))
            continue;

          // 🛠️ คัดแยกและจัดการปัญหาข้อมูลเลื่อน (Shifting Issue) แบบละเอียดครับ 🥇🏆
          var activeHeaders = List<String>.from(rawHeaders);
          var activeKeys = List<String>.from(internalKeys);

          // ตรวจสอบ Timestamp Shift: ถ้า Row 1 Column 1 เป็น "ชื่อ" แต่ Row นี้ Column 1 เป็น "เวลา"
          // หรือถ้าจำนวน Column ข้อมูลมากกว่าหัวตารางจริงๆ ให้ดัน Timestamp เข้าไปครับ
          bool isTimestamp =
              rowItems[0].contains('/') && rowItems[0].contains(':');
          bool headerStartsWithName =
              rawHeaders.isNotEmpty && rawHeaders[0].contains('ชื่อ');

          if (isTimestamp && headerStartsWithName) {
            activeHeaders.insert(0, 'ประทับเวลา');
            activeKeys.insert(0, 'sync_timestamp');
          }

          final Map<String, dynamic> itemMap = {
            '_raw_headers': activeHeaders,
          };

          for (var j = 0; j < rowItems.length; j++) {
            if (j < activeHeaders.length) {
              String val = rowItems[j];
              itemMap[activeHeaders[j]] = val;

              if (j < activeKeys.length) {
                String mappedKey = activeKeys[j];
                if (mappedKey.isNotEmpty) {
                  itemMap[mappedKey] = val;
                }
              }
            }
          }

          // ✨ ระบบเจนรหัส ID อัตโนมัติถ้าไม่มีมาให้ครับ 🥇🏆
          if (itemMap['requestId'] == null ||
              itemMap['requestId'].toString().trim().isEmpty) {
            final now = DateTime.now().millisecondsSinceEpoch;
            itemMap['requestId'] =
                'LV-${now.toString().substring(now.toString().length - 6)}$i';
          }

          if (itemMap.keys.length > 1) {
            previewData.add(itemMap);
          }
        }

        setState(() {
          _syncPreview = previewData;
          _isFetchingSync = false;
          _syncStatusMsg = previewData.isNotEmpty
              ? 'ดึงข้อมูลสำเร็จ! พบ ${previewData.length} รายการจาก Sheets'
              : 'ดึงข้อมูลสำเร็จ แต่ตัวแปรในชีตไม่ตรงกับระบบครับ';
        });
      } else {
        throw Exception('ดึงข้อมูลล้มเหลว (Error: ${response.statusCode})');
      }
    } catch (e) {
      setState(() {
        _isFetchingSync = false;
        _syncStatusMsg =
            'เกิดข้อผิดพลาด: $e\n(ตรวจสอบว่าคุณครูเปิดการแชร์ลิงก์เป็นสาธารณะหรือยังครับ)';
      });
    }
  }

  Future<void> _performSync() async {
    if (_syncPreview.isEmpty) return;

    setState(() {
      _isPerformingSync = true;
      _syncStatusMsg = 'กำลังบันทึกข้อมูลลงฐานข้อมูล...';
    });

    int updated = 0;

    try {
      for (var item in _syncPreview) {
        final requestId = item['requestId']?.toString() ?? '';
        final fullName = item['fullName']?.toString() ?? '';

        if (requestId.isEmpty && fullName.isEmpty) continue;

        // 🛠️ ระบบคำนวณจำนวนวันอัตโนมัติ (Date Calculation) ครับ 🥇🏆
        String startDateStr = item['startDate']?.toString() ?? '';
        String endDateStr = item['endDate']?.toString() ?? '';
        String totalDays = item['days']?.toString() ?? '';

        if (totalDays.isEmpty || totalDays == '0') {
          try {
            // พยายามคำนวณจากวันที่ครับ (รองรับ d/m/yyyy)
            final startParts = startDateStr.split('/');
            final endParts = endDateStr.split('/');
            if (startParts.length == 3 && endParts.length == 3) {
              final start = DateTime(int.parse(startParts[2]),
                  int.parse(startParts[1]), int.parse(startParts[0]));
              final end = DateTime(int.parse(endParts[2]),
                  int.parse(endParts[1]), int.parse(endParts[0]));
              final diff = end.difference(start).inDays + 1;
              if (diff > 0) totalDays = diff.toString();
            }
          } catch (e) {
            totalDays = '1';
          }
        }

        final data = {
          'fullName': fullName,
          'leaveType': item['leaveType']?.toString() ?? 'ลาป่วย',
          'startDate': startDateStr,
          'endDate': endDateStr,
          'reason': item['reason']?.toString() ?? '',
          'status': item['status']?.toString() ?? 'ส่งใบลาแล้ว',
          'requestId': requestId,
          'year': item['year']?.toString() ?? '',
          'days': totalDays,
          'totalDays': totalDays,
          'medicalCertificate': item['medicalCertificate']?.toString() ??
              '', // ✨ เพิ่มช่องลิ้งค์ใบรับรองแพทย์ครับ
          'updatedAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        };

        // 🥇 บันทึกข้อมูลโดยพ่วง Document ID เป็นรหัสใบลา (requestId) เลยครับ
        await _firebaseService.db
            .collection('Leaves')
            .doc(requestId)
            .set(data, SetOptions(merge: true));
        updated++;
      }

      setState(() {
        _isPerformingSync = false;
        _syncStatusMsg =
            'ซิงค์ข้อมูลลงใบบันทึกการลา (Leaves) สำเร็จ! (ประมวลผล: $updated รายการ)';
        _syncPreview = [];
      });
    } catch (e) {
      setState(() {
        _isPerformingSync = false;
        _syncStatusMsg = 'เกิดข้อผิดพลาดระหว่างซิงค์ข้อมูล Leaves: $e';
      });
    }
  }

  Widget _buildGlassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
              color: Colors.blueGrey.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: child,
    );
  }

  // 🔥 ฟังก์ชันสำหรับสร้างหัวตารางให้ตรงแนวครับ
  Widget _buildTableLabelHeader() {
    TextStyle headerStyle = GoogleFonts.sarabun(
        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black26);
    return Padding(
      padding: const EdgeInsets.only(
          left: 52, right: 48), // เผื่อที่สำหรับ Avatar และ Action Icon
      child: Row(
        children: [
          Expanded(
              flex: 3, child: Text('ชื่อ-ตำแหน่งบริหาร', style: headerStyle)),
          Expanded(
              flex: 2, child: Text('กลุ่มสาระการเรียนรู้', style: headerStyle)),
          Expanded(flex: 2, child: Text('วิทยฐานะ', style: headerStyle)),
          Expanded(
              flex: 1,
              child: Text('สิทธิ์',
                  textAlign: TextAlign.center, style: headerStyle)),
        ],
      ),
    );
  }

  Widget _buildActionMenu(Map<String, dynamic> user) {
    final bool isWaiting = (user['forgotPasswordStatus'] ?? '') == 'waiting';

    return PopupMenuButton<String>(
      icon:
          const Icon(Icons.more_vert_rounded, size: 18, color: Colors.blueGrey),
      onSelected: (val) {
        if (val == 'edit') {
          _editUser(user);
        } else if (val == 'delete') {
          _deleteUser(user);
        } else if (val == 'view_password') {
          _viewPassword(user);
        } else if (val == 'allow_reset') {
          _enablePasswordReset(user);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text('แก้ไข')
            ])),
        const PopupMenuItem(
            value: 'view_password',
            child: Row(children: [
              Icon(Icons.visibility_outlined, size: 16, color: Colors.indigo),
              SizedBox(width: 8),
              Text('ดูรหัสผ่าน')
            ])),
        // 🔴 ปุ่มเปลี่ยนตามสถานะ: "อนุมัติการรีเซ็ต" หรือ "รีเซ็ตรหัส"
        PopupMenuItem(
            value: 'allow_reset',
            child: Row(children: [
              Icon(
                isWaiting ? Icons.key_rounded : Icons.lock_reset_rounded,
                size: 16,
                color: isWaiting ? Colors.red : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                isWaiting ? 'อนุมัติการรีเซ็ต' : 'รีเซ็ตรหัส',
                style: TextStyle(
                  color: isWaiting ? Colors.red : Colors.black87,
                  fontWeight: isWaiting ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ])),
        const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('ลบข้อมูล', style: TextStyle(color: Colors.red))
            ])),
      ],
    );
  }

  // 🕵️‍♂️ ฟังก์ชันรีเซ็ตรหัสเป็น 123456 และเปิดสิทธิ์ 24 ชม. สำหรับแอดมินครับ 🥇🏆
  void _enablePasswordReset(Map<String, dynamic> user) async {
    final DateTime expiry = DateTime.now().add(const Duration(hours: 24));

    try {
      await FirebaseFirestore.instanceFor(
              app: Firebase.app(), databaseId: 'school')
          .collection('Teachers')
          .doc(user['id'])
          .update({
        'password': '123456',
        'forgotPasswordStatus': 'reset_by_admin',
        'resetAllowedUntil': Timestamp.fromDate(expiry)
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'รีเซ็ตรหัสผ่านสำหรับ ${user['fullName']} เป็น 123456 สำเร็จ! (ใช้ได้ถึง ${expiry.day}/${expiry.month}/${expiry.year + 543} ${expiry.hour}:${expiry.minute.toString().padLeft(2, '0')} น.)'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 🕵️‍♂️ ฟังก์ชันส่องรหัสผ่านสำหรับแอดมินครับ (Phase 5 - Convenient & Secure) 🥇🏆
  void _viewPassword(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.vpn_key_outlined, color: Colors.indigo),
            const SizedBox(width: 12),
            Text('ตรวจสอบรหัสผ่าน',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('รหัสผ่านของ ${user['fullName'] ?? 'ผู้ใช้งาน'}:',
                style: GoogleFonts.sarabun(color: Colors.blueGrey)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.withOpacity(0.1)),
              ),
              child: SelectableText(
                user['password']?.toString() ?? 'ไม่พบข้อมูล',
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
                '* คุณครูสามารถคัดลอกรหัสผ่านนี้ไปแจ้งเจ้าของบัญชีได้ทันทีครับ',
                style: GoogleFonts.sarabun(
                    fontSize: 11, color: Colors.blueGrey.withOpacity(0.7))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ตกลง',
                style: GoogleFonts.sarabun(
                    fontWeight: FontWeight.bold, color: Colors.indigo)),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(t,
          style: GoogleFonts.sarabun(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey)));

  Widget _buildTextField(TextEditingController ctrl, String hint,
          {bool obscure = false, IconData? icon}) =>
      TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
              hintText: hint,
              prefixIcon: icon != null
                  ? Icon(icon, size: 18, color: Colors.blueGrey)
                  : null,
              hintStyle: const TextStyle(fontSize: 12, color: Colors.black26),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade100)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade100))),
          style: const TextStyle(fontSize: 13));

  Widget _buildDropdownField({
    required List<String> items,
    required String? val,
    required Function(String?) onC,
    IconData? icon,
    Color? color,
    Color? iconColor,
    String? hint,
  }) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: color ?? const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color != null
                      ? color.withOpacity(0.5)
                      : Colors.grey.shade100)),
          child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
            value: (items.isNotEmpty && val != null && items.contains(val))
                ? val
                : (items.isNotEmpty ? items.first : null),
            isExpanded: true,
            hint: hint != null
                ? Text(hint,
                    style: const TextStyle(fontSize: 12, color: Colors.black26))
                : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Colors.black26),
            items: items
                .map((e) => DropdownMenuItem(
                    value: e,
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon,
                              size: 18, color: iconColor ?? Colors.blueGrey),
                          const SizedBox(width: 8),
                        ],
                        Text(e, style: const TextStyle(fontSize: 12)),
                      ],
                    )))
                .toList(),
            onChanged: onC,
          )));

  // 🕵️‍♂️ ฟังก์ชันดึงปฏิทินพรีเมียมตัวใหม่มาใช้งานครับ 🥇🏆
  Future<void> _showPremiumDatePicker(
      DateTime initial, Function(DateTime) onPick) async {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Center(
        child: ThaiBuddhistCalendarWidget(
          initialDate: initial,
          firstDate: DateTime(DateTime.now().year - 5),
          lastDate: DateTime(DateTime.now().year + 5),
          onDateSelected: onPick,
        ),
      ),
    );
  }

  Widget _buildDatePickerField(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const Icon(Icons.calendar_month_outlined,
                size: 18, color: Colors.blueGrey),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 6: ระบบจัดการปีงบประมาณ (Academic Years)
  // ==========================================
  Widget _buildBudgetTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.calendar_month_rounded,
                  color: primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ตั้งค่ารอบงบประมาณ",
                    style: GoogleFonts.sarabun(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryColor)),
                Text(
                    "กำหนดช่วงเวลาของแต่ละรอบงบประมาณเพื่อใช้ในการสรุปสถิติการลา",
                    style: GoogleFonts.sarabun(
                        color: Colors.blueGrey, fontSize: 13)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ฝั่งซ้าย: เพิ่มรอบงบประมาณ
            Expanded(
              flex: 4,
              child: _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("เพิ่มรอบงบประมาณ",
                        style: GoogleFonts.sarabun(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 24),
                    _buildFieldLabel("ปีงบประมาณ (พ.ศ.)"),
                    _buildTextField(_yearController, "เช่น 2569",
                        icon: Icons.calendar_today_rounded),
                    const SizedBox(height: 16),
                    _buildFieldLabel("รอบที่"),
                    _buildRoundDropdown(),
                    const SizedBox(height: 16),
                    _buildFieldLabel("เริ่มต้นตั้งแต่วันที่"),
                    _buildDatePickerField(
                        FirebaseService.formatThaiDate(_roundStartDate), () {
                      _showPremiumDatePicker(_roundStartDate,
                          (d) => setState(() => _roundStartDate = d));
                    }),
                    const SizedBox(height: 16),
                    _buildFieldLabel("ถึงวันที่"),
                    _buildDatePickerField(
                        FirebaseService.formatThaiDate(_roundEndDate), () {
                      _showPremiumDatePicker(_roundEndDate,
                          (d) => setState(() => _roundEndDate = d));
                    }),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_yearController.text.isNotEmpty) {
                          final String yearStr = _yearController.text;

                          // 🧮 ใช้วันที่ที่เลือกจากปฏิทินพรีเมียมครับ 🥇🏆🏎️
                          final int startYearBE = _roundStartDate.year < 2400
                              ? _roundStartDate.year + 543
                              : _roundStartDate.year;
                          final int endYearBE = _roundEndDate.year < 2400
                              ? _roundEndDate.year + 543
                              : _roundEndDate.year;

                          final String startDate =
                              "${_roundStartDate.day}/${_roundStartDate.month}/$startYearBE";
                          final String endDate =
                              "${_roundEndDate.day}/${_roundEndDate.month}/$endYearBE";

                          await _firebaseService.addFiscalRound({
                            'year': yearStr,
                            'round': _selectedRound,
                            'startDate': startDate,
                            'endDate': endDate,
                          });

                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'เพิ่มรอบงบประมาณเรียบร้อยแล้วครับ')));
                        }
                      },
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text("เพิ่มข้อมูล",
                          style:
                              GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // ฝั่งขวา: รายการรอบงบประมาณ
            Expanded(
              flex: 8,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firebaseService.getFiscalRoundsStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final rounds = snapshot.data!;

                    return _buildGlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.table_chart_outlined,
                                      size: 20, color: Colors.blue),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("รายชื่อรอบงบประมาณทั้งหมด",
                                        style: GoogleFonts.sarabun(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: primaryColor)),
                                    Text("ข้อมูลช่วงเวลาที่บันทึกไว้ในระบบ",
                                        style: GoogleFonts.sarabun(
                                            fontSize: 12,
                                            color: Colors.blueGrey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          if (rounds.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(
                                  child: Text("ยังไม่มีข้อมูลรอบงบประมาณในระบบ",
                                      style: GoogleFonts.sarabun(
                                          color: Colors.grey))),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: rounds.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final r = rounds[index];

                                // 📅 ตรวจสอบว่าตรงกับปฏิทินปัจจุบันหรือไม่ 🕵️‍♂️
                                final now = DateTime.now();
                                final todayStr =
                                    "${now.day}/${now.month}/${now.year + 543}";
                                bool isCurrentCalendar =
                                    FirebaseService.isDateInRange(
                                        todayStr,
                                        r['startDate'] ?? '',
                                        r['endDate'] ?? '');

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  title: Row(
                                    children: [
                                      Text(
                                          "ปี ${r['year']} รอบที่ ${r['round']}",
                                          style: GoogleFonts.sarabun(
                                              fontWeight: FontWeight.bold)),
                                      if (isCurrentCalendar)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 12),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.blue
                                                    .withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.auto_awesome,
                                                  size: 10, color: Colors.blue),
                                              const SizedBox(width: 4),
                                              Text("ปัจจุบัน (ตามปฏิทิน)",
                                                  style: GoogleFonts.sarabun(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.blue)),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                          "ช่วงเวลา: ${FirebaseService.formatThaiDate(r['startDate'])} - ${FirebaseService.formatThaiDate(r['endDate'])}",
                                          style: GoogleFonts.sarabun(
                                              fontSize: 12)),
                                      if (isCurrentCalendar)
                                        Text(
                                            "สถานะ: กำลังใช้งานสรุปผล (อัตโนมัติ 🏎️)",
                                            style: GoogleFonts.sarabun(
                                                fontSize: 12,
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold))
                                      else
                                        Text("สถานะ: พร้อมใช้งาน (ตามช่วงเวลา)",
                                            style: GoogleFonts.sarabun(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                    ],
                                  ),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: isCurrentCalendar
                                            ? Colors.blue.withOpacity(0.1)
                                            : Colors.blueGrey.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(
                                        isCurrentCalendar
                                            ? Icons.auto_awesome_rounded
                                            : Icons.calendar_today_rounded,
                                        color: isCurrentCalendar
                                            ? Colors.blue
                                            : Colors.blueGrey,
                                        size: 24),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () {
                                          _firebaseService
                                              .deleteFiscalRound(r['id']);
                                          if (mounted)
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'ลบข้อมูลรอบงบประมาณเรียบร้อยแล้วครับ')));
                                        },
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red, size: 20),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  }),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDateForStorage(DateTime date) {
    return '${date.day}/${date.month}/${date.year + 543}';
  }

  String _formatDateDisplay(DateTime date) {
    return '${date.day} ${_thaiMonths[date.month - 1]} ${date.year + 543}';
  }

  DateTime? _parseStoredDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final isoDate = DateTime.tryParse(text);
    if (isoDate != null) return isoDate;

    final parts = RegExp(r'\d+')
        .allMatches(text)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList();
    if (parts.length < 3) return null;

    int day;
    int month;
    int year;

    if (parts[0] > 1900) {
      year = parts[0];
      month = parts[1];
      day = parts[2];
    } else {
      day = parts[0];
      month = parts[1];
      year = parts[2];
    }

    if (year > 2400) year -= 543;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime? _recordDate(Map<String, dynamic> data) {
    return _parseStoredDate(data['dateValue']) ??
        _parseStoredDate(data['date']) ??
        _parseStoredDate(data['day']) ??
        _parseStoredDate(data['workDate']);
  }

  String _recordTitle(Map<String, dynamic> data) {
    final title = data['title'] ??
        data['name'] ??
        data['note'] ??
        data['description'] ??
        data['detail'];
    final text = title?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  Future<void> _saveHoliday() async {
    final title = _holidayTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อวันหยุดก่อนบันทึก')),
      );
      return;
    }

    final docId = 'holiday_${_dateKey(_holidayDate).replaceAll('-', '')}';
    await _firebaseService.db.collection('SpecialHolidays').doc(docId).set({
      'date': _formatDateForStorage(_holidayDate),
      'dateValue': Timestamp.fromDate(_holidayDate),
      'title': title,
      'note': title,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _holidayTitleController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกวันหยุดเรียบร้อยแล้วครับ')),
    );
  }

  Future<void> _saveSpecialWorkingDay() async {
    final title = _specialWorkingTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อวันทำงานพิเศษก่อนบันทึก')),
      );
      return;
    }

    final docId =
        'working_${_dateKey(_specialWorkingDate).replaceAll('-', '')}';
    await _firebaseService.db.collection('SpecialWorkingDays').doc(docId).set({
      'date': _formatDateForStorage(_specialWorkingDate),
      'dateValue': Timestamp.fromDate(_specialWorkingDate),
      'title': title,
      'note': title,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _specialWorkingTitleController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('บันทึกวันทำงานพิเศษเรียบร้อยแล้วครับ')),
    );
  }

  Future<void> _deleteSpecialDateRecord(
    String collection,
    String docId,
    String message,
  ) async {
    await _firebaseService.db.collection(collection).doc(docId).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<Set<String>> _loadSpecialDateKeys(String collection) async {
    final snapshot = await _firebaseService.db.collection(collection).get();
    return snapshot.docs
        .map((doc) => _recordDate(doc.data()))
        .whereType<DateTime>()
        .map(_dateKey)
        .toSet();
  }

  double _calculateBusinessLeaveDays(
    Map<String, dynamic> leave,
    Set<String> holidayKeys,
    Set<String> specialWorkingKeys,
  ) {
    if (FirebaseService.isHalfDayLeave(leave)) return 0.5;

    final start = _recordDate({
      'date': leave['startDate'],
      'dateValue': leave['startDateValue'],
    });
    final end = _recordDate({
      'date': leave['endDate'],
      'dateValue': leave['endDateValue'],
    });
    if (start == null || end == null) {
      final current = leave['totalDays'] ?? leave['days'];
      if (current is num) return current.toDouble();
      return double.tryParse(current?.toString() ?? '') ?? 0;
    }

    final first = DateTime(start.year, start.month, start.day)
            .isBefore(DateTime(end.year, end.month, end.day))
        ? DateTime(start.year, start.month, start.day)
        : DateTime(end.year, end.month, end.day);
    final last = DateTime(start.year, start.month, start.day)
            .isBefore(DateTime(end.year, end.month, end.day))
        ? DateTime(end.year, end.month, end.day)
        : DateTime(start.year, start.month, start.day);

    double total = 0;
    for (DateTime day = first;
        !day.isAfter(last);
        day = day.add(const Duration(days: 1))) {
      final key = _dateKey(day);
      final isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

      if (specialWorkingKeys.contains(key)) {
        total += 1;
      } else if (holidayKeys.contains(key)) {
        continue;
      } else if (!isWeekend) {
        total += 1;
      }
    }

    return total;
  }

  Future<void> _recalculateAllLeaveDays() async {
    setState(() => _isRecalculatingLeaves = true);
    try {
      final holidayKeys = await _loadSpecialDateKeys('SpecialHolidays');
      final specialWorkingKeys =
          await _loadSpecialDateKeys('SpecialWorkingDays');
      final snapshot = await _firebaseService.db.collection('Leaves').get();

      var batch = _firebaseService.db.batch();
      int pendingWrites = 0;
      int updated = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final totalDays =
            _calculateBusinessLeaveDays(data, holidayKeys, specialWorkingKeys);

        batch.update(doc.reference, {
          'days': totalDays,
          'totalDays': totalDays,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        pendingWrites++;
        updated++;

        if (pendingWrites >= 450) {
          await batch.commit();
          batch = _firebaseService.db.batch();
          pendingWrites = 0;
        }
      }

      if (pendingWrites > 0) {
        await batch.commit();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('คำนวณวันลาย้อนหลังใหม่แล้ว $updated รายการ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('คำนวณวันลาย้อนหลังไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRecalculatingLeaves = false);
    }
  }

  Future<void> _installDefaultHolidaysForCurrentYear() async {
    setState(() => _isInstallingHolidays = true);
    try {
      final year = DateTime.now().year;
      final holidays = <Map<String, dynamic>>[
        {'date': DateTime(year, 1, 1), 'title': 'วันขึ้นปีใหม่'},
        {'date': DateTime(year, 3, 3), 'title': 'วันมาฆบูชา'},
        {'date': DateTime(year, 4, 6), 'title': 'วันจักรี'},
        {'date': DateTime(year, 4, 13), 'title': 'วันสงกรานต์'},
        {'date': DateTime(year, 4, 14), 'title': 'วันสงกรานต์'},
        {'date': DateTime(year, 4, 15), 'title': 'วันสงกรานต์'},
        {'date': DateTime(year, 5, 1), 'title': 'วันแรงงานแห่งชาติ'},
        {'date': DateTime(year, 5, 4), 'title': 'วันฉัตรมงคล'},
        {'date': DateTime(year, 5, 13), 'title': 'วันพืชมงคล'},
        {'date': DateTime(year, 5, 31), 'title': 'วันวิสาขบูชา'},
        {
          'date': DateTime(year, 6, 3),
          'title': 'วันเฉลิมพระชนมพรรษาสมเด็จพระราชินี'
        },
        {
          'date': DateTime(year, 7, 28),
          'title': 'วันเฉลิมพระชนมพรรษาพระบาทสมเด็จพระเจ้าอยู่หัว'
        },
        {'date': DateTime(year, 7, 29), 'title': 'วันอาสาฬหบูชา'},
        {'date': DateTime(year, 8, 12), 'title': 'วันแม่แห่งชาติ'},
        {'date': DateTime(year, 10, 13), 'title': 'วันนวมินทรมหาราช'},
        {'date': DateTime(year, 10, 23), 'title': 'วันปิยมหาราช'},
        {'date': DateTime(year, 12, 5), 'title': 'วันพ่อแห่งชาติ'},
        {'date': DateTime(year, 12, 10), 'title': 'วันรัฐธรรมนูญ'},
        {'date': DateTime(year, 12, 31), 'title': 'วันสิ้นปี'},
      ];

      final batch = _firebaseService.db.batch();
      for (final holiday in holidays) {
        final date = holiday['date'] as DateTime;
        final title = holiday['title'] as String;
        final docId = 'holiday_${_dateKey(date).replaceAll('-', '')}';
        final ref =
            _firebaseService.db.collection('SpecialHolidays').doc(docId);
        batch.set(
            ref,
            {
              'date': _formatDateForStorage(date),
              'dateValue': Timestamp.fromDate(date),
              'title': title,
              'note': title,
              'source': 'default_${year + 543}',
              'updatedAt': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'ติดตั้งวันหยุดราชการหลักปี ${year + 543} แล้ว ${holidays.length} วัน'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ติดตั้งวันหยุดราชการหลักไม่สำเร็จ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isInstallingHolidays = false);
    }
  }

  Widget _buildHolidayTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เพิ่มวันหยุดใหม่',
                style: GoogleFonts.sarabun(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'กำหนดวันหยุดนักขัตฤกษ์ วันหยุดพิเศษ หรือวันหยุดเฉพาะของโรงเรียน เพื่อใช้หักลบจำนวนวันลาโดยอัตโนมัติ',
                style:
                    GoogleFonts.sarabun(color: Colors.blueGrey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final dateField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('เลือกวันที่หยุด'),
                      _buildDatePickerField(
                        _formatDateDisplay(_holidayDate),
                        () => _showPremiumDatePicker(
                          _holidayDate,
                          (date) => setState(() => _holidayDate = date),
                        ),
                      ),
                    ],
                  );
                  final titleField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('ชื่อวันหยุด / รายละเอียด'),
                      _buildTextField(
                        _holidayTitleController,
                        'เช่น วันสงกรานต์, วันครู, ปิดเทอมภาคเรียน',
                        icon: Icons.edit_calendar_rounded,
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        dateField,
                        const SizedBox(height: 16),
                        titleField,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(flex: 4, child: dateField),
                      const SizedBox(width: 24),
                      Expanded(flex: 6, child: titleField),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isRecalculatingLeaves
                        ? null
                        : _recalculateAllLeaveDays,
                    icon: _isRecalculatingLeaves
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(
                      _isRecalculatingLeaves
                          ? 'กำลังคำนวณ...'
                          : 'คำนวณวันลาย้อนหลังใหม่ทั้งหมด',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide(color: Colors.orange.shade200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isInstallingHolidays
                        ? null
                        : _installDefaultHolidaysForCurrentYear,
                    icon: _isInstallingHolidays
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 18),
                    label: Text(_isInstallingHolidays
                        ? 'กำลังติดตั้ง...'
                        : 'ติดตั้งวันหยุดราชการหลักปีนี้'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor.withOpacity(0.35)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveHoliday,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('บันทึกวันหยุด'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSpecialDateList(
          collection: 'SpecialHolidays',
          title: 'รายการวันหยุดกำหนดเองในระบบ',
          emptyText: 'ยังไม่มีข้อมูลวันหยุดพิเศษเพิ่มเติม',
          emptySubText:
              'วันหยุดเสาร์-อาทิตย์และวันหยุดนักขัตฤกษ์พื้นฐานรองรับอยู่ในระบบโดยอัตโนมัติแล้วครับ',
          chipSuffix: 'วัน',
          accent: Colors.amber,
          icon: Icons.event_available_rounded,
          deleteMessage: 'ลบวันหยุดเรียบร้อยแล้วครับ',
        ),
      ],
    );
  }

  Widget _buildSpecialWorkingDayTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ตั้งค่าวันทำงานพิเศษ (เสาร์-อาทิตย์)',
          style: GoogleFonts.sarabun(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'กำหนดวันเสาร์หรืออาทิตย์ที่มีนโยบายการเรียนการสอนของโรงเรียน เพื่อให้นับเป็นวันลาทำงานจริง (ไม่นับวันเสาร์-อาทิตย์)',
          style: GoogleFonts.sarabun(color: Colors.blueGrey, fontSize: 13),
        ),
        const SizedBox(height: 28),
        _buildGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'เพิ่มวันทำงานพิเศษใหม่',
                style: GoogleFonts.sarabun(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 900;
                  final dateField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('วันที่ทำกิจกรรมพิเศษ'),
                      _buildDatePickerField(
                        _formatDateDisplay(_specialWorkingDate),
                        () => _showPremiumDatePicker(
                          _specialWorkingDate,
                          (date) => setState(() => _specialWorkingDate = date),
                        ),
                      ),
                    ],
                  );
                  final titleField = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel(
                          'ชื่อวันเรียนชดเชย / กิจกรรมตามนโยบายโรงเรียน'),
                      _buildTextField(
                        _specialWorkingTitleController,
                        'เช่น สอนชดเชยวันลอยกระทง, MEP สอนพิเศษ, โครงการเตรียมความพร้อม',
                        icon: Icons.assignment_turned_in_rounded,
                      ),
                    ],
                  );
                  final saveButton = ElevatedButton.icon(
                    onPressed: _saveSpecialWorkingDay,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('บันทึกวันทำงานพิเศษ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dateField,
                        const SizedBox(height: 16),
                        titleField,
                        const SizedBox(height: 16),
                        saveButton,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(flex: 3, child: dateField),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: titleField),
                      const SizedBox(width: 16),
                      saveButton,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        _buildSpecialDateList(
          collection: 'SpecialWorkingDays',
          title: 'รายการวันทำงานพิเศษกำหนดเองในระบบ',
          emptyText: 'ยังไม่มีข้อมูลวันทำงานพิเศษเพิ่มเติม',
          emptySubText:
              'เพิ่มวันที่โรงเรียนมีนโยบายให้วันเสาร์-อาทิตย์เป็นวันทำงานจริงได้จากฟอร์มด้านบนครับ',
          chipSuffix: 'วัน',
          accent: Colors.yellow.shade700,
          icon: Icons.calendar_today_rounded,
          deleteMessage: 'ลบวันทำงานพิเศษเรียบร้อยแล้วครับ',
        ),
      ],
    );
  }

  Widget _buildSpecialDateList({
    required String collection,
    required String title,
    required String emptyText,
    required String emptySubText,
    required String chipSuffix,
    required Color accent,
    required IconData icon,
    required String deleteMessage,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firebaseService.db.collection(collection).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildGlassCard(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final records = snapshot.data!.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        records.sort((a, b) {
          final aDate = _recordDate(a);
          final bDate = _recordDate(b);
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });

        return _buildGlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.sarabun(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        'ทั้งหมด ${records.length} $chipSuffix',
                        style: GoogleFonts.sarabun(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (records.isEmpty)
                SizedBox(
                  height: 220,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emptyText,
                          style: GoogleFonts.sarabun(
                            color: Colors.blueGrey,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          emptySubText,
                          style: GoogleFonts.sarabun(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final date = _recordDate(record);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 20, color: accent),
                      ),
                      title: Text(
                        _recordTitle(record),
                        style: GoogleFonts.sarabun(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      subtitle: Text(
                        date == null ? '-' : _formatDateDisplay(date),
                        style: GoogleFonts.sarabun(color: Colors.blueGrey),
                      ),
                      trailing: IconButton(
                        onPressed: () => _deleteSpecialDateRecord(
                          collection,
                          record['id'].toString(),
                          deleteMessage,
                        ),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoundDropdown() {
    return _buildDropdownField(
      val: _selectedRound,
      items: ['1', '2'],
      icon: Icons.group_work_outlined,
      onC: (val) => setState(() => _selectedRound = val!),
    );
  }

  // ❌ ลบ _buildMonthDropdown ออกไปเพราะใช้ Premium Calendar แทนแล้วครับ 🥇🏆
}
