import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/firebase_service.dart';
import '../services/migration_service.dart';
import '../services/mobile_permission_migration.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'line_settings_screen.dart';
import 'calendar_settings_tab.dart';
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
  final Set<String> _selectedMigrationCollections = <String>{};
  bool _migrationSelectionTouched = false;
  bool _isClearingImportTables = false;

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
  Map<String, int> _masterOrderByKey = {};
  List<String> _ranks = ['---เลือก---'];
  List<String> _roles = ['ครู'];
  List<String> _adminPositions = ['ไม่มีตำแหน่งบริหาร'];
  List<String> _leaveTypes = []; // 🔥 ตัวแปรสำหรับประเภทการลาครับ 🥇🏆
  bool _isLoadingDropdowns = true;
  String _searchText = ''; // 🔥 ตัวแปรสำหรับค้นหาแบบ Real-time ครับ 🥇🏆
  int _masterSubTab = 0; // 🔥 ตัวแปรสำหรับสลับหมวดหมู่ข้อมูลพื้นฐานครับ 🥇🏆

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

      final users = await _firebaseService.getUsersFromSupabase();
      Map<String, dynamic>? matchedUser;

      if (cachedDocId.isNotEmpty) {
        matchedUser = users.firstWhere(
          (u) => (u['id'] ?? '').toString().trim() == cachedDocId,
          orElse: () => {},
        );
      }
      if ((matchedUser == null || matchedUser.isEmpty) &&
          cachedUsername.isNotEmpty) {
        matchedUser = users.firstWhere(
          (u) => (u['username'] ?? '').toString().trim() == cachedUsername,
          orElse: () => {},
        );
      }
      if ((matchedUser == null || matchedUser.isEmpty) &&
          currentUser.isNotEmpty) {
        matchedUser = users.firstWhere(
          (u) =>
              (u['fullName'] ?? u['name'] ?? '').toString().trim() ==
              currentUser,
          orElse: () => {},
        );
      }

      if (matchedUser != null && matchedUser.isNotEmpty) {
        final role = _resolveEffectiveRole([
          matchedUser['role'],
          matchedUser['permission'],
          cachedRole,
        ]);
        await prefs.setString('userRole', role);
        await prefs.setString('userFullDataJson', jsonEncode(matchedUser));
        return true;
      }

      return currentUser.isNotEmpty;
    } catch (e) {
      debugPrint('Role sync failed: $e');
    }
    return false;
  }

  String _masterIdFieldForCollection(String collection) {
    switch (collection) {
      case 'Positions':
        return 'ID_Positions';
      case 'Academics':
        return 'ID_Academics';
      case 'Departments':
        return 'ID_Departments';
      case 'Roles':
        return 'ID_Roles';
      case 'AdminRoles':
        return 'ID_AdminRoles';
      case 'LeaveTypes':
        return 'ID_LeaveTypes';
      default:
        return '';
    }
  }

  String _masterNameFieldForCollection(String collection) {
    switch (collection) {
      case 'Positions':
        return 'ตำแหน่ง';
      case 'Academics':
        return 'วิทยฐานะ';
      case 'Departments':
        return 'แผนก_กลุ่มสาระ';
      case 'Roles':
        return 'สิทธิ์การเข้าถึง';
      case 'AdminRoles':
        return 'ตำแหน่งบริหาร';
      case 'LeaveTypes':
        return 'ประเภทการลา';
      default:
        return 'Value';
    }
  }

  String _masterOrderKey(String collection, String value) {
    return '$collection::$value';
  }

  String _masterNameFromData(
    Map<String, dynamic> data,
    String collection,
  ) {
    final schemaName = data[_masterNameFieldForCollection(collection)];
    if (schemaName is String && schemaName.trim().isNotEmpty) {
      return schemaName.trim();
    }

    final legacyName = data['Value'];
    if (legacyName is String && legacyName.trim().isNotEmpty) {
      return legacyName.trim();
    }

    for (final entry in data.entries) {
      if (entry.value is String &&
          !entry.key.toUpperCase().contains('ID') &&
          entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }

    return '';
  }

  Future<Map<String, int>> _loadMasterOrderByKey() async {
    const collections = [
      'Positions',
      'Academics',
      'Departments',
      'Roles',
      'AdminRoles',
      'LeaveTypes',
    ];
    final orders = <String, int>{};

    for (final collection in collections) {
      final snapshot = await _firebaseService.db.collection(collection).get();
      final idField = _masterIdFieldForCollection(collection);

      for (final doc in snapshot.docs) {
        final name = _masterNameFromData(doc.data(), collection);
        if (name.isEmpty) continue;

        final dataOrder = _toIntValue(doc.data()[idField]);
        final docOrder = _toIntValue(doc.id);
        final order = dataOrder > 0 ? dataOrder : docOrder;
        if (order > 0) {
          orders[_masterOrderKey(collection, name)] = order;
        }
      }
    }

    return orders;
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
        _loadMasterOrderByKey(),
      ]);

      final pos = results[0] as List<String>;
      final dep = results[1] as List<String>;
      final rnk = results[2] as List<String>;
      final pms = results[3] as List<String>;
      final adm = results[4] as List<String>;
      final lvt = results[5] as List<String>;
      final masterOrders = results[6] as Map<String, int>;

      setState(() {
        if (pos.isNotEmpty) _positions = ['---เลือก---', ...pos];
        if (dep.isNotEmpty) _departments = ['---เลือก---', ...dep];
        _masterOrderByKey = masterOrders;
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
      'role': _selectedRole,
      'permission': _selectedRole,
      'ตำแหน่งงานบริหาร': _adminPosController.text,
      'profileImage': _photoController.text,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final String inputPassword = _passController.text.trim();

    try {
      await _syncCurrentUserRole();

      if (_isEditing && _editingId != null) {
        String newPhoto = _photoController.text;

        if (_oldPhotoUrl.trim().isNotEmpty && _oldPhotoUrl != newPhoto) {
          await _firebaseService.deleteDriveFileStrict(_oldPhotoUrl);
        }

        final updateData = Map<String, dynamic>.from(data);
        updateData.remove('password');
        await _firebaseService.updateUser(_editingId!, updateData);

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
      _passController.text = (user['password']?.toString() ?? '');
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
    final uploadInput =
        web.document.createElement('input') as web.HTMLInputElement
          ..type = 'file'
          ..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.length > 0) {
        final file = files.item(0)!;
        final reader = web.FileReader();
        reader.readAsDataURL(file);

        reader.onLoadEnd.listen((e) async {
          final result = reader.result as String;

          final img = web.document.createElement('img') as web.HTMLImageElement
            ..src = result;
          img.onLoad.listen((_) async {
            final canvas =
                web.document.createElement('canvas') as web.HTMLCanvasElement;
            const int maxSize = 350;
            int width = img.naturalWidth;
            int height = img.naturalHeight;
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
            final ctx =
                canvas.getContext('2d')! as web.CanvasRenderingContext2D;
            ctx.drawImage(img, 0, 0, width.toDouble(), height.toDouble());

            final compressedData = canvas.toDataURL('image/jpeg', 0.85.toJS);

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
                      color: Colors.blue.withValues(alpha: 0.1),
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
                      color: Colors.orange.withValues(alpha: 0.1),
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
                      color: Colors.red.withValues(alpha: 0.1),
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

  // 🔄 Modal Popup แสดงความคืบหน้าการ Export & Import ไป Supabase
  String _migrationTableGroup(String table) {
    switch (table) {
      case 'Teachers':
      case 'UserRoles':
      case 'LoginLogs':
        return 'ผู้ใช้งาน';
      case 'Leaves':
      case 'LeaveTypes':
      case 'FiscalRounds':
      case 'SpecialHolidays':
      case 'SpecialWorkingDays':
        return 'การลา';
      case 'Permissions':
      case 'MobilePermissions':
      case 'Roles':
      case 'AdminRoles':
        return 'สิทธิ์';
      default:
        return 'ข้อมูลพื้นฐาน';
    }
  }

  IconData _migrationTableIcon(String table) {
    switch (table) {
      case 'Teachers':
        return Icons.groups_rounded;
      case 'UserRoles':
        return Icons.manage_accounts_rounded;
      case 'Leaves':
        return Icons.assignment_rounded;
      case 'LoginLogs':
        return Icons.history_rounded;
      case 'Permissions':
      case 'MobilePermissions':
        return Icons.admin_panel_settings_rounded;
      case 'Roles':
      case 'AdminRoles':
        return Icons.badge_rounded;
      case 'LeaveTypes':
      case 'FiscalRounds':
        return Icons.event_note_rounded;
      default:
        return Icons.table_chart_rounded;
    }
  }

  Future<List<String>?> _selectMigrationCollections() async {
    final allCollections = MigrationService.allCollections;
    final selected = {
      for (final c in allCollections)
        c: !_migrationSelectionTouched ||
            _selectedMigrationCollections.contains(c)
    };

    final confirmed = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedCount = selected.values.where((v) => v).length;
          final allChecked = selectedCount == allCollections.length;
          final selectedCollections =
              MigrationService.collectionsFromSelection(selected);

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            backgroundColor: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screen = MediaQuery.of(context).size;
                final dialogWidth =
                    screen.width < 1120 ? screen.width - 48 : 1080.0;
                final dialogHeight =
                    screen.height < 720 ? screen.height - 48 : 640.0;

                return Container(
                  width: dialogWidth,
                  height: dialogHeight,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x330F172A),
                        blurRadius: 36,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.compare_arrows_rounded,
                                color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('นำเข้าข้อมูลบุคลากร',
                                    style: GoogleFonts.sarabun(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF0F172A))),
                                const SizedBox(height: 3),
                                Text(
                                  'เลือก table จาก Firebase เพื่อนำเข้า Supabase ตามลำดับ dependency อัตโนมัติ',
                                  style: GoogleFonts.sarabun(
                                      fontSize: 13,
                                      color: const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                                '$selectedCount/${allCollections.length} table',
                                style: GoogleFonts.sarabun(
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF2563EB))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F0F172A),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: allChecked,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (v) => setDialogState(() {
                                for (final c in allCollections) {
                                  selected[c] = v ?? false;
                                }
                              }),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('เลือกทั้งหมด',
                                  style: GoogleFonts.sarabun(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF0F172A))),
                            ),
                            Text(
                              selectedCollections.isEmpty
                                  ? 'ยังไม่ได้เลือก table'
                                  : 'ลำดับนำเข้า: ${selectedCollections.take(4).join(' → ')}${selectedCollections.length > 4 ? ' → ...' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sarabun(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: GridView.builder(
                          itemCount: allCollections.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 4.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemBuilder: (_, index) {
                            final table = allCollections[index];
                            final checked = selected[table] ?? false;
                            return InkWell(
                              key: ValueKey('migration-dialog-$table'),
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => setDialogState(
                                  () => selected[table] = !checked),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: checked
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: checked
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFFE2E8F0),
                                    width: checked ? 1.4 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: checked,
                                      activeColor: const Color(0xFF2563EB),
                                      onChanged: (v) => setDialogState(
                                          () => selected[table] = v ?? false),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: checked
                                            ? const Color(0xFFDBEAFE)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(_migrationTableIcon(table),
                                          size: 18,
                                          color: checked
                                              ? const Color(0xFF2563EB)
                                              : const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(table,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.sarabun(
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      const Color(0xFF0F172A))),
                                          const SizedBox(height: 2),
                                          Text(_migrationTableGroup(table),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.sarabun(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: selectedCount == 0
                                  ? null
                                  : () => _showMigrationSelectionSummary(
                                      selectedCollections),
                              icon: const Icon(Icons.schema_rounded),
                              label: Text('เปรียบเทียบที่เลือก',
                                  style: GoogleFonts.sarabun(
                                      fontWeight: FontWeight.w800)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                foregroundColor: const Color(0xFF1E3A8A),
                                side:
                                    const BorderSide(color: Color(0xFF94A3B8)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: selectedCount == 0
                                  ? null
                                  : () =>
                                      Navigator.pop(ctx, selectedCollections),
                              icon: const Icon(Icons.cloud_upload_rounded),
                              label: Text('นำเข้าที่เลือก ($selectedCount)',
                                  style: GoogleFonts.sarabun(
                                      fontWeight: FontWeight.w900)),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                elevation: 0,
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('ยกเลิก',
                                style: GoogleFonts.sarabun(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B))),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    return confirmed;
  }

  List<String> _migrationInfoLines(List<String> lines) {
    return lines.where((line) {
      final isError = line.contains(' Error:') ||
          line.contains('schema Error:') ||
          line.startsWith('⏸️ ') ||
          line.startsWith('❌ ');
      return !isError;
    }).toList();
  }

  Map<String, List<int>> _migrationImportedCounts(List<String> lines) {
    final result = <String, List<int>>{};
    final patterns = [
      RegExp(r'^[^A-Za-z]*([A-Za-z]+):\s*(\d+)\s*(?:→|->)\s*(\d+)\s+imported'),
      RegExp(
          r'^[^A-Za-z]*([A-Za-z]+):\s*(\d+)\s+documents\s*(?:→|->)\s*(\d+)\s+menu rows imported'),
      RegExp(
          r'^[^A-Za-z]*([A-Za-z]+):\s*(\d+)\s*(?:→|->)\s*(\d+)\s+menu rows imported'),
      RegExp(
          r'^[^A-Za-z]*([A-Za-z]+):\s*(\d+)\s*(?:→|->)\s*(\d+)\s+role rows imported'),
    ];
    for (final line in lines) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final total = int.tryParse(match[2]!) ?? 0;
          final imported = int.tryParse(match[3]!) ?? 0;
          result[match[1]!] = [imported, total];
          break;
        }
      }
    }
    return result;
  }

  Map<String, List<String>> _migrationErrorsByTable(List<String> lines) {
    final result = <String, List<String>>{};
    for (final line in lines) {
      final isError = line.contains(' Error:') ||
          line.contains('schema Error:') ||
          line.startsWith('⏸️ ') ||
          line.startsWith('❌ ');
      if (!isError) continue;
      final table = line
          .split(RegExp(r'[:/]'))
          .first
          .replaceAll('⏸️', '')
          .replaceAll('❌', '')
          .trim();
      result.putIfAbsent(table.isEmpty ? 'ระบบ' : table, () => []).add(line);
    }
    return result;
  }

  Widget _migrationPanel({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFFBFDFF),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.sarabun(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A))),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sarabun(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B))),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _migrationEmptyState({
    required IconData icon,
    required String title,
    required String detail,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(detail,
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(
                    fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _migrationInfoList(List<String> infoLines) {
    if (infoLines.isEmpty) {
      return _migrationEmptyState(
        icon: Icons.cloud_upload_outlined,
        title: 'ยังไม่มีข้อมูลนำเข้า',
        detail: 'รายละเอียดจะเพิ่มเข้ามาระหว่างการทำงาน',
        color: const Color(0xFF2563EB),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: infoLines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final line = infoLines[i];
        final isSuccess = line.contains('imported') || line.startsWith('✅');
        final isNote =
            line.startsWith('ℹ️') || line.contains('INSERT โดยไม่ส่ง PK');
        final color = isSuccess
            ? const Color(0xFF16A34A)
            : isNote
                ? const Color(0xFF2563EB)
                : const Color(0xFF64748B);
        final icon = isSuccess
            ? Icons.check_circle_rounded
            : isNote
                ? Icons.info_rounded
                : Icons.notes_rounded;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .16)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(line,
                    style: GoogleFonts.sarabun(
                        fontSize: 12.5,
                        height: 1.35,
                        color: const Color(0xFF334155))),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _migrationErrorList(Map<String, List<String>> errorsByTable) {
    if (errorsByTable.isEmpty) {
      return _migrationEmptyState(
        icon: Icons.verified_rounded,
        title: 'ยังไม่พบปัญหา',
        detail: 'ถ้ามีรายการค้าง จะถูกแยกตาม table ตรงนี้',
        color: const Color(0xFF16A34A),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: errorsByTable.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final entry = errorsByTable.entries.elementAt(index);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFECACA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.key,
                        style: GoogleFonts.sarabun(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF991B1B))),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${entry.value.length} รายการ',
                        style: GoogleFonts.sarabun(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF991B1B))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...entry.value.take(30).map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(color: Color(0xFFB91C1C))),
                        Expanded(
                          child: Text(line,
                              style: GoogleFonts.sarabun(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: const Color(0xFF7F1D1D))),
                        ),
                      ],
                    ),
                  )),
              if (entry.value.length > 30)
                Text('แสดง 30 รายการแรกจาก ${entry.value.length} รายการ',
                    style: GoogleFonts.sarabun(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB91C1C))),
            ],
          ),
        );
      },
    );
  }

  Widget _migrationCountList(Map<String, List<int>> counts) {
    if (counts.isEmpty) {
      return _migrationEmptyState(
        icon: Icons.table_rows_rounded,
        title: 'ยังไม่มี record สำเร็จ',
        detail: 'จำนวนสำเร็จของแต่ละ table จะแสดงที่นี่',
        color: const Color(0xFF16A34A),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: counts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final entry = counts.entries.elementAt(index);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.key,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sarabun(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF166534))),
              ),
              Text('${entry.value[0]}/${entry.value[1]}',
                  style: GoogleFonts.sarabun(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF15803D))),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMigrationProgressFromSelection(
      Iterable<String> selection) async {
    try {
      final all = MigrationService.allCollections;
      final selectedTables = selection.isEmpty ? all : selection;
      await _showMigrationProgressDialog(collections: selectedTables.toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เปิดหน้าต่างนำเข้าไม่สำเร็จ: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _clearImportTablesFromSelection(
      Iterable<String> selection) async {
    if (_isClearingImportTables) return;
    final all = MigrationService.allCollections;
    final selectedTables = selection.isEmpty ? all : selection;
    final orderedTables =
        MigrationService.orderedCollectionsForImport(selectedTables);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ล้างข้อมูลใน Supabase',
            style: GoogleFonts.sarabun(fontWeight: FontWeight.w900)),
        content: Text(
          'ต้องการล้างข้อมูล ${orderedTables.length} table ที่เลือกไว้หรือไม่? การล้างนี้จะใช้สิทธิ์ Supabase ของผู้ใช้ปัจจุบัน',
          style: GoogleFonts.sarabun(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('ยกเลิก', style: GoogleFonts.sarabun()),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: Text('ล้างข้อมูล',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isClearingImportTables = true);
    try {
      final cleared = await MigrationService.clearImportTables(
        collections: orderedTables,
        onLog: debugPrint,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleared.isEmpty
              ? 'ไม่พบตารางที่ล้างได้ หรือสิทธิ์ Supabase ไม่อนุญาต'
              : 'ล้างข้อมูลใน Supabase แล้ว ${cleared.length} table'),
          backgroundColor: cleared.isEmpty
              ? Colors.orange.shade700
              : const Color(0xFF15803D),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ล้างข้อมูลใน Supabase ไม่สำเร็จ: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isClearingImportTables = false);
    }
  }

  Future<void> _showMigrationProgressDialog({List<String>? collections}) async {
    final targetCollections = collections == null
        ? await _selectMigrationCollections()
        : MigrationService.orderedCollectionsForImport(
            List<String>.of(collections));
    if (targetCollections == null || targetCollections.isEmpty || !mounted)
      return;
    setState(() {
      _migrationSelectionTouched = true;
      _selectedMigrationCollections
        ..clear()
        ..addAll(targetCollections);
    });

    // สถานะความคืบหน้า (ใช้ ValueNotifier เพื่ออัปเดต UI ใน dialog แบบสด)
    final logs = ValueNotifier<List<String>>([
      'ลำดับนำเข้า: ${MigrationService.importOrderSummary(targetCollections)}',
      'ตารางที่เลือก: ${targetCollections.join(', ')}',
    ]);
    final progress = ValueNotifier<double?>(null); // null = indeterminate
    final currentStep = ValueNotifier<String>('กำลังเตรียมการ...');
    final finished = ValueNotifier<bool>(false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screen = MediaQuery.of(context).size;
            final dialogWidth =
                screen.width < 1220 ? screen.width - 48 : 1220.0;
            final dialogHeight =
                screen.height < 760 ? screen.height - 48 : 704.0;
            return Container(
              width: dialogWidth,
              height: dialogHeight,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FB),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330F172A),
                    blurRadius: 36,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: finished,
                        builder: (_, done, __) => Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: done
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            done
                                ? Icons.check_circle_rounded
                                : Icons.sync_rounded,
                            color: done
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable: finished,
                              builder: (_, done, __) => Text(
                                done
                                    ? 'นำเข้าเสร็จสิ้น'
                                    : 'กำลังนำเข้าข้อมูล...',
                                style: GoogleFonts.sarabun(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            ValueListenableBuilder<String>(
                              valueListenable: currentStep,
                              builder: (_, step, __) => Text(
                                step,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.sarabun(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ValueListenableBuilder<List<String>>(
                        valueListenable: logs,
                        builder: (_, lines, __) {
                          final counts = _migrationImportedCounts(lines);
                          final total =
                              counts.values.fold<int>(0, (a, b) => a + b[0]);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'สำเร็จ $total records',
                              style: GoogleFonts.sarabun(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ValueListenableBuilder<double?>(
                    valueListenable: progress,
                    builder: (_, value, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8B5CF6)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          value == null
                              ? 'กำลังเตรียมข้อมูล'
                              : '${(value * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.sarabun(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ValueListenableBuilder<List<String>>(
                      valueListenable: logs,
                      builder: (_, lines, __) {
                        final infoLines = _migrationInfoLines(lines);
                        final errorsByTable = _migrationErrorsByTable(lines);
                        final counts = _migrationImportedCounts(lines);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 34,
                              child: _migrationPanel(
                                title: 'ข้อมูลนำเข้า',
                                subtitle: 'ขั้นตอนและรายละเอียดที่ถูกนำเข้า',
                                icon: Icons.cloud_upload_rounded,
                                color: const Color(0xFF2563EB),
                                child: _migrationInfoList(infoLines),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 46,
                              child: _migrationPanel(
                                title: 'ตรวจสอบปัญหา',
                                subtitle: 'แยก error และรายการค้างตาม table',
                                icon: Icons.error_outline_rounded,
                                color: const Color(0xFFDC2626),
                                child: _migrationErrorList(errorsByTable),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 24,
                              child: _migrationPanel(
                                title: 'สำเร็จต่อ table',
                                subtitle: 'จำนวน record ที่นำเข้าได้',
                                icon: Icons.table_rows_rounded,
                                color: const Color(0xFF16A34A),
                                child: _migrationCountList(counts),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: finished,
                      builder: (_, done, __) => ElevatedButton.icon(
                        onPressed: done ? () => Navigator.pop(ctx) : null,
                        icon: const Icon(Icons.close_rounded),
                        label: Text(done ? 'ปิด' : 'กำลังทำงาน...',
                            style: GoogleFonts.sarabun(
                                fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(130, 46),
                          elevation: 0,
                          backgroundColor: done
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    // เริ่ม import พร้อมรายงานความคืบหน้าเข้า dialog
    try {
      int total = 0;
      const pageHandledTables = {
        'AppConfig',
        'Teachers',
        'UserRoles',
        'Permissions',
        'MobilePermissions',
        'Leaves',
        'LoginLogs',
      };

      for (var i = 0; i < targetCollections.length; i++) {
        final table = targetCollections[i];
        progress.value = i / targetCollections.length;
        currentStep.value =
            'กำลังนำเข้า: $table (${i + 1}/${targetCollections.length})';

        if (pageHandledTables.contains(table)) {
          total += await _importPageHandledMigrationTables(
            [table],
            onLog: (msg) => logs.value = [...logs.value, msg],
            onStep: (_, __, ___) {},
          );
        } else {
          total += await MigrationService.exportAndImportToSupabase(
            collections: [table],
            onLog: (msg) => logs.value = [...logs.value, msg],
            onStep: (_, __, current) {
              if (current.startsWith('ข้าม ')) {
                currentStep.value = current;
              }
            },
          );
        }

        progress.value = (i + 1) / targetCollections.length;
      }

      currentStep.value = total == 0
          ? 'ไม่มีรายการนำเข้าสำเร็จ — ตรวจเหตุผลในบันทึก'
          : 'นำเข้าสำเร็จ $total records';
    } catch (e) {
      logs.value = [...logs.value, '❌ Error: $e'];
      currentStep.value = 'เกิดข้อผิดพลาด';
      progress.value = 0;
    } finally {
      finished.value = true;
    }
  }

  Future<int> _importPageHandledMigrationTables(
    List<String> tables, {
    required void Function(String message) onLog,
    required void Function(int done, int total, String current) onStep,
  }) async {
    final db = FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'school',
    );
    final supabase = Supabase.instance.client;
    var imported = 0;

    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      onStep(i, tables.length, table);
      if (table == 'AppConfig') {
        imported += await _importAppConfigFromPage(db, supabase, onLog);
      } else if (table == 'Teachers') {
        imported += await _importTeachersFromPage(db, supabase, onLog);
      } else if (table == 'UserRoles') {
        imported += await _importUserRolesFromPage(db, supabase, onLog);
      } else if (table == 'Permissions') {
        imported += await _importPermissionsFromPage(db, supabase, onLog);
      } else if (table == 'MobilePermissions') {
        imported += await _importMobilePermissionsFromPage(db, supabase, onLog);
      } else if (table == 'Leaves') {
        imported += await _importLeavesFromPage(db, supabase, onLog);
      } else if (table == 'LoginLogs') {
        imported += await _importLoginLogsFromPage(db, supabase, onLog);
      }
      onStep(i + 1, tables.length, table);
    }
    return imported;
  }

  Future<int> _importAppConfigFromPage(
    FirebaseFirestore db,
    SupabaseClient supabase,
    void Function(String message) onLog,
  ) async {
    try {
      await supabase
          .from('appconfig')
          .select('ID_AppConfig,Description,"Key AppTitle",Value')
          .limit(0);
    } catch (e) {
      onLog('AppConfig: ตรวจ schema ไม่สำเร็จ: $e');
      return 0;
    }

    final snap = await db.collection('AppConfig').get();
    var success = 0;
    onLog('AppConfig -> appconfig: document fields -> key/value rows');

    for (final doc in snap.docs) {
      final data = doc.data();
      for (final entry in data.entries) {
        try {
          final key = '${doc.id}.${entry.key}';
          final value = entry.value is Map || entry.value is List
              ? jsonEncode(entry.value)
              : _toSupabaseValue(entry.value)?.toString();
          final record = <String, dynamic>{
            'Description': doc.id,
            'Key AppTitle': key,
            'Value': value,
          }..removeWhere((_, value) => value == null);

          final existing = await supabase
              .from('appconfig')
              .select('ID_AppConfig')
              .eq('"Key AppTitle"', key)
              .limit(1)
              .maybeSingle();
          if (existing == null) {
            await supabase.from('appconfig').insert(record);
          } else {
            await supabase
                .from('appconfig')
                .update(record)
                .eq('ID_AppConfig', existing['ID_AppConfig']);
          }
          success++;
        } catch (e) {
          onLog('AppConfig/${doc.id}.${entry.key} Error: $e');
        }
      }
    }

    onLog(
        'AppConfig: ${snap.docs.length} documents -> $success key/value rows imported');
    return success;
  }

  Future<int> _importTeachersFromPage(
    FirebaseFirestore db,
    SupabaseClient supabase,
    void Function(String message) onLog,
  ) async {
    try {
      await MigrationService.refreshTableColumns();
    } catch (e) {
      onLog('Teachers schema Error: $e');
      return 0;
    }

    final columns =
        MigrationService.importColumnsForCollection('Teachers')?.toSet() ??
            <String>{};
    if (columns.isEmpty) {
      onLog('Teachers schema Error: ไม่พบคอลัมน์ Teachers จาก Supabase');
      return 0;
    }

    final snap = await db.collection('Teachers').get();
    var success = 0;
    final missingFk = <String>{};
    onLog(
        'Teachers -> Teachers: แปลง text จาก Firebase เป็น FK id_* ก่อนนำเข้า');

    for (final doc in snap.docs) {
      final data = doc.data();
      try {
        final record = <String, dynamic>{};
        void put(String column, dynamic value) {
          if (!columns.contains(column) || value == null) return;
          if (value is String && value.trim().isEmpty) return;
          record[column] = _toSupabaseValue(value);
        }

        put('username', data['username']);
        put('password', data['password']);
        put('fullName', data['fullName'] ?? data['name']);
        put('name', data['name'] ?? data['fullName']);
        put('email', data['email']);
        put('firebase_uid', data['firebase_uid'] ?? doc.id);
        put('profileImage', data['profileImage']);
        put('created_at', data['created_at'] ?? data['createdAt']);
        put('updated_at', data['updated_at'] ?? data['updatedAt']);
        put('lastSyncAt', data['lastSyncAt']);

        final roleText = _teacherRoleForMigration(data);
        final idRole = await _tryResolveMasterIdForMigration(
          supabase,
          rawValue: roleText,
          tableName: 'roles',
          idColumn: 'ID_Roles',
          nameColumn: 'Accessrights',
          label: 'role',
          onLog: onLog,
        );
        put('id_role', idRole);

        final positionText = data['id_position'] ?? data['position'];
        final idPosition = await _tryResolveMasterIdForMigration(
          supabase,
          rawValue: positionText,
          tableName: 'positions',
          idColumn: 'ID_Positions',
          nameColumn: 'positionName',
          label: 'position',
          onLog: onLog,
        );
        put('id_position', idPosition);

        final departmentText = data['id_department'] ?? data['department'];
        final idDepartment = await _tryResolveMasterIdForMigration(
          supabase,
          rawValue: departmentText,
          tableName: 'departments',
          idColumn: 'ID_Departments',
          nameColumn: 'DepartmentsName',
          label: 'department',
          onLog: onLog,
        );
        put('id_department', idDepartment);

        final academicText =
            data['id_academic'] ?? data['academicStanding'] ?? data['rank'];
        final idAcademic = await _tryResolveMasterIdForMigration(
          supabase,
          rawValue: academicText,
          tableName: 'academics',
          idColumn: 'ID_Academics',
          nameColumn: 'AcademicsName',
          label: 'academic',
          onLog: onLog,
        );
        put('id_academic', idAcademic);
        put('id_academics', idAcademic);

        final adminRoleText = data['id_adminRole'] ??
            data['adminRole'] ??
            data['ตำแหน่งงานบริหาร'];
        final idAdminRole = await _tryResolveMasterIdForMigration(
          supabase,
          rawValue: adminRoleText,
          tableName: 'adminroles',
          idColumn: 'ID_AdminRoles',
          nameColumn: 'AdminRolesName',
          label: 'admin role',
          onLog: onLog,
        );
        put('id_adminRole', idAdminRole);
        put('id_adminrole', idAdminRole);
        put('id_adminroles', idAdminRole);
        put('id_permission', idRole);

        if (record.isEmpty) {
          throw const FormatException(
              'ไม่มีฟิลด์ Teachers ที่ตรงกับ Supabase schema');
        }

        await supabase.from('Teachers').insert(record);
        success++;
      } catch (e) {
        onLog('Teachers/${doc.id} Error: $e');
      }
    }

    if (missingFk.isNotEmpty) {
      onLog(
          'Teachers: พบคอลัมน์ ${missingFk.join(', ')} แต่ยังไม่ map เพราะต้องยืนยันว่าชี้ไป table/PK ใด');
    }
    onLog('Teachers: ${snap.docs.length} -> $success imported');
    return success;
  }

  Future<int> _importUserRolesFromPage(
    FirebaseFirestore db,
    SupabaseClient supabase,
    void Function(String message) onLog,
  ) async {
    final snap = await db.collection('UserRoles').get();
    var success = 0;
    onLog(
        'UserRoles -> UserRoles: Firebase Auth UID -> Teachers.id_user, role -> roles.ID_Roles -> UserRoles.id_role');

    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        // UserRoles document IDs are Auth UIDs. teacherDocId identifies a
        // Firestore Teachers document and must never be treated as an Auth UID.
        var teacher = await supabase
            .from('Teachers')
            .select('id_user')
            .eq('firebase_uid', doc.id)
            .maybeSingle();
        final teacherDocId = (data['teacherDocId'] ?? '').toString().trim();
        Map<String, dynamic>? sourceData;
        if (teacher == null && teacherDocId.isNotEmpty) {
          final source =
              await db.collection('Teachers').doc(teacherDocId).get();
          sourceData = source.data();
          final uid = (sourceData?['firebase_uid'] ?? '').toString().trim();
          if (uid.isNotEmpty && uid != doc.id) {
            teacher = await supabase
                .from('Teachers')
                .select('id_user')
                .eq('firebase_uid', uid)
                .maybeSingle();
          }
          // Teachers imported before their first login may have no Auth UID.
          // Only accept a unique username from the referenced source teacher.
          final username = (sourceData?['username'] ?? '').toString().trim();
          if (teacher == null && username.isNotEmpty) {
            teacher = await supabase
                .from('Teachers')
                .select('id_user')
                .eq('username', username)
                .maybeSingle();
          }
        }
        final fullNameCandidates = <String>{
          (sourceData?['fullName'] ?? '').toString().trim(),
          (sourceData?['name'] ?? '').toString().trim(),
          (data['fullName'] ?? '').toString().trim(),
          (data['name'] ?? '').toString().trim(),
        }..removeWhere((value) => value.isEmpty);
        for (final fullName in fullNameCandidates) {
          if (teacher != null) break;
          teacher = await supabase
              .from('Teachers')
              .select('id_user')
              .eq('fullName', fullName)
              .maybeSingle();
        }
        final idUser = teacher?['id_user'];
        if (idUser == null) {
          final triedNames = fullNameCandidates.isEmpty
              ? ''
              : ' (ลองค้นชื่อ: ${fullNameCandidates.join(', ')})';
          throw FormatException(
              'ไม่พบครูใน Supabase สำหรับ UserRoles/${doc.id}$triedNames; กรุณานำเข้า Teachers ก่อน');
        }

        final rawRole = data['id_role'] ?? data['role'] ?? data['permission'];
        if (rawRole == null) {
          throw const FormatException('ไม่พบ role/id_role');
        }
        final idRole = await _resolveRoleIdForMigration(supabase, rawRole);
        final record = <String, dynamic>{
          'id_user': idUser,
          'id_role': idRole,
        };
        final lastSyncAt = _toSupabaseValue(data['lastSyncAt']);
        if (lastSyncAt != null) record['lastSyncAt'] = lastSyncAt;

        final existing = await supabase
            .from('UserRoles')
            .select('id_UserRole')
            .eq('id_user', idUser)
            .eq('id_role', idRole)
            .maybeSingle();
        if (existing == null) {
          await supabase.from('UserRoles').insert(record);
        } else {
          await supabase
              .from('UserRoles')
              .update(record)
              .eq('id_UserRole', existing['id_UserRole']);
        }
        success++;
      } catch (e) {
        onLog('UserRoles/${doc.id} Error: $e');
      }
    }

    onLog('UserRoles: ${snap.docs.length} -> $success imported');
    return success;
  }

  Future<int> _importPermissionsFromPage(
    FirebaseFirestore db,
    SupabaseClient supabase,
    void Function(String message) onLog,
  ) async {
    try {
      await supabase
          .from('Permissions')
          .select('id_role,menu_id,status,updatedAt')
          .limit(0);
    } catch (e) {
      onLog(
          'Permissions: ตารางนี้ต้องมีคอลัมน์ id_role, menu_id, status เพื่อเก็บสิทธิ์เมนู 0–8 ให้เท่ากับ Firebase');
      onLog(
          'Permissions: ให้รัน supabase/permissions_menu_id.sql ใน Supabase SQL Editor ก่อนนำเข้าใหม่');
      onLog('Permissions schema Error: $e');
      return 0;
    }

    final snap = await db.collection('Permissions').get();
    var success = 0;
    onLog('Permissions: สิทธิ์แต่ละเมนู -> (id_role, menu_id, status)');

    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        final rawRole =
            data['id_role'] ?? data['role'] ?? data['Role'] ?? doc.id;
        final idRole = await _resolveRoleIdForMigration(supabase, rawRole);
        final records = MobilePermissionMigration.records(
          data,
          idRole,
          aliases: MobilePermissionMigration.pcMenuAliases,
        );
        final updatedAt = _toSupabaseValue(data['updatedAt']);
        for (final record in records) {
          if (updatedAt != null) record['updatedAt'] = updatedAt;
        }
        await supabase
            .from('Permissions')
            .upsert(records, onConflict: 'id_role,menu_id');
        success += records.length;
      } catch (e) {
        onLog('Permissions/${doc.id} Error: $e');
      }
    }

    onLog(
        'Permissions: ${snap.docs.length} documents -> $success menu rows imported');
    return success;
  }

  Future<int> _importMobilePermissionsFromPage(
    FirebaseFirestore db,
    SupabaseClient supabase,
    void Function(String message) onLog,
  ) async {
    try {
      await supabase
          .from('MobilePermissions')
          .select('id_role,menu_id,status,updatedAt')
          .limit(0);
    } catch (e) {
      onLog(
          'MobilePermissions: ตารางนี้ต้องมีคอลัมน์ menu_id ก่อน เพื่อเก็บสิทธิ์เมนู -1 และ 0–8 ให้เท่ากับ Firebase');
      onLog(
          'MobilePermissions: ให้รัน supabase/mobile_permissions_menu_id.sql ใน Supabase SQL Editor แล้วลบข้อมูล MobilePermissions เดิม 3 แถวก่อนนำเข้าใหม่');
      onLog('MobilePermissions schema Error: $e');
      return 0;
    }

    final snap = await db.collection('MobilePermissions').get();
    var success = 0;
    onLog('MobilePermissions: สิทธิ์แต่ละเมนู -> (id_role, menu_id, status)');

    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        final rawRole =
            data['id_role'] ?? data['role'] ?? data['Role'] ?? doc.id;
        final idRole = await _resolveRoleIdForMigration(supabase, rawRole);
        final records = MobilePermissionMigration.records(data, idRole);
        final updatedAt = _toSupabaseValue(data['updatedAt']);
        for (final record in records) {
          if (updatedAt != null) record['updatedAt'] = updatedAt;
        }
        await supabase
            .from('MobilePermissions')
            .upsert(records, onConflict: 'id_role,menu_id');
        success += records.length;
      } catch (e) {
        onLog('MobilePermissions/${doc.id} Error: $e');
      }
    }

    onLog(
        'MobilePermissions: ${snap.docs.length} documents -> $success menu rows imported');
    return success;
  }

  Future<int> _importLoginLogsFromPage(
    FirebaseFirestore db,
    SupabaseClient supabase,
    void Function(String message) onLog,
  ) async {
    try {
      await supabase
          .from('LoginLogs')
          .select('id_LoginLogs,id_user,timestamp,platform,userAgent')
          .limit(0);
    } catch (e) {
      onLog('LoginLogs: ตรวจ schema ไม่สำเร็จ: $e');
      return 0;
    }

    final snap = await db.collection('LoginLogs').get();
    var success = 0;
    onLog('LoginLogs -> LoginLogs: uid/username/fullName -> Teachers.id_user');

    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        final idUser = await _resolveTeacherIdForMigration(
          db,
          supabase,
          uid: data['uid']?.toString(),
          teacherDocId: data['teacherDocId']?.toString(),
          username: data['username']?.toString(),
          fullName: (data['fullName'] ?? data['name'])?.toString(),
        );

        if (idUser == null) {
          onLog('LoginLogs/: นำเข้าโดยไม่ผูก user เพราะไม่พบ Teachers.id_user');
        }

        final timestamp = _toSupabaseValue(data['timestamp']);
        final record = <String, dynamic>{
          if (idUser != null) 'id_user': idUser,
          'timestamp': timestamp,
          'platform': data['platform']?.toString(),
          'userAgent': data['userAgent']?.toString(),
        }..removeWhere((_, value) => value == null);

        var existingQuery = supabase
            .from('LoginLogs')
            .select('id_LoginLogs')
            .eq('id_user', idUser ?? -1);
        if (timestamp != null)
          existingQuery = existingQuery.eq('timestamp', timestamp);
        final platform = record['platform'];
        if (platform != null)
          existingQuery = existingQuery.eq('platform', platform);
        final existing = await existingQuery.limit(1).maybeSingle();
        if (existing == null) {
          await supabase.from('LoginLogs').insert(record);
        } else {
          await supabase
              .from('LoginLogs')
              .update(record)
              .eq('id_LoginLogs', existing['id_LoginLogs']);
        }
        success++;
      } catch (e) {
        onLog('LoginLogs/${doc.id} Error: $e');
      }
    }

    onLog('LoginLogs: ${snap.docs.length} -> $success imported');
    return success;
  }

  Future<int> _importLeavesFromPage(
    FirebaseFirestore db,
    SupabaseClient supabase,
    void Function(String message) onLog,
  ) async {
    try {
      await supabase
          .from('Leaves')
          .select(
              'id_leaves,id_user,timestamp,status,lastUpdatedAt,leaveDate,id_leaveType,reason,startDate,endDate,totalDays,id_year,receiveNumber,medicalCertificate')
          .limit(0);
    } catch (e) {
      onLog('Leaves: ตรวจ schema ไม่สำเร็จ: $e');
      return 0;
    }

    final snap = await db.collection('Leaves').get();
    var success = 0;
    onLog(
        'Leaves -> Leaves: uid/fullName -> Teachers.id_user, leaveType -> LeaveTypes.id_leaveType, date -> FiscalRounds.id_year');

    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        final idUser = await _resolveTeacherIdForMigration(
          db,
          supabase,
          uid: data['uid']?.toString(),
          teacherDocId: data['teacherDocId']?.toString(),
          username: data['username']?.toString(),
          fullName: (data['fullName'] ?? data['name'])?.toString(),
        );
        if (idUser == null) {
          throw FormatException(
              'ไม่พบ Teachers.id_user จาก uid/fullName ของ Leaves/${doc.id}');
        }

        final rawLeaveType = data['id_leaveType'] ?? data['leaveType'];
        if (rawLeaveType == null) {
          throw const FormatException('ไม่พบ leaveType/id_leaveType');
        }
        final idLeaveType = await _resolveLeaveTypeIdForMigration(
          supabase,
          rawLeaveType,
        );

        final leaveDate = _dateForMigration(
          data['leaveDate'] ?? data['startDate'] ?? data['timestamp'],
        );
        final startDate = _dateForMigration(data['startDate'] ?? leaveDate);
        final endDate = _dateForMigration(data['endDate'] ?? startDate);
        final idYear = await _resolveFiscalRoundIdForMigration(
          supabase,
          data,
          startDate ?? leaveDate,
        );

        final record = <String, dynamic>{
          'id_user': idUser,
          'timestamp': _toSupabaseValue(data['timestamp']),
          'status': data['status']?.toString(),
          'lastUpdatedAt': _toSupabaseValue(data['lastUpdatedAt']),
          'leaveDate': leaveDate,
          'id_leaveType': idLeaveType,
          'reason': data['reason']?.toString(),
          'startDate': startDate,
          'endDate': endDate,
          'totalDays': _numericForMigration(data['totalDays']),
          'id_year': idYear,
          'receiveNumber': data['receiveNumber']?.toString(),
          'medicalCertificate': data['medicalCertificate']?.toString(),
        }..removeWhere((_, value) => value == null);

        var existingQuery = supabase
            .from('Leaves')
            .select('id_leaves')
            .eq('id_user', idUser)
            .eq('id_leaveType', idLeaveType);
        if (startDate != null)
          existingQuery = existingQuery.eq('startDate', startDate);
        if (endDate != null)
          existingQuery = existingQuery.eq('endDate', endDate);
        final reason = record['reason'];
        if (reason != null) existingQuery = existingQuery.eq('reason', reason);
        final existing = await existingQuery.limit(1).maybeSingle();
        if (existing == null) {
          await supabase.from('Leaves').insert(record);
        } else {
          await supabase
              .from('Leaves')
              .update(record)
              .eq('id_leaves', existing['id_leaves']);
        }
        success++;
      } catch (e) {
        onLog('Leaves/${doc.id} Error: $e');
      }
    }

    onLog('Leaves: ${snap.docs.length} -> $success imported');
    return success;
  }

  dynamic _teacherRoleForMigration(Map<String, dynamic> data) {
    final direct = data['id_role'];
    if (direct != null && direct.toString().trim().isNotEmpty) return direct;

    for (final key in [
      'role',
      'permission',
      'Role',
      'Permission',
      'สิทธิ์การเข้าถึง',
      'สิทธิ์',
    ]) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != '---เลือก---') {
        return _canonicalRoleNameForMigration(value);
      }
    }

    final fullName = (data['fullName'] ?? data['name'] ?? '').toString();
    final username = (data['username'] ?? '').toString().toLowerCase();
    final adminRole =
        (data['ตำแหน่งงานบริหาร'] ?? data['adminRole'] ?? '').toString().trim();

    if (fullName.contains('ผู้ดูแลระบบ') || username.contains('admin')) {
      return 'ผู้ดูแลระบบ';
    }
    if (adminRole.isNotEmpty && adminRole != 'ไม่มีตำแหน่งบริหาร') {
      return 'ผู้บริหาร';
    }
    return 'ครู';
  }

  String _canonicalRoleNameForMigration(String value) {
    final normalized = _normalizeFkTextForMigration(value);
    if (normalized.contains('admin') || normalized.contains('ผู้ดูแล')) {
      return 'ผู้ดูแลระบบ';
    }
    if (normalized.contains('manager') ||
        normalized.contains('director') ||
        normalized.contains('บริหาร') ||
        normalized.contains('ผู้อำนวยการ')) {
      return 'ผู้บริหาร';
    }
    if (normalized.contains('teacher') || normalized.contains('ครู')) {
      return 'ครู';
    }
    return value.trim();
  }

  Future<int?> _tryResolveMasterIdForMigration(
    SupabaseClient supabase, {
    required dynamic rawValue,
    required String tableName,
    required String idColumn,
    required String nameColumn,
    required String label,
    required void Function(String message) onLog,
  }) async {
    if (rawValue == null) return null;
    if (rawValue is int) return rawValue;
    final rawText = rawValue.toString().trim();
    if (rawText.isEmpty || rawText == '---เลือก---' || rawText == '-') {
      return null;
    }
    final direct = int.tryParse(rawText);
    if (direct != null) return direct;

    final normalized = _normalizeFkTextForMigration(rawText);
    try {
      final rows = await supabase
          .from(tableName)
          .select(_selectColumnsForMigration([idColumn, nameColumn]));
      for (final row in rows) {
        final name = (row[nameColumn] ?? '').toString().trim();
        if (_normalizeFkTextForMigration(name) == normalized) {
          final value = row[idColumn];
          return value is int ? value : int.tryParse(value?.toString() ?? '');
        }
      }
      onLog('Teachers: ไม่พบ $label ใน $tableName.$nameColumn = $rawText');
      return null;
    } catch (e) {
      onLog('Teachers: resolve $label ไม่สำเร็จ: $e');
      return null;
    }
  }

  String _selectColumnsForMigration(List<String> columns) {
    return columns.map((column) {
      final needsQuotes = RegExp(r'[^A-Za-z0-9_]').hasMatch(column);
      return needsQuotes ? '"$column"' : column;
    }).join(',');
  }

  String _normalizeFkTextForMigration(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim().toLowerCase();
  }

  Future<int?> _resolveTeacherIdForMigration(
    FirebaseFirestore db,
    SupabaseClient supabase, {
    String? uid,
    String? teacherDocId,
    String? username,
    String? fullName,
  }) async {
    Future<int?> idFrom(String column, String? value) async {
      final text = value?.trim();
      if (text == null || text.isEmpty) return null;
      // 1) exact match ก่อน (เร็วและตรงที่สุด)
      var teacher = await supabase
          .from('Teachers')
          .select('id_user')
          .eq(column, text)
          .maybeSingle();
      // 2) fallback: เทียบแบบไม่สนตัวพิมพ์เล็ก-ใหญ่ (escape ตัว wildcard ของ ilike)
      if (teacher == null) {
        final escaped = text
            .replaceAll('\\', '\\\\')
            .replaceAll('%', '\\%')
            .replaceAll('_', '\\_');
        teacher = await supabase
            .from('Teachers')
            .select('id_user')
            .ilike(column, escaped)
            .limit(1)
            .maybeSingle();
      }
      final raw = teacher?['id_user'];
      return raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    }

    final directUid = await idFrom('firebase_uid', uid);
    if (directUid != null) return directUid;

    final docId = teacherDocId?.trim();
    if (docId != null && docId.isNotEmpty) {
      final source = await db.collection('Teachers').doc(docId).get();
      final sourceData = source.data();
      final sourceUid =
          await idFrom('firebase_uid', sourceData?['firebase_uid']?.toString());
      if (sourceUid != null) return sourceUid;
      final sourceUsername =
          await idFrom('username', sourceData?['username']?.toString());
      if (sourceUsername != null) return sourceUsername;
      final sourceFullName = await idFrom('fullName',
          (sourceData?['fullName'] ?? sourceData?['name'])?.toString());
      if (sourceFullName != null) return sourceFullName;
    }

    final byUsername = await idFrom('username', username);
    if (byUsername != null) return byUsername;
    return idFrom('fullName', fullName);
  }

  Future<int> _resolveLeaveTypeIdForMigration(
    SupabaseClient supabase,
    dynamic rawLeaveType,
  ) async {
    final direct = rawLeaveType is int
        ? rawLeaveType
        : int.tryParse(rawLeaveType.toString());
    if (direct != null) return direct;

    final name = rawLeaveType.toString().trim();
    if (name.isEmpty) throw const FormatException('ไม่พบ leaveType');
    final rows =
        await supabase.from('LeaveTypes').select('id_leaveType,leaveName');
    Map<String, dynamic>? row;
    for (final candidate in rows) {
      final leaveName = (candidate['leaveName'] ?? '').toString().trim();
      if (_sameLeaveTypeForMigration(name, leaveName)) {
        row = Map<String, dynamic>.from(candidate);
        break;
      }
    }
    if (row == null) throw FormatException('ไม่พบ LeaveTypes.leaveName=$name');
    final value = row['id_leaveType'];
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (parsed == null)
      throw FormatException('LeaveTypes.id_leaveType ไม่ใช่ตัวเลข: $name');
    return parsed;
  }

  bool _sameLeaveTypeForMigration(String source, String target) {
    final a = _normalizeLeaveTypeForMigration(source);
    final b = _normalizeLeaveTypeForMigration(target);
    if (a == b) return true;
    return a.contains(b) || b.contains(a);
  }

  String _normalizeLeaveTypeForMigration(String value) {
    final text = value
        .replaceAll(' ', '')
        .replaceAll('ประเภท', '')
        .replaceAll('การ', '')
        .replaceAll('ขอ', '')
        .replaceAll('ส่วนตัว', '')
        .trim();
    if (text.contains('ป่วย')) return 'ลาป่วย';
    if (text.contains('กิจ')) return 'ลากิจ';
    if (text.contains('คลอด')) return 'ลาคลอด';
    if (text.contains('พัก')) return 'ลาพักผ่อน';
    return text;
  }

  Future<int?> _resolveFiscalRoundIdForMigration(
    SupabaseClient supabase,
    Map<String, dynamic> data,
    String? dateText,
  ) async {
    final direct = data['id_year'] is int
        ? data['id_year'] as int
        : int.tryParse(data['id_year']?.toString() ?? '');
    if (direct != null) return direct;

    final rows = await supabase
        .from('FiscalRounds')
        .select('id_year,year,round,startDate,endDate');
    final targetDate = DateTime.tryParse(dateText ?? '');
    final rawYear = data['year'] ?? data['fiscalYear'];
    final targetYear =
        rawYear is int ? rawYear : int.tryParse(rawYear?.toString() ?? '');
    final rawRound = data['round'];
    final targetRound =
        rawRound is int ? rawRound : int.tryParse(rawRound?.toString() ?? '');

    for (final row in rows) {
      final start = DateTime.tryParse(row['startDate']?.toString() ?? '');
      final end = DateTime.tryParse(row['endDate']?.toString() ?? '');
      if (targetDate != null && start != null && end != null) {
        final inRange = !targetDate.isBefore(start) && !targetDate.isAfter(end);
        if (inRange) return _intValue(row['id_year']);
      }
      final rowYear = _intValue(row['year']);
      final rowRound = _intValue(row['round']);
      if (targetYear != null &&
          rowYear == targetYear &&
          (targetRound == null || rowRound == targetRound)) {
        return _intValue(row['id_year']);
      }
    }
    return null;
  }

  int? _intValue(dynamic value) {
    return value is int ? value : int.tryParse(value?.toString() ?? '');
  }

  num? _numericForMigration(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  String? _dateForMigration(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return _dateForMigration(value.toDate());
    if (value is DateTime) {
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
    if (slash != null) {
      final day = int.parse(slash[1]!);
      final month = int.parse(slash[2]!);
      final storedYear = int.parse(slash[3]!);
      final year = storedYear > 2400 ? storedYear - 543 : storedYear;
      final parsed = DateTime(year, month, day);
      if (parsed.year == year && parsed.month == month && parsed.day == day) {
        return _dateForMigration(parsed);
      }
      throw FormatException('วันที่ไม่ถูกต้อง: $text');
    }
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return _dateForMigration(parsed);
    throw FormatException('รูปแบบวันที่ไม่รองรับ: $text');
  }

  Future<int> _resolveRoleIdForMigration(
    SupabaseClient supabase,
    dynamic rawRole,
  ) async {
    final direct = rawRole is int ? rawRole : int.tryParse(rawRole.toString());
    if (direct != null) return direct;

    final roleName = rawRole.toString().trim();
    if (roleName.isEmpty) throw FormatException('ไม่พบ role/id_role');

    final role = await supabase
        .from('roles')
        .select('ID_Roles')
        .eq('Accessrights', roleName)
        .maybeSingle();
    if (role == null) {
      throw FormatException('ไม่พบ roles.Accessrights=$roleName');
    }

    for (final key in ['id_role', 'id', 'ID_Roles', 'id_Roles']) {
      final value = role[key];
      final parsed =
          value is int ? value : int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    throw FormatException('ไม่พบคอลัมน์ id ของ role: $roleName');
  }

  dynamic _toSupabaseValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return value;
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
                  if (_currentTab == 5) const CalendarSettingsTab(tabIndex: 0),
                  if (_currentTab == 6) const CalendarSettingsTab(tabIndex: 1),
                  if (_currentTab == 7) const CalendarSettingsTab(tabIndex: 2),
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
            color: isActive ? color.withValues(alpha: 0.1) : Colors.white,
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

  int _toIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<int> _nextMasterNumericId(
    String collection,
    String idField,
  ) async {
    final snapshot = await _firebaseService.db.collection(collection).get();
    var maxId = 0;
    for (final doc in snapshot.docs) {
      final dataId = _toIntValue(doc.data()[idField]);
      final docId = _toIntValue(doc.id);
      final current = dataId > docId ? dataId : docId;
      if (current > maxId) maxId = current;
    }
    return maxId + 1;
  }

  (String, String) _supabaseTableAndNameField(String collection) {
    switch (collection.toLowerCase()) {
      case 'positions':
        return ('positions', 'positionname');
      case 'academics':
        return ('academics', 'academicname');
      case 'departments':
        return ('departments', 'departmentname');
      case 'roles':
        return ('roles', 'Accessrights');
      case 'adminroles':
        return ('adminroles', 'adminrolename');
      case 'leavetypes':
        return ('LeaveTypes', 'value');
      default:
        return (collection, 'Value');
    }
  }

  Future<void> _createMasterItem(
    String collection,
    String value,
  ) async {
    // 🚀 เพิ่มรายการใน Supabase เท่านั้น — ห้ามแตะ Firebase
    final pair = _supabaseTableAndNameField(collection);
    final table = pair.$1;
    final nameField = pair.$2;
    final idField = _masterIdFieldForCollection(collection);

    try {
      final client = _firebaseService.supabaseClient;
      if (client != null) {
        if (idField.isNotEmpty) {
          final nextId = await _nextMasterNumericId(collection, idField);
          await client.from(table).insert({
            idField: nextId,
            nameField: value,
          });
        } else {
          await client.from(table).insert({
            nameField: value,
          });
        }
      }
    } catch (e) {
      debugPrint('Supabase _createMasterItem error: $e');
    }
  }

  Future<int> _migrateMasterToNumericSchema(String collectionName) async {
    // 🛡️ ปิดการเขียน Firebase ถาวรตามนโยบายความปลอดภัย
    return 0;
  }

  Future<void> _renameMasterItem(String oldValue, String newValue) async {
    final collection = _masterCollectionForCurrentTab();
    if (collection.isEmpty) return;

    // 🚀 อัปเดตชื่อใน Supabase เท่านั้น — ห้ามแตะ Firebase
    final pair = _supabaseTableAndNameField(collection);
    final table = pair.$1;
    final nameField = pair.$2;

    try {
      final client = _firebaseService.supabaseClient;
      if (client != null) {
        await client.from(table).update({nameField: newValue}).eq(nameField, oldValue);
      }
    } catch (e) {
      debugPrint('Supabase _renameMasterItem error: $e');
    }

    await _loadDropdownData();
  }

  Future<void> _deleteMasterItem(String value) async {
    final collection = _masterCollectionForCurrentTab();
    if (collection.isEmpty) return;

    // 🚀 ลบออกจาก Supabase เท่านั้น — ห้ามแตะ Firebase
    final pair = _supabaseTableAndNameField(collection);
    final table = pair.$1;
    final nameField = pair.$2;

    try {
      final client = _firebaseService.supabaseClient;
      if (client != null) {
        await client.from(table).delete().eq(nameField, value);
      }
    } catch (e) {
      debugPrint('Supabase _deleteMasterItem error: $e');
    }

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
    final masterCollection = _masterCollectionForCurrentTab();
    final usesNumericSchema =
        _masterIdFieldForCollection(masterCollection).isNotEmpty;
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
                      color: color.withValues(alpha: 0.1),
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
                if (usesNumericSchema) ...[
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('กำลังอัปเดตข้อมูลเดิม...'),
                            duration: Duration(seconds: 1),
                          ),
                        );

                        final updated = await _migrateMasterToNumericSchema(
                            masterCollection);

                        if (mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'อัปเดตข้อมูลเรียบร้อย $updated รายการ',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('อัปเดตข้อมูลไม่สำเร็จ: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('อัปเดตข้อมูล'),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      textStyle: GoogleFonts.sarabun(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
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
                            final orderKey =
                                _masterOrderKey(masterCollection, item);
                            final displayOrder = usesNumericSchema
                                ? (_masterOrderByKey[orderKey]?.toString() ??
                                    '${index + 1}')
                                : '${index + 1}';
                            return DataRow(
                              color: WidgetStateProperty.resolveWith((states) {
                                return index.isEven
                                    ? Colors.white
                                    : const Color(0xFFFAFBFC);
                              }),
                              cells: [
                                DataCell(Text(displayOrder)),
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
                                      color:
                                          Colors.green.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: Colors.green
                                              .withValues(alpha: 0.16)),
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

                    if (masterCollection.isEmpty) return;

                    try {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('กำลังบันทึกข้อมูลลงฐานข้อมูล...'),
                        duration: Duration(seconds: 1),
                      ));

                      await _createMasterItem(masterCollection, val);

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
                      color: Colors.black.withValues(alpha: 0.04),
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
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _firebaseService.getAllPermissionDocsFromSupabase(
            _permissionCollectionName),
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
            for (var doc in snapshot.data!) {
              final id = doc['id']?.toString() ?? '';
              if (id.isNotEmpty) rolePerms[id] = doc;
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
                          }

                          // 🚀 บันทึกสิทธิ์ลง Supabase เท่านั้น — ห้ามเขียน Firebase
                          final client = _firebaseService.supabaseClient;
                          if (client != null) {
                            try {
                              await client
                                  .from(_permissionCollectionName)
                                  .upsert({
                                'id': role,
                                ...newData,
                                'updatedat': DateTime.now().toIso8601String(),
                              });
                            } catch (e) {
                              debugPrint('Supabase permission save error: $e');
                            }
                          }
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
                                          // 🚀 อัปเดตสิทธิ์ลง Supabase เท่านั้น — ห้ามเขียน Firebase
                                          final client = _firebaseService.supabaseClient;
                                          if (client != null) {
                                            try {
                                              await client
                                                  .from(_permissionCollectionName)
                                                  .upsert({
                                                'id': role,
                                                pageId: val,
                                                'updatedat': DateTime.now().toIso8601String(),
                                              });
                                            } catch (e) {
                                              debugPrint('Supabase permission toggle error: $e');
                                            }
                                          }
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
                          color: Colors.blue.withValues(alpha: 0.3),
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

        // 🔄 ปุ่มเดียวจบ: Export จาก Firebase → Import เข้า Supabase พร้อม popup แสดงความคืบหน้า
        ElevatedButton.icon(
          onPressed: _showMigrationProgressDialog,
          icon: const Icon(Icons.cloud_sync_rounded),
          label: Text('Export to Supabase',
              style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        // Segmented Tabs (Glassmorphism style)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4)
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
                color: Colors.black.withValues(alpha: 0.03),
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
                              color: Colors.black.withValues(alpha: 0.05),
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
                color: Colors.black.withValues(alpha: 0.03),
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
            color: Colors.red.withValues(alpha: 0.3),
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
                Text('จำนวน $count รายการ กรุณากดรีเซ็ตรหัสผ่านเพื่อจัดการครับ',
                    style: GoogleFonts.sarabun(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11)),
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

  bool _isClearing = false;

  Widget _buildSyncTab(bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSyncHeader(),
        const SizedBox(height: 12),
        _buildMigrationSelectionCard(isWide),
        const SizedBox(height: 32),
        _buildClearReceiveNumberCard(),
      ],
    );
  }

  Widget _buildMigrationSelectionCard(bool isWide) {
    final all = MigrationService.allCollections;
    final displayTables = all;
    final effectiveSelected = _migrationSelectionTouched
        ? _selectedMigrationCollections
        : all.toSet();
    final count = effectiveSelected.length;
    final allChecked = count == all.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('เปรียบเทียบ Firebase กับ Supabase ก่อนนำเข้า',
                        style: GoogleFonts.sarabun(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('เลือก table เดียวหรือหลาย table ด้วย checkbox',
                        style: GoogleFonts.sarabun(
                            fontSize: 12.5, color: const Color(0xFF64748B))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Text('$count/${all.length} table',
                    style: GoogleFonts.sarabun(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: allChecked,
                  activeColor: const Color(0xFF3B5F96),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() {
                    _migrationSelectionTouched = true;
                    _selectedMigrationCollections.clear();
                    if (v == true) {
                      _selectedMigrationCollections.addAll(all);
                    }
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Text('เลือกทั้งหมด',
                  style: GoogleFonts.sarabun(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayTables.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWide ? 3 : 1,
              childAspectRatio: isWide ? 9.2 : 10.5,
              crossAxisSpacing: 96,
              mainAxisSpacing: 22,
            ),
            itemBuilder: (_, i) {
              final table = displayTables[i];
              final checked = effectiveSelected.contains(table);
              return InkWell(
                key: ValueKey('migration-card-$table'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() {
                  if (!_migrationSelectionTouched) {
                    _migrationSelectionTouched = true;
                    _selectedMigrationCollections.addAll(all);
                  }
                  if (_selectedMigrationCollections.contains(table)) {
                    _selectedMigrationCollections.remove(table);
                  } else {
                    _selectedMigrationCollections.add(table);
                  }
                }),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: checked,
                        activeColor: const Color(0xFF3B5F96),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) => setState(() {
                          if (!_migrationSelectionTouched) {
                            _migrationSelectionTouched = true;
                            _selectedMigrationCollections.addAll(all);
                          }
                          if (v == true) {
                            _selectedMigrationCollections.add(table);
                          } else {
                            _selectedMigrationCollections.remove(table);
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      key: ValueKey('migration-order-badge-$table'),
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${i + 1}',
                          style: GoogleFonts.sarabun(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF2563EB))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(table,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sarabun(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF4B5563))),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: count == 0 || _isClearingImportTables
                      ? null
                      : () =>
                          _clearImportTablesFromSelection(effectiveSelected),
                  icon: _isClearingImportTables
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep_rounded, size: 16),
                  label: Text(
                      _isClearingImportTables ? 'กำลังล้าง...' : 'ล้างข้อมูล',
                      style: GoogleFonts.sarabun(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(34),
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: count == 0
                      ? null
                      : () => _showMigrationSelectionSummary(
                          MigrationService.orderedCollectionsForImport(
                              effectiveSelected)),
                  icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                  label: Text('เปรียบเทียบที่เลือก',
                      style: GoogleFonts.sarabun(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(34),
                    foregroundColor: const Color(0xFF3B5F96),
                    side: const BorderSide(color: Color(0xFF9CA3AF)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: count == 0
                      ? null
                      : () => _openMigrationProgressFromSelection(
                          effectiveSelected),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: Text('นำเข้าที่เลือก ($count)',
                      style: GoogleFonts.sarabun(
                          fontSize: 13, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(34),
                    elevation: 0,
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _firebaseFieldsForMigration(String name) {
    const reviewedFields = <String, List<String>>{
      'SpecialWorkingDays': [
        'date',
        'dateValue',
        'title',
        'note',
        'createdAt',
        'updatedAt',
      ],
      'Settings': [
        'appsScriptUrl',
        'driveLeaveFolderId',
        'driveProfileFolderId',
        'secretKey',
        'adminPositions',
        'departments',
        'positions',
        'channelToken',
        'groupId',
        'template',
        'updatedAt',
        'webhookUrl',
        'lastNumber',
        'year',
      ],
      'Roles': ['createdAt', 'updatedAt', 'สิทธิ์การเข้าถึง / Value'],
      'LeaveTypes': ['ประเภทการลา / Value', 'createdAt', 'updatedAt'],
      'Permissions': ['0', '1', '2', '3', '4', '5', '6', '7', '8', 'updatedAt'],
      'MobilePermissions': ['id_role', 'status', 'updatedAt'],
      'Academics': ['createdAt', 'updatedAt', 'วิทยฐานะ / Value'],
      'AdminRoles': ['createdAt', 'updatedAt', 'ตำแหน่งบริหาร / Value'],
      'AppConfig': ['รอตรวจชื่อฟิลด์จาก Firebase'],
      'Departments': ['createdAt', 'updatedAt', 'แผนก_กลุ่มสาระ / Value'],
      'Positions': ['createdAt', 'ตำแหน่ง / Value', 'updatedAt'],
    };
    if (reviewedFields.containsKey(name)) return reviewedFields[name]!;
    const fields = <String, List<String>>{
      'Teachers': [
        'username',
        'password',
        'fullName',
        'email',
        'role',
        'permission',
        'position',
        'department',
        'firebase_uid',
        'created_at',
        'updated_at'
      ],
      'Leaves': [
        'uid',
        'requestId',
        'timestamp',
        'status',
        'lastUpdatedAt',
        'fullName',
        'userId',
        'role',
        'position',
        'department',
        'leaveDate',
        'leaveType',
        'reason',
        'startDate',
        'endDate',
        'days',
        'totalDays',
        'year',
        'receiveNumber',
        'medicalCertificate'
      ],
      'UserRoles': [
        'teacherDocId',
        'lastSyncAt',
      ],
      'FiscalRounds': [
        'year',
        'round',
        'startDate',
        'endDate',
        'isActive',
        'createdAt'
      ],
      'SpecialHolidays': [
        'date',
        'dateValue',
        'title',
        'note',
        'source',
        'createdAt',
        'updatedAt'
      ],
      'LoginLogs': [
        'username',
        'fullName',
        'role',
        'timestamp',
        'platform',
        'userAgent'
      ],
    };
    return fields[name] ?? ['รอตรวจจาก Firebase'];
  }

  List<String> _supabaseColumnsForMigration(String name) {
    if (name == 'UserRoles') {
      return const ['id_user', 'lastSyncAt'];
    }
    final importColumns = MigrationService.importColumnsForCollection(name);
    if (importColumns != null) {
      return importColumns.isEmpty
          ? [
              MigrationService.importBlockerForCollection(name) ??
                  'รอยืนยัน schema'
            ]
          : importColumns;
    }
    return const <String>[];
  }

  Future<void> _showMigrationSelectionSummary(List<String> collections) async {
    if (collections.contains('Teachers')) {
      try {
        await MigrationService.refreshTableColumns();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลด schema Teachers ไม่สำเร็จ: $e')),
        );
      }
      if (!mounted) return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เปรียบเทียบข้อมูลที่เลือก',
            style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 780,
          height: 520,
          child: ListView(
            children: collections.map((table) {
              final firebase = _firebaseFieldsForMigration(table);
              final supabase = _supabaseColumnsForMigration(table);
              final blocker = table == 'UserRoles'
                  ? null
                  : MigrationService.importBlockerForCollection(table);
              final rows = <DataRow>[];
              for (var i = 0; i < firebase.length || i < supabase.length; i++) {
                rows.add(DataRow(cells: [
                  DataCell(Text(i < firebase.length ? firebase[i] : '',
                      style: GoogleFonts.sarabun(fontSize: 12))),
                  DataCell(Text(i < supabase.length ? supabase[i] : '',
                      style: GoogleFonts.sarabun(fontSize: 12))),
                ]));
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(table,
                          style: GoogleFonts.sarabun(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor)),
                      if (blocker != null)
                        Text(blocker,
                            style: GoogleFonts.sarabun(
                                fontSize: 12, color: Colors.orange.shade900)),
                      const SizedBox(height: 4),
                      DataTable(
                        headingRowColor:
                            WidgetStateProperty.all(const Color(0xFFE2E8F0)),
                        columnSpacing: 34,
                        columns: [
                          DataColumn(
                              label: Text('Firebase field',
                                  style: GoogleFonts.sarabun(
                                      fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Supabase column',
                                  style: GoogleFonts.sarabun(
                                      fontWeight: FontWeight.bold))),
                        ],
                        rows: rows,
                      ),
                    ]),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('ปิด', style: GoogleFonts.sarabun()))
        ],
      ),
    );
  }

  Widget _buildClearReceiveNumberCard() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Text('ล้างเลขรับใบลาทั้งหมด',
                style: GoogleFonts.sarabun(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor)),
          ]),
          const SizedBox(height: 8),
          Text(
              'ลบเลขรับที่/วันที่/เวลา ออกจากใบลาทั้งหมด เพื่อให้ admin อนุมัติใหม่แล้วระบบเติมเลขรับให้อัตโนมัติ',
              style: GoogleFonts.sarabun(fontSize: 13, color: Colors.blueGrey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isClearing
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('ยืนยันการล้างข้อมูล',
                            style: GoogleFonts.sarabun(
                                fontWeight: FontWeight.bold)),
                        content: Text(
                            'ต้องการล้างเลขรับใบลาทั้งหมดหรือไม่?\nข้อมูลเลขรับ/วันที่/เวลา จะถูกลบออกทั้งหมด',
                            style: GoogleFonts.sarabun()),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('ยกเลิก')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white),
                            child: const Text('ยืนยันล้างข้อมูล'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    setState(() => _isClearing = true);
                    try {
                      await _firebaseService.clearAllReceiveNumbers();
                      if (mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text('✅ ล้างเลขรับใบลาทั้งหมดเรียบร้อย'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('❌ เกิดข้อผิดพลาด: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ));
                      }
                    } finally {
                      if (mounted) setState(() => _isClearing = false);
                    }
                  },
            icon: _isClearing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete_sweep_rounded),
            label:
                Text(_isClearing ? 'กำลังล้างข้อมูล...' : 'ล้างเลขรับทั้งหมด'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
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
                    ? Colors.green.withValues(alpha: 0.05)
                    : Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _syncStatusMsg!.contains('สำเร็จ')
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1)),
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
                        color: Colors.blue.withValues(alpha: 0.1),
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
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: Colors.grey
                                              .withValues(alpha: 0.2)),
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

        // 🚀 บันทึกข้อมูลลง Supabase เท่านั้น — ห้ามเขียน Firebase
        await _firebaseService.updateLeaveRequest(requestId, data);
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
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
              color: Colors.blueGrey.withValues(alpha: 0.05),
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

  void _enablePasswordReset(Map<String, dynamic> user) async {
    final DateTime expiry = DateTime.now().add(const Duration(hours: 24));
    final String resetCode = FirebaseService.generateResetCode();

    try {
      // 🚀 อัปเดตรหัสผ่านลง Supabase เท่านั้น — ห้ามเขียน Firebase
      await _firebaseService.updateTeacherById(user['id'], {
        'password': resetCode,
        'tempResetCode': resetCode,
        'forgotPasswordStatus': 'reset_by_admin',
        'resetAllowedUntil': expiry.toIso8601String(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text('รีเซ็ตสำเร็จ',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('รหัสชั่วคราวสำหรับ ${user['fullName']}:',
                    style: GoogleFonts.sarabun(color: Colors.blueGrey)),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(resetCode,
                      style: GoogleFonts.sarabun(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Colors.indigo.shade900)),
                ),
                const SizedBox(height: 12),
                Text(
                    'ใช้ได้ถึง ${expiry.day}/${expiry.month}/${expiry.year + 543} ${expiry.hour}:${expiry.minute.toString().padLeft(2, '0')} น.',
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: Colors.orange.shade700)),
                const SizedBox(height: 4),
                Text('กรุณาแจ้งรหัสนี้ให้ครูเจ้าของบัญชีครับ',
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: Colors.blueGrey)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ตกลง',
                    style: GoogleFonts.sarabun(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _viewPassword(Map<String, dynamic> user) {
    final pwd = (user['password'] ?? '').toString().trim();
    final bool hasPassword = pwd.isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(hasPassword ? Icons.vpn_key_outlined : Icons.lock_rounded,
                color: hasPassword ? Colors.indigo : Colors.green),
            const SizedBox(width: 12),
            Text(hasPassword ? 'ตรวจสอบรหัสผ่าน' : 'ยังไม่ได้ตั้งรหัสผ่าน',
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasPassword) ...[
              Text(
                  'ผู้ใช้ ${user['fullName'] ?? 'ผู้ใช้งาน'} ยังไม่มีรหัสผ่านในระบบครับ',
                  style: GoogleFonts.sarabun(color: Colors.blueGrey)),
              const SizedBox(height: 16),
              Text(
                  'หากต้องการ ให้ใช้ปุ่ม "รีเซ็ตรหัสผ่าน" เพื่อตั้งรหัสใหม่ให้ครูครับ',
                  style: GoogleFonts.sarabun(
                      fontSize: 12, color: Colors.blueGrey)),
            ] else ...[
              Text('รหัสผ่านของ ${user['fullName'] ?? 'ผู้ใช้งาน'}:',
                  style: GoogleFonts.sarabun(color: Colors.blueGrey)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.indigo.withValues(alpha: 0.1)),
                ),
                child: SelectableText(
                  pwd,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sarabun(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ตกลง',
                style: GoogleFonts.sarabun(
                    fontWeight: FontWeight.bold,
                    color: hasPassword ? Colors.indigo : Colors.green)),
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
                      ? color.withValues(alpha: 0.5)
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

  // Tabs 5-7 moved to calendar_settings_tab.dart
}
