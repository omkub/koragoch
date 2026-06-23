import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../widgets/thai_buddhist_calendar_widget.dart';

class MobileLeaveFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback? onComplete;
  const MobileLeaveFormScreen({super.key, this.initialData, this.onComplete});

  @override
  State<MobileLeaveFormScreen> createState() => _MobileLeaveFormScreenState();
}

class _MobileLeaveFormScreenState extends State<MobileLeaveFormScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();

  // Controllers
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _medicalLinkController = TextEditingController();
  final TextEditingController _yearController =
      TextEditingController(text: (DateTime.now().year + 543).toString());

  // State
  Map<String, dynamic>? _selectedUser;
  String? _loggedInUser;
  String? _userRole;
  String? _selectedLeaveType;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isHalfDay = false;
  String _halfDayPeriod = 'morning';
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _allUsers = [];
  String? _editRequestId;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _initializeEditMode(widget.initialData!);
    }
    _loadUser();
  }

  void _initializeEditMode(Map<String, dynamic> data) {
    _editRequestId = data['requestId'];
    _selectedLeaveType = data['leaveType'];
    _reasonController.text = data['reason'] ?? '';
    _phoneController.text = data['phone'] ?? '';
    _yearController.text = data['year']?.toString() ?? '';

    final medicalLink = data['medicalCertificate']?.toString() ?? '';
    if (medicalLink.isNotEmpty) {
      _medicalLinkController.text = medicalLink;
    }

    _startDate = _parseThaiDate(data['startDate']) ?? DateTime.now();
    _endDate = _parseThaiDate(data['endDate']) ?? DateTime.now();
    _isHalfDay = data['isHalfDay'] == true ||
        data['isHalfDay']?.toString().toLowerCase() == 'true';
    _halfDayPeriod = (data['halfDayPeriod'] ?? 'morning').toString();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? editName =
        widget.initialData?['fullName'] ?? widget.initialData?['name'];
    final name = editName ?? prefs.getString('currentUser');
    final role = prefs.getString('userRole');
    final cacheJson = prefs.getString('userFullDataJson');

    // ⚡ ฝั่งครู: ดึงข้อมูลตัวเองมาโชว์ไวๆ (ถ้าไม่ใช่การแก้ไขใบลาคนอื่น)
    if (cacheJson != null && editName == null) {
      try {
        final cachedData = jsonDecode(cacheJson);
        setState(() {
          _selectedUser = cachedData;
          _loggedInUser = name;
          _userRole = role;
          _phoneController.text =
              cachedData['phone'] ?? cachedData['phoneNumber'] ?? '';
        });
      } catch (_) {}
    } else {
      setState(() {
        _loggedInUser = name;
        _userRole = role;
      });
    }

    // 🛡️ ฝั่งแอดมิน: ดึงรายชื่อครูจาก Cache มาโชว์ใน Dropdown ทันที! 🥇🏆
    if (role?.contains('ผู้ดูแลระบบ') == true) {
      final teachersCache = prefs.getString('admin_teachers_list_cache');
      if (teachersCache != null) {
        try {
          final List<dynamic> decoded = jsonDecode(teachersCache);
          setState(() => _allUsers = List<Map<String, dynamic>>.from(decoded));
        } catch (_) {}
      }
      _loadAllUsers(); // Background sync
    }

    // 🚀 Background Sync ข้อมูลส่วนตัว (Force sync if name is Admin but role is Teacher) 🥇🏆
    final String? uid = _firebaseService.currentUid;
    Map<String, dynamic>? userData;
    if (uid != null) {
      userData = await _firebaseService.searchTeacherByUid(uid);

      // 🛡️ ป้องกันกรณีชื่อ Admin ค้างในสิทธิ์ครูครับ 🥇🏆🏎️
      if (userData != null &&
          userData['fullName'] == 'ผู้ดูแลระบบ' &&
          (role == null || !role.contains('ผู้ดูแลระบบ'))) {
        debugPrint("⚠️ Name mismatch detected! Re-syncing name for Teacher...");
        // ลองหาด้วยชื่อจริงๆ ที่เราควรจะเป็น (ถ้ามี)
        if (name != null && name != 'ผู้ดูแลระบบ') {
          final realUser = await _firebaseService.searchTeacherByName(name);
          if (realUser != null) userData = realUser;
        }
      }
    }

    if (userData == null && name != null)
      userData = await _firebaseService.searchTeacherByName(name);

    if (userData != null && mounted) {
      setState(() {
        _selectedUser = userData;
        _phoneController.text =
            userData!['phone'] ?? userData!['phoneNumber'] ?? '';
      });
      await prefs.setString('userFullDataJson', jsonEncode(userData));

      // 🔄 อัปเดตชื่อใน Prefs ให้ตรงกับฐานข้อมูลล่าสุด (เฉพาะกรณีที่เป็นการดึงข้อมูลตัวเอง ไม่ใช่การแก้ไขใบลาคนอื่นครับ)
      if (userData['fullName'] != null && editName == null) {
        await prefs.setString('currentUser', userData['fullName']);
      }
    }
  }

  void _loadAllUsers() async {
    // 🛡️ ดึงข้อมูลแบบรวดเร็ว (Future) มาอัปเดต Cache ครับ 🥇🏆🏎️
    _firebaseService.getUsers().then((users) async {
      if (mounted) {
        setState(() => _allUsers = users);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_teachers_list_cache', jsonEncode(users));
      }
    }).catchError((e) => debugPrint("Load All Users Error: $e"));

    // 📡 และยังคงเปิด Stream ไว้เผื่อมีการเปลี่ยนแปลงสดๆ ครับ
    _firebaseService.getUsersStream().listen((users) {
      if (mounted) setState(() => _allUsers = users);
    }, onError: (e) => debugPrint("Stream All Users Error: $e"));
  }

  // Attached file info
  String? _attachedFileName;
  String? _attachedFileDataUrl;
  String? _attachedFileType;

  @override
  void dispose() {
    _reasonController.dispose();
    _phoneController.dispose();
    _medicalLinkController.dispose();
    _yearController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchUserData(String fullName) {
    if (_allUsers.isEmpty) return;
    try {
      final user = _allUsers.firstWhere((u) => u['fullName'] == fullName);
      setState(() {
        _selectedUser = user;
        _phoneController.text = user['phone'] ?? user['phoneNumber'] ?? '';
      });
    } catch (_) {}
  }

  String _formatDate(DateTime d) {
    return "${d.day}/${d.month}/${d.year + 543}";
  }

  DateTime? _parseThaiDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      if (year > 2400) year -= 543;
      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool get _isHalfDayActive =>
      _isHalfDay && _isSameCalendarDay(_startDate, _endDate);

  num _calculatedTotalDays() {
    if (_isHalfDayActive) return 0.5;
    final days = _endDate.difference(_startDate).inDays + 1;
    return days < 1 ? 1 : days;
  }

  String _formatLeaveDays(num value) =>
      FirebaseService.formatLeaveDayCount(value);

  void _setStartDate(DateTime date) {
    setState(() {
      _startDate = date;
      if (_isHalfDay || _endDate.isBefore(_startDate)) {
        _endDate = date;
      }
    });
  }

  void _setEndDate(DateTime date) {
    setState(() {
      _endDate = date;
      if (_isHalfDay || _endDate.isBefore(_startDate)) {
        _startDate = date;
      }
    });
  }

  bool _hasLeaveConflict(
    Map<String, dynamic> leave,
    DateTime newStart,
    DateTime newEnd,
  ) {
    final existingStart = _parseThaiDate(leave['startDate']);
    final existingEnd = _parseThaiDate(leave['endDate']);
    if (existingStart == null || existingEnd == null) return false;

    final overlaps =
        newStart.isBefore(existingEnd.add(const Duration(days: 1))) &&
            newEnd.isAfter(existingStart.subtract(const Duration(days: 1)));
    if (!overlaps) return false;

    final existingHalfDay = FirebaseService.isHalfDayLeave(leave);
    final existingPeriod = (leave['halfDayPeriod'] ?? '').toString();
    final bothSingleDay = _isSameCalendarDay(newStart, newEnd) &&
        _isSameCalendarDay(existingStart, existingEnd);
    if (_isHalfDayActive &&
        existingHalfDay &&
        bothSingleDay &&
        existingPeriod != _halfDayPeriod) {
      return false;
    }

    return true;
  }

  Future<void> _pickAndUploadMedicalCertificate() async {
    try {
      final ImagePicker picker = ImagePicker();

      // 🕵️‍♂️ ให้เลือกก่อนว่าจะเอาจากคลังภาพหรือกล้องครับ (รองรับ PDF ผ่าน FilePicker เดิม)
      final String? choice = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.image_rounded),
                title: const Text('เลือกรูปภาพ (แนะนำ - เร็วที่สุด ⚡)'),
                onTap: () => Navigator.pop(ctx, 'img')),
            ListTile(
                leading: const Icon(Icons.file_present_rounded),
                title: const Text('เลือกไฟล์ PDF / อื่นๆ'),
                onTap: () => Navigator.pop(ctx, 'file')),
          ],
        ),
      );

      if (choice == 'img') {
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          imageQuality: 50, // บีบอัด 50% เพื่อให้ส่งไวขึ้นแต่ยังอ่านออกครับ 🥇
        );

        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _attachedFileName = image.name;
            _attachedFileDataUrl =
                "data:image/${image.name.split('.').last};base64,${base64Encode(bytes)}";
            _attachedFileType = image.name.split('.').last;
            _medicalLinkController.clear();
          });
        }
      } else if (choice == 'file') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          withData: true,
        );

        if (result != null && result.files.first.bytes != null) {
          final file = result.files.first;
          setState(() {
            _attachedFileName = file.name;
            _attachedFileDataUrl =
                "data:${_getFileMimeType(file.extension)};base64,${base64Encode(file.bytes!)}";
            _attachedFileType = file.extension;
            _medicalLinkController.clear();
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      _showError("ไม่สามารถเลือกไฟล์ได้: $e");
    }
  }

  String _getFileMimeType(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _submitForm() async {
    if (_selectedUser == null ||
        _selectedLeaveType == null ||
        _selectedLeaveType == '---เลือก---') {
      _showError("กรุณาเลือกบุคลากรและประเภทการลา");
      return;
    }

    if (_reasonController.text.isEmpty) {
      _showError("กรุณาระบุเหตุผลการลา");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String fullName = _selectedUser!['fullName'];
      final history = await _firebaseService.getMyLeaveRequests(fullName);

      final DateTime newStart =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      final DateTime newEnd =
          DateTime(_endDate.year, _endDate.month, _endDate.day);

      for (var leave in history) {
        if (_editRequestId != null && leave['requestId'] == _editRequestId)
          continue;

        final String status = (leave['status'] ?? '').toString();
        if (status.contains('รอ') ||
            status.contains('อนุญาต') ||
            status.contains('ส่งใบ')) {
          final DateTime? existingStart = _parseThaiDate(leave['startDate']);
          final DateTime? existingEnd = _parseThaiDate(leave['endDate']);

          if (existingStart != null && existingEnd != null) {
            if (_hasLeaveConflict(leave, newStart, newEnd)) {
              _showError(
                  '❌ ไม่สามารถส่งได้: คุณมีการลาในช่วงวันที่นี้อยู่แล้ว (${leave['startDate']} - ${leave['endDate']})');
              setState(() => _isSubmitting = false);
              return;
            }
          }
        }
      }

      String finalMedicalUrl = _medicalLinkController.text.trim();
      if (_attachedFileDataUrl != null) {
        // 🚀 แสดงสถานะกำลังอัปโหลดไฟล์แนบ
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
                Text('กำลังส่งไฟล์แนบใบรับรองแพทย์... 📂'),
              ],
            ),
            duration: Duration(minutes: 1),
          ));
        }

        final resData = await _firebaseService.uploadDriveFile(
          fileData: _attachedFileDataUrl!,
          fileName:
              '${DateTime.now().millisecondsSinceEpoch}_$_attachedFileName',
          mimeType: _getFileMimeType(_attachedFileType),
          folderType: 'leave',
          folderId: FirebaseService.driveLeaveFolderId,
        );
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        finalMedicalUrl = resData['url'];
      }

      final data = {
        'leaveType': _selectedLeaveType,
        'startDate': _formatDate(_startDate),
        'endDate': _formatDate(_endDate),
        'totalDays': _calculatedTotalDays(),
        'isHalfDay': _isHalfDayActive,
        'halfDayPeriod': _isHalfDayActive ? _halfDayPeriod : '',
        'reason': _reasonController.text,
        'phone': _phoneController.text,
        'medicalCertificate': finalMedicalUrl,
        'year': _yearController.text,
      };

      if (_editRequestId != null) {
        // 🔒 กรณีแก้ไข: ห้ามอัปเดตชื่อและข้อมูลส่วนตัวทับของเดิมเด็ดขาด ตามคำสั่ง 🥇🏆
        await _firebaseService.updateLeaveRequest(_editRequestId!, data);
      } else {
        // 🆕 กรณีสร้างใหม่: เพิ่มข้อมูลส่วนตัวและวันเวลาสร้างครับ
        data['fullName'] = _selectedUser!['fullName'];
        data['position'] = _selectedUser!['position'];
        data['academicStanding'] = _selectedUser!['academicStanding'];
        data['department'] = _selectedUser!['department'] ?? '';
        data['createdAt'] = DateTime.now().toIso8601String();

        await _firebaseService.submitLeaveRequest(data);
        _firebaseService
            .sendLineNotification(data)
            .catchError((e) => debugPrint("Submit notify error: $e"));
      }

      if (mounted) {
        _resetForm();
        _showSuccess(_editRequestId != null
            ? "อัพเดตข้อมูลใบลาสำเร็จเรียบร้อยแล้วครับ"
            : "ส่งใบลาสำเร็จเรียบร้อยแล้วครับ");
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 500), curve: Curves.easeOut);

        // 🕵️‍♂️ หน่วงเวลานิดนึงก่อนกลับหน้าเดิม เพื่อให้ User เห็นข้อความสำเร็จ
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            if (widget.onComplete != null) {
              widget.onComplete!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        });
      }
    } catch (e) {
      _showError("เกิดข้อผิดพลาด: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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

  void _resetForm() {
    setState(() {
      _selectedLeaveType = null;
      _reasonController.clear();
      _medicalLinkController.clear();
      _attachedFileName = null;
      _attachedFileDataUrl = null;
      _attachedFileType = null;
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _isHalfDay = false;
      _halfDayPeriod = 'morning';
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: GoogleFonts.sarabun()))
      ]),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 28),
            const SizedBox(width: 12),
            Text("สำเร็จ!",
                style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(msg,
            style: GoogleFonts.sarabun(
                fontSize: 16, color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("ตกลง",
                style: GoogleFonts.sarabun(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2563EB))),
          )
        ],
      ),
    );
  }

  // 🖼️ ฟังก์ชันแปลงลิงก์ Google Drive ให้เป็น Direct Link สำหรับแสดงผลครับ 🥇🏆🏎️
  String _getDisplayImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    String? fileId;
    if (url.contains('drive.google.com/file/d/')) {
      final match = RegExp(r"\/d\/([a-zA-Z0-9_-]+)").firstMatch(url);
      if (match != null && match.groupCount >= 1) fileId = match.group(1);
    } else if (url.contains('id=')) {
      final match = RegExp(r"id=([a-zA-Z0-9_-]+)").firstMatch(url);
      if (match != null && match.groupCount >= 1) fileId = match.group(1);
    }

    if (fileId != null) {
      return "https://lh3.googleusercontent.com/d/$fileId";
    }

    return url.contains('?')
        ? "$url&t=${DateTime.now().millisecondsSinceEpoch}"
        : "$url?t=${DateTime.now().millisecondsSinceEpoch}";
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _userRole?.contains('ผู้ดูแลระบบ') == true;

    return Material(
      color: const Color(0xFFF4F7FC),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 24,
                        offset: const Offset(0, 12))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAdmin) ...[
                      _buildFieldLabel("เลือกบุคลากร (สำหรับผู้ดูแลระบบ)"),
                      _allUsers.isEmpty
                          ? const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)))
                          : _buildSearchableDropdown(
                              _allUsers
                                  .map((u) => u['fullName']?.toString() ?? '')
                                  .toList(),
                              (val) => _fetchUserData(val),
                              initialValue:
                                  _selectedUser?['fullName']?.toString(),
                              enabled: _editRequestId ==
                                  null, // 🔒 ล็อกชื่อถ้าเป็นการแก้ไขครับ
                            ),
                      if (_selectedUser != null) ...[
                        const SizedBox(height: 12),
                        _buildUserInfoTag(),
                      ],
                      const SizedBox(height: 24),
                    ],
                    if (!isAdmin) ...[
                      _buildFieldLabel("ผู้ยื่นใบลา"),
                      _selectedUser == null
                          ? Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                children: [
                                  const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                  const SizedBox(width: 12),
                                  Text("กำลังดึงข้อมูลส่วนตัว...",
                                      style: GoogleFonts.sarabun(
                                          color: Colors.grey)),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.blue.withOpacity(0.1))),
                              child: Row(
                                children: [
                                  ClipOval(
                                    child: _selectedUser?['profileImage'] !=
                                                null &&
                                            _selectedUser!['profileImage']
                                                .toString()
                                                .isNotEmpty
                                        ? Image.network(_getDisplayImageUrl(_selectedUser!['profileImage']),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const CircleAvatar(
                                                    backgroundColor:
                                                        Color(0xFFEFF6FF),
                                                    child: Icon(
                                                        Icons.person_rounded,
                                                        color:
                                                            Color(0xFF2563EB))))
                                        : const CircleAvatar(
                                            backgroundColor: Color(0xFFEFF6FF),
                                            child: Icon(Icons.person_rounded,
                                                color: Color(0xFF2563EB))),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_selectedUser?['fullName'] ?? '-',
                                            style: GoogleFonts.sarabun(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    const Color(0xFF0F172A))),
                                        Text(
                                            "${_selectedUser?['position'] ?? '-'} | ${_selectedUser?['department'] ?? '-'}",
                                            style: GoogleFonts.sarabun(
                                                fontSize: 12,
                                                color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 24),
                    ],
                    _buildFieldLabel("ประเภทการลา"),
                    _buildDropdownField(
                        _selectedLeaveType ?? '---เลือก---',
                        [
                          "---เลือก---",
                          "ลาป่วย",
                          "ลากิจส่วนตัว",
                          "ลาคลอดบุตร",
                          "ลาพักผ่อน"
                        ],
                        (val) => setState(() => _selectedLeaveType = val)),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel("เริ่มวันที่"),
                        _buildDatePickerField(
                            FirebaseService.formatThaiDate(_startDate),
                            () async {
                          _showPremiumDatePicker(_startDate, _setStartDate);
                        }),
                        const SizedBox(height: 16),
                        _buildFieldLabel("ถึงวันที่"),
                        _buildDatePickerField(
                            FirebaseService.formatThaiDate(_endDate), () async {
                          _showPremiumDatePicker(_endDate, _setEndDate);
                        }),
                        const SizedBox(height: 16),
                        _buildHalfDaySelector(),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("จำนวนวันที่ลา:",
                                  style: GoogleFonts.sarabun(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF15803D))),
                              Text(
                                  "${_formatLeaveDays(_calculatedTotalDays())} วัน",
                                  style: GoogleFonts.sarabun(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF16A34A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel("เหตุผลการลา"),
                    _buildTextField(_reasonController, Icons.edit_note_rounded,
                        maxLines: 3, hint: "ระบุเหตุผล..."),
                    const SizedBox(height: 20),
                    _buildFieldLabel("เบอร์โทรศัพท์ที่ติดต่อได้"),
                    _buildTextField(_phoneController, Icons.phone_rounded,
                        hint: "08x-xxxxxxx"),
                    const SizedBox(height: 20),
                    _buildFieldLabel("แนบใบรับรองแพทย์ (ถ้ามี)"),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(
                                _medicalLinkController, Icons.link_rounded,
                                hint: "วางลิงก์เอกสาร...")),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _pickAndUploadMedicalCertificate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 56,
                            width: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.attach_file_rounded,
                                color: Color(0xFF2563EB)),
                          ),
                        )
                      ],
                    ),
                    if (_attachedFileName != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFBBF7D0))),
                              child: Row(children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF16A34A), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text("ไฟล์แนบ: $_attachedFileName",
                                        style: const TextStyle(
                                            color: Color(0xFF15803D),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis)),
                                GestureDetector(
                                    onTap: () => setState(
                                        () => _attachedFileName = null),
                                    child: const Icon(Icons.close_rounded,
                                        color: Color(0xFF16A34A), size: 18))
                              ]))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                _editRequestId != null
                                    ? "อัพเดตข้อมูล"
                                    : "ส่งใบลาเข้าระบบ",
                                style: GoogleFonts.sarabun(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            Icon(
                                _editRequestId != null
                                    ? Icons.save_rounded
                                    : Icons.send_rounded,
                                size: 20,
                                color: Colors.white),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHalfDaySelector() {
    final selectedMode = _isHalfDayActive ? _halfDayPeriod : 'full';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'เลือกช่วงเวลาการลา',
          style: GoogleFonts.sarabun(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF94A3B8)),
            ),
            child: Row(
              children: [
                _buildLeaveDurationButton('full', 'เต็มวัน', selectedMode),
                _buildSegmentDivider(),
                _buildLeaveDurationButton(
                    'morning', 'ครึ่งวันเช้า', selectedMode),
                _buildSegmentDivider(),
                _buildLeaveDurationButton(
                    'afternoon', 'ครึ่งวันบ่าย', selectedMode),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveDurationButton(
      String value, String label, String selectedMode) {
    final selected = selectedMode == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            if (value == 'full') {
              _isHalfDay = false;
            } else {
              _isHalfDay = true;
              _halfDayPeriod = value;
              _endDate = _startDate;
            }
          });
        },
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          color: selected ? const Color(0xFFE0EAFF) : Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded,
                    size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sarabun(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentDivider() {
    return Container(
        width: 1, height: double.infinity, color: const Color(0xFF94A3B8));
  }

  Widget _buildUserInfoTag() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                "${_selectedUser?['position'] ?? '-'} | ${_selectedUser?['department'] ?? '-'}",
                style: GoogleFonts.sarabun(
                    fontSize: 13,
                    color: const Color(0xFF1E40AF),
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label,
          style: GoogleFonts.sarabun(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569))));

  Widget _buildTextField(TextEditingController ctrl, IconData icon,
          {String hint = '',
          int maxLines = 1,
          FocusNode? focusNode,
          bool enabled = true,
          Widget? suffixIcon}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        focusNode: focusNode,
        enabled: enabled,
        style: GoogleFonts.sarabun(
            fontSize: 15,
            color: enabled ? const Color(0xFF0F172A) : Colors.black54),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.sarabun(color: const Color(0xFF94A3B8), fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor:
              enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      );

  Widget _buildDropdownField(
          String value, List<String> items, Function(String) onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16)),
        child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF94A3B8)),
                style: GoogleFonts.sarabun(
                    fontSize: 15,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w500),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                items: items
                    .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                    .toList(),
                onChanged: (v) => onChanged(v!))),
      );

  Widget _buildDatePickerField(String value, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_month_rounded,
                size: 18, color: Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Flexible(
                child: Text(
              value,
              style: GoogleFonts.sarabun(
                  fontSize: 14,
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ))
          ])));

  Widget _buildSearchableDropdown(
          List<String> options, Function(String) onSelected,
          {String? initialValue, bool enabled = true}) =>
      Autocomplete<String>(
        initialValue: TextEditingValue(
            text: (initialValue != null && initialValue != '---เลือก---')
                ? initialValue
                : ''),
        optionsBuilder: (v) {
          if (!enabled) return const Iterable<String>.empty();
          return options.where((o) => o.contains(v.text.trim()));
        },
        onSelected: (val) {
          if (enabled) onSelected(val);
        },
        fieldViewBuilder: (ctx, ctrl, focus, onSub) => _buildTextField(
          ctrl,
          Icons.person_rounded,
          hint: "ค้นหาชื่อ...",
          focusNode: focus,
          enabled: enabled,
          suffixIcon: Icon(enabled ? Icons.arrow_drop_down : Icons.lock_outline,
              color: const Color(0xFF94A3B8)),
        ),
      );
}
