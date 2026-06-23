import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thai_buddhist_date_pickers/thai_buddhist_date_pickers.dart';
import 'package:thai_buddhist_date/thai_buddhist_date.dart' as tbd;
import '../services/firebase_service.dart';
import '../widgets/thai_buddhist_calendar_widget.dart';

class LeaveFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback? onComplete;
  const LeaveFormScreen({super.key, this.initialData, this.onComplete});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen>
    with TickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();

  // Controllers
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _yearController =
      TextEditingController(text: (DateTime.now().year + 543).toString());
  final TextEditingController _medicalLinkController = TextEditingController();

  List<Map<String, dynamic>> _allUsers = [];
  Map<String, dynamic>? _selectedUser;
  String? _loggedInUser;
  String? _userRole;
  String? _selectedLeaveType = '---เลือก---';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isHalfDay = false;
  String _halfDayPeriod = 'morning';

  Map<String, dynamic>? _lastLeaveRequest;
  List<Map<String, dynamic>> _userHistory = [];
  bool _isSubmitting = false;
  String? _attachedFileName;
  String? _attachedFileDataUrl;
  String? _attachedFileType;
  String? _editRequestId;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _initializeEditMode(widget.initialData!);
    }
    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final users = await _firebaseService.getUsers();
      if (!mounted) return; // 🛡️ ตรวจสอบก่อน setState เสมอครับ
      setState(() {
        _allUsers = users;
        _loggedInUser = prefs.getString('currentUser');
        _userRole = prefs.getString('userRole');
      });

      // 🕵️‍♂️ ถ้าเป็นการแก้ไข ให้ใช้ชื่อจากใบลาใบนั้นครับ (เช็คทั้ง fullName และ name เพื่อความชัวร์)
      final nameToFetch = widget.initialData?['fullName'] ??
          widget.initialData?['name'] ??
          _loggedInUser;

      if (nameToFetch != null && _allUsers.isNotEmpty) {
        _fetchUserData(nameToFetch);
      }
    } catch (e) {
      debugPrint("Error loading users: $e");
    }
  }

  Future<void> _fetchUserData(String fullName) async {
    try {
      final user = _allUsers.firstWhere((u) => u['fullName'] == fullName,
          orElse: () => {});
      if (user.isNotEmpty) {
        final lastLeave = await _firebaseService.getLastLeaveRequest(fullName);
        final history = await _firebaseService.getMyLeaveRequests(fullName);
        if (!mounted) return; // 🛡️ ตรวจสอบก่อน setState เสมอครับ
        setState(() {
          _selectedUser = user;
          _lastLeaveRequest = lastLeave;
          _userHistory = history;
          _phoneController.text = user['phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year + 543}";
  }

  String _getDay(DateTime date) => date.day.toString();
  String _getMonth(DateTime date) {
    const months = [
      "มกราคม",
      "กุมภาพันธ์",
      "มีนาคม",
      "เมษายน",
      "พฤษภาคม",
      "มิถุนายน",
      "กรกฎาคม",
      "สิงหาคม",
      "กันยายน",
      "ตุลาคม",
      "พฤศจิกายน",
      "ธันวาคม"
    ];
    return months[date.month - 1];
  }

  DateTime? _parseThaiDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = int.parse(parts[2]);
      if (year > 2400) year -= 543; // แปลง พ.ศ. เป็น ค.ศ.
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

  Future<void> _pickMedicalCertificateFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
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
    } catch (e) {
      debugPrint("Error picking medical certificate file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('ไม่สามารถเลือกไฟล์ได้: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
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
        _selectedLeaveType == '---เลือก---' ||
        _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('กรุณากรอกข้อมูลให้ครบถ้วนครับ'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.amber,
      ));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // 🕵️‍♂️ เช็คการลาซ้ำ (Duplicate/Overlap Check) 🥇🏆
      final String fullName = _selectedUser!['fullName'];
      final history = await _firebaseService.getMyLeaveRequests(fullName);

      final DateTime newStart =
          DateTime(_startDate.year, _startDate.month, _startDate.day);
      final DateTime newEnd =
          DateTime(_endDate.year, _endDate.month, _endDate.day);

      for (var leave in history) {
        if (_editRequestId != null && leave['requestId'] == _editRequestId)
          continue; // ข้ามตัวเองถ้ากำลังแก้ไข

        final String status = (leave['status'] ?? '').toString();
        // เช็คเฉพาะที่รอพิจารณาหรืออนุมัติแล้วเท่านั้นครับ 🥇
        if (status.contains('รอ') ||
            status.contains('อนุญาต') ||
            status.contains('ส่งใบ')) {
          final DateTime? existingStart = _parseThaiDate(leave['startDate']);
          final DateTime? existingEnd = _parseThaiDate(leave['endDate']);

          if (existingStart != null && existingEnd != null) {
            if (_hasLeaveConflict(leave, newStart, newEnd)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      '❌ ไม่สามารถส่งได้: คุณมีการลาในช่วงวันที่นี้อยู่แล้ว (${leave['startDate']} - ${leave['endDate']}) สถานะ: $status'),
                  backgroundColor: Colors.redAccent,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                ));
              }
              setState(() => _isSubmitting = false);
              return;
            }
          }
        }
      }

      String finalMedicalUrl = _medicalLinkController.text.trim();
      if (_attachedFileDataUrl != null) {
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
                Text('กำลังส่งไฟล์แนบใบรับรองแพทย์...'),
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
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        finalMedicalUrl = resData['url'];
      }

      final data = {
        'leaveType': _selectedLeaveType,
        'reason': _reasonController.text,
        'startDate': _formatDate(_startDate),
        'endDate': _formatDate(_endDate),
        'totalDays': _calculatedTotalDays(),
        'isHalfDay': _isHalfDayActive,
        'halfDayPeriod': _isHalfDayActive ? _halfDayPeriod : '',
        'phone': _phoneController.text,
        'year': _yearController.text,
        'medicalCertificate': finalMedicalUrl,
      };

      if (_editRequestId != null) {
        // 🔒 กรณีแก้ไข: ห้ามอัปเดตชื่อและข้อมูลส่วนตัวทับของเดิมเด็ดขาด ตามคำสั่ง 🥇🏆
        await _firebaseService.updateLeaveRequest(_editRequestId!, data);
      } else {
        // 🆕 กรณีสร้างใหม่: เพิ่มข้อมูลส่วนตัวครับ
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_editRequestId != null
              ? 'อัพเดตข้อมูลใบลาสำเร็จแล้วครับ ✨'
              : 'ส่งใบลาสำเร็จแล้วครับ ✨'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ));

        // 🚀 รีเซ็ตฟอร์มให้สะอาด เพื่อพร้อมรับใบถัดไปครับ 🥇🏆
        setState(() {
          _selectedLeaveType = '---เลือก---';
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

        // 🕵️‍♂️ ถ้ามี Navigator ให้ Pop (สำหรับ Mobile) แต่ถ้าไม่มีให้ปล่อยผ่าน (สำหรับ Desktop)
        if (Navigator.of(context).canPop()) {
          Future.delayed(const Duration(milliseconds: 500),
              () => Navigator.of(context).pop());
        }

        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final num totalDays = _calculatedTotalDays();
    final TextStyle bodyStyle =
        GoogleFonts.sarabun(fontSize: 14, color: Colors.black, height: 1.5);
    // 📱 ปรับเกณฑ์เป็น 1100 ให้ตรงกับ MainLayout เพื่อความเสถียรครับ 🥇🏆
    final bool isMobile = MediaQuery.of(context).size.width < 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          // Left Sidebar - Input Form (Enhanced UI)
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(4, 0))
              ]),
              child: SingleChildScrollView(
                // 📏 ปรับ Padding ตามขนาดหน้าจอครับ
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 40, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("แบบฟอร์มใบลาใหม่",
                        style: GoogleFonts.sarabun(
                            fontSize: isMobile ? 24 : 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B))),
                    const SizedBox(height: 24),
                    if (_userRole?.contains('ผู้ดูแลระบบ') == true) ...[
                      _buildAnimatedFormSection(
                          title: "ข้อมูลบุคลากร (สำหรับผู้ดูแลระบบ)",
                          icon: Icons.person_search_outlined,
                          child: Column(
                            children: [
                              _allUsers.isEmpty
                                  ? Row(
                                      children: [
                                        const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)),
                                        const SizedBox(width: 12),
                                        Text("กำลังโหลดรายชื่อบุคลากร...",
                                            style: GoogleFonts.sarabun(
                                                fontSize: 14,
                                                color: Colors.blueGrey)),
                                      ],
                                    )
                                  : _buildSearchableDropdown(
                                      _allUsers
                                          .map((u) =>
                                              u['fullName']?.toString() ?? '')
                                          .toList(),
                                      (val) {
                                        _fetchUserData(val);
                                      },
                                      initialValue: _selectedUser?['fullName']
                                          ?.toString(),
                                      enabled: _editRequestId ==
                                          null, // 🔒 ล็อกชื่อถ้าเป็นการแก้ไขครับ
                                    ),
                              if (_selectedUser != null) _buildUserInfoFooter(),
                            ],
                          )),
                    ] else ...[
                      _buildAnimatedFormSection(
                        title: "ข้อมูลผู้ยื่นใบลา",
                        icon: Icons.person_outline,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline,
                                      size: 18, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _loggedInUser ?? 'กำลังโหลดชื่อ...',
                                      style: GoogleFonts.sarabun(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF334155)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedUser != null) _buildUserInfoFooter(),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildAnimatedFormSection(
                        title: "รายละเอียดการลา",
                        icon: Icons.article_outlined,
                        child: Column(
                          children: [
                            _buildDropdownField(
                                _selectedLeaveType ?? '---เลือก---', [
                              "---เลือก---",
                              "ลาป่วย",
                              "ลากิจส่วนตัว",
                              "ลาคลอดบุตร",
                              "ลาพักผ่อน"
                            ], (val) {
                              setState(() => _selectedLeaveType = val);
                            }),
                            const SizedBox(height: 16),
                            // 📱 ใช้ LayoutBuilder เพื่อวัด "พื้นที่จริง" แทนการเดาขนาดหน้าจอครับ 🥇🏆
                            LayoutBuilder(
                              builder: (context, constraints) {
                                bool useColumn = constraints.maxWidth < 500;
                                if (useColumn) {
                                  return Column(
                                    children: [
                                      _buildDatePickerField(
                                          "เริ่มวันที่",
                                          FirebaseService.formatThaiDate(
                                              _startDate), () async {
                                        _showPremiumDatePicker(
                                            _startDate, _setStartDate);
                                      }),
                                      const SizedBox(height: 16),
                                      _buildDatePickerField(
                                          "ถึงวันที่",
                                          FirebaseService.formatThaiDate(
                                              _endDate), () async {
                                        _showPremiumDatePicker(
                                            _endDate, _setEndDate);
                                      }),
                                      const SizedBox(height: 12),
                                      _buildHalfDaySelector(),
                                      const SizedBox(height: 12),
                                      _buildTotalDaysBadge(),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                              child: _buildDatePickerField(
                                                  "เริ่มวันที่",
                                                  FirebaseService
                                                      .formatThaiDate(
                                                          _startDate),
                                                  () async {
                                            _showPremiumDatePicker(
                                                _startDate, _setStartDate);
                                          })),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: _buildDatePickerField(
                                                  "ถึงวันที่",
                                                  FirebaseService
                                                      .formatThaiDate(_endDate),
                                                  () async {
                                            _showPremiumDatePicker(
                                                _endDate, _setEndDate);
                                          })),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildHalfDaySelector(),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: _buildTotalDaysBadge(),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                                _reasonController, Icons.edit_note_outlined,
                                hint: "ระบุเหตุผลการลาอย่างละเอียด",
                                maxLines: 2),
                          ],
                        )),
                    const SizedBox(height: 24),
                    _buildAnimatedFormSection(
                        title: "ข้อมูลติดต่อและอื่นๆ",
                        icon: Icons.contact_phone_outlined,
                        child: Column(
                          children: [
                            _buildTextField(
                                _phoneController, Icons.phone_android_outlined,
                                hint: "เบอร์โทรศัพท์ที่ติดต่อได้ระหว่างลา"),
                            const SizedBox(height: 16),
                            _buildTextField(
                                _yearController, Icons.calendar_month_outlined,
                                hint: "ปีงบประมาณ พ.ศ."),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(_medicalLinkController,
                                      Icons.link_rounded,
                                      hint: "วางลิงก์ใบรับรองแพทย์ (ถ้ามี)"),
                                ),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: _pickMedicalCertificateFile,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: const Icon(Icons.attach_file_rounded,
                                        color: Color(0xFF2563EB)),
                                  ),
                                ),
                              ],
                            ),
                            if (_attachedFileName != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFBBF7D0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Color(0xFF16A34A), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "ไฟล์แนบ: $_attachedFileName",
                                        style: const TextStyle(
                                            color: Color(0xFF15803D),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _attachedFileName = null;
                                        _attachedFileDataUrl = null;
                                        _attachedFileType = null;
                                      }),
                                      child: const Icon(Icons.close_rounded,
                                          color: Color(0xFF16A34A), size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        )),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                _editRequestId != null
                                    ? "อัพเดตข้อมูล"
                                    : "บันทึกและส่งใบลา",
                                style: GoogleFonts.sarabun(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Right Side - Masterpiece A4 Preview (ซ่อนในมือถือครับ)
          if (!isMobile)
            Expanded(
              flex: 7,
              child: Container(
                color: const Color(0xFF475569), // Darker slate for focus
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40, horizontal: 20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 794, // A4 at 96 DPI
                      constraints: const BoxConstraints(minHeight: 1123),
                      padding: const EdgeInsets.all(60),
                      decoration:
                          BoxDecoration(color: Colors.white, boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 40,
                            offset: const Offset(0, 20))
                      ]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Official Header Registration Area
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 180),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text("แบบใบลา",
                                        style: GoogleFonts.sarabun(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            decoration:
                                                TextDecoration.underline)),
                                    Text("ลาป่วย/ลากิจ/ลาคลอดบุตร",
                                        style:
                                            GoogleFonts.sarabun(fontSize: 14)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 180,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    border: Border.all(width: 0.8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPerfectDottedLabel("รับที่"),
                                    const SizedBox(height: 6),
                                    _buildPerfectDottedLabel("วันที่"),
                                    const SizedBox(height: 6),
                                    _buildPerfectDottedLabel("เวลา"),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text("โรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก",
                                    style: bodyStyle.copyWith(
                                        fontWeight: FontWeight.bold)),
                                Text("อำเภอบ้านด่าน จังหวัดบุรีรัมย์ 31000",
                                    style: bodyStyle),
                                const SizedBox(height: 20),
                                Text(
                                    "วันที่ ................ เดือน ................................ พ.ศ. ....................",
                                    style: bodyStyle),
                              ],
                            ),
                          ),
                          const SizedBox(height: 35),
                          _buildPerfectFullWidthRow([
                            Text("เรื่อง ",
                                style: bodyStyle.copyWith(
                                    fontWeight: FontWeight.bold)),
                            _buildPerfectDottedLine(
                                value: _selectedLeaveType == '---เลือก---'
                                    ? ''
                                    : "ขอ$_selectedLeaveType")
                          ]),
                          Text(
                              "เรียน ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก",
                              style: bodyStyle),
                          const SizedBox(height: 18),
                          _buildPerfectFullWidthRow([
                            const SizedBox(width: 60),
                            Text("ข้าพเจ้า", style: bodyStyle),
                            _buildPerfectDottedLine(
                                value: (_selectedUser?['fullName'] ?? '')
                                    .toString(),
                                flex: 8),
                            Text("ตำแหน่ง", style: bodyStyle),
                            Builder(builder: (context) {
                              String pos =
                                  (_selectedUser?['position']?.toString() ??
                                      '');
                              if (pos == '---เลือก---') pos = '';

                              String rank = (_selectedUser?['academicStanding']
                                      ?.toString() ??
                                  '');
                              if (rank == '---เลือก---' || rank == '-')
                                rank = '';

                              String combined = pos;
                              if (rank.isNotEmpty) combined += " $rank";

                              return _buildPerfectDottedLine(
                                  value: combined, flex: 5);
                            }),
                            Text("โรงเรียนรมย์บุรีพิทยาคม", style: bodyStyle),
                          ]),
                          Text(
                              "รัชมังคลาภิเษก สังกัดสำนักงานเขตพื้นที่การศึกษามัธยมศึกษาบุรีรัมย์ กระทรวงศึกษาธิการ",
                              style: bodyStyle),
                          const SizedBox(height: 18),

                          // Leave Type Section with Styled Curly Bracket
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                  width: 80,
                                  child: Text("ขอลา",
                                      style: bodyStyle.copyWith(
                                          fontWeight: FontWeight.bold))),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  "ป่วย",
                                  "ลากิจส่วนตัว",
                                  "ลาคลอดบุตร",
                                  "ลาพักผ่อน"
                                ].map((t) {
                                  bool isChecked = _selectedLeaveType == t;
                                  return _buildPerfectCheckBox(t, isChecked);
                                }).toList(),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Transform.scale(
                                  scaleX: 0.4,
                                  child: Text("}",
                                      style: GoogleFonts.sarabun(
                                          fontSize: 130,
                                          fontWeight: FontWeight.w100,
                                          height: 0.8,
                                          color:
                                              Colors.black.withOpacity(0.5))),
                                ),
                              ),
                              Expanded(
                                  child: Column(children: [
                                const SizedBox(
                                    height: 35), // Align with 'ลากิจส่วนตัว'
                                _buildPerfectFullWidthRow([
                                  Text("เนื่องจาก", style: bodyStyle),
                                  _buildPerfectDottedLine(
                                      value: _reasonController.text)
                                ]),
                                _buildPerfectDottedLine(
                                    width: double.infinity, flex: 0)
                              ]))
                            ],
                          ),
                          const SizedBox(height: 18),

                          _buildPerfectFullWidthRow([
                            Text("ตั้งแต่วันที่", style: bodyStyle),
                            _buildPerfectDottedLine(
                                value: FirebaseService.formatThaiDate(
                                    _formatDate(_startDate))),
                            Text("ถึงวันที่", style: bodyStyle),
                            _buildPerfectDottedLine(
                                value: FirebaseService.formatThaiDate(
                                    _formatDate(_endDate))),
                            Text("มีกำหนด", style: bodyStyle),
                            _buildPerfectDottedLine(
                                flex: 0,
                                width: 60,
                                value: _formatLeaveDays(totalDays)),
                            Text("วัน", style: bodyStyle),
                          ]),
                          _buildPerfectFullWidthRow([
                            Text("ข้าพเจ้าได้ลา", style: bodyStyle),
                            _buildPerfectCheckBox(
                                "ป่วย",
                                _lastLeaveRequest?['leaveType']
                                        ?.contains("ป่วย") ??
                                    false),
                            _buildPerfectCheckBox(
                                "ลากิจส่วนตัว",
                                _lastLeaveRequest?['leaveType']
                                        ?.contains("กิจ") ??
                                    false),
                            _buildPerfectCheckBox(
                                "ลาคลอดบุตร",
                                _lastLeaveRequest?['leaveType']
                                        ?.contains("คลอด") ??
                                    false),
                            Text("ครั้งสุดท้ายตั้งแต่วันที่", style: bodyStyle),
                            _buildPerfectDottedLine(
                                value: _lastLeaveRequest?['startDate'] != null
                                    ? FirebaseService.formatThaiDate(
                                        _lastLeaveRequest!['startDate'])
                                    : "",
                                flex: 1),
                            Text("ถึงวันที่", style: bodyStyle),
                            _buildPerfectDottedLine(
                                value: _lastLeaveRequest?['endDate'] != null
                                    ? FirebaseService.formatThaiDate(
                                        _lastLeaveRequest!['endDate'])
                                    : "",
                                flex: 1),
                          ]),
                          _buildPerfectFullWidthRow([
                            Text("มีกำหนด", style: bodyStyle),
                            _buildPerfectDottedLine(
                                flex: 0,
                                width: 40,
                                value: _lastLeaveRequest?['totalDays']
                                        ?.toString() ??
                                    ""),
                            Text("วัน ในระหว่างที่ลาติดต่อข้าพเจ้าได้ที่",
                                style: bodyStyle),
                            _buildPerfectDottedLine(
                                flex: 4,
                                value: _phoneController.text.toString()),
                          ]),
                          const SizedBox(height: 25),
                          Center(
                              child: Text("จึงเรียนมาเพื่อโปรดพิจารณา",
                                  style: bodyStyle)),

                          const SizedBox(height: 40),

                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // LEFT SIDE: Statistics & HR Approval
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const Spacer(),
                                      Text("สถิติวันลาในปีงบประมาณนี้",
                                          style: GoogleFonts.sarabun(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      Table(
                                        border: TableBorder.all(width: 0.6),
                                        columnWidths: const {
                                          0: FlexColumnWidth(1.2),
                                          1: FlexColumnWidth(1.0),
                                          2: FlexColumnWidth(1.0),
                                          3: FlexColumnWidth(1.0),
                                        },
                                        children: [
                                          TableRow(children: [
                                            _A4Cell("ประเภท\nการลา",
                                                bold: true, height: 60),
                                            _A4Cell(
                                                "ลามาแล้ว\nครั้ง/วัน\n(วันทำการ)",
                                                bold: true,
                                                height: 60),
                                            _A4Cell(
                                                "ลาครั้งนี้\nครั้ง/วัน\n(วันทำการ)",
                                                bold: true,
                                                height: 60),
                                            _A4Cell(
                                                "รวมเป็น\nครั้ง/วัน\n(วันทำการ)",
                                                bold: true,
                                                height: 60),
                                          ]),
                                          _buildPerfectTableRow(
                                              "ป่วย", totalDays),
                                          _buildPerfectTableRow(
                                              "ลากิจ", totalDays),
                                          _buildPerfectTableRow(
                                              "ลาคลอดบุตร", totalDays),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                          "ลงชื่อ ..................................................",
                                          style: bodyStyle),
                                      Text(
                                          _getManagerName(
                                              "หัวหน้ากลุ่มบริหารงานบุคคล"),
                                          style: bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold)),
                                      Text("หัวหน้ากลุ่มบริหารงานบุคคล",
                                          style: bodyStyle),
                                      Text("........../........../..........",
                                          style: bodyStyle),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 45),

                                // RIGHT SIDE: Applicant Sign & Executive Approval
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text("ขอแสดงความนับถือ",
                                          style: bodyStyle),
                                      const SizedBox(height: 15),
                                      Text(
                                          "ลงชื่อ ..................................................",
                                          style: bodyStyle),
                                      Text(
                                          "(${_selectedUser?['fullName'] ?? '................................'})",
                                          style: GoogleFonts.sarabun(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text(
                                          "ตำแหน่ง ${_selectedUser?['position'] ?? '................................'}",
                                          style: bodyStyle),
                                      const SizedBox(height: 35),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text("ความคิดเห็น",
                                              style: GoogleFonts.sarabun(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(
                                              "................................................................................",
                                              style: GoogleFonts.sarabun(
                                                  color: Colors.black26,
                                                  fontSize: 13,
                                                  letterSpacing: 1)),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                          "ลงชื่อ ..................................................",
                                          style: bodyStyle),
                                      Text(
                                          _getManagerName(
                                              "รองผู้อำนวยการกลุ่มบริหารงานบุคคล"),
                                          style: bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold)),
                                      Text("รองผู้อำนวยการกลุ่มบริหารงานบุคคล",
                                          style: bodyStyle),
                                      Text("........../........../..........",
                                          style: bodyStyle),
                                      const SizedBox(height: 30),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text("คำสั่ง",
                                              style: GoogleFonts.sarabun(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 15),
                                          _buildPerfectCheckBox(
                                              "อนุญาต", false),
                                          _buildPerfectCheckBox(
                                              "ไม่อนุญาต", false),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                          "ลงชื่อ ..................................................",
                                          style: bodyStyle),
                                      Text(
                                          _getManagerName(
                                              "ผู้อำนวยการโรงเรียน"),
                                          style: bodyStyle.copyWith(
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                          "ผู้อำนวยการโรงเรียนรมย์บุรีพิทยาคม รัชมังคลาภิเษก",
                                          style: bodyStyle,
                                          textAlign: TextAlign.center),
                                      Text("........../........../..........",
                                          style: bodyStyle),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFormSection(
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Text(title,
                style: GoogleFonts.sarabun(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B))),
          ]),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1)),
          child,
        ],
      ),
    );
  }

  Widget _buildPerfectDottedLabel(String label) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text("$label .............................",
            style: GoogleFonts.sarabun(
                fontSize: 12, color: Colors.blueGrey.shade800)));
  }

  Widget _buildPerfectFullWidthRow(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: children),
      );

  Widget _buildPerfectDottedLine({int flex = 1, double? width, String? value}) {
    final widget = Container(
      width: width,
      height: 32, // เพิ่มจาก 28
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2), // ขยับจุดลงนิดหนึ่ง
            child: Text(
                "......................................................................................................................................",
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: GoogleFonts.sarabun(
                    color: Colors.black26, fontSize: 18, letterSpacing: 2)),
          ),
          if (value != null && value.isNotEmpty)
            Positioned(
                bottom: 10, // ยกตัวหนังสือขึ้นจาก 6 เป็น 10
                child: Text(value,
                    style: GoogleFonts.sarabun(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A)))),
        ],
      ),
    );
    return flex > 0 ? Expanded(flex: flex, child: widget) : widget;
  }

  Widget _buildPerfectCheckBox(String label, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                  border: Border.all(width: 1, color: Colors.black)),
              child: isChecked
                  ? const Icon(Icons.check,
                      size: 14, color: Colors.black, weight: 800)
                  : null),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.sarabun(fontSize: 14)),
        ],
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
            height: 44,
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
                    'morning', 'ครึ่งวันเช้า (0.5 วัน)', selectedMode),
                _buildSegmentDivider(),
                _buildLeaveDurationButton(
                    'afternoon', 'ครึ่งวันบ่าย (0.5 วัน)', selectedMode),
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
                    size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sarabun(
                    fontSize: 14,
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

  Widget _buildTotalDaysBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Text(
        'รวมจำนวนที่ลา: ${_formatLeaveDays(_calculatedTotalDays())} วัน',
        style: GoogleFonts.sarabun(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF16A34A),
        ),
      ),
    );
  }

  TableRow _buildPerfectTableRow(String label, num currentDays) {
    final String currentYear = _yearController.text;
    final relevantHistory = _userHistory.where((req) {
      final String reqType = (req['leaveType'] ?? "").toString();
      final String reqYear = (req['year'] ?? "").toString();
      bool typeMatch = false;
      if (label == "ป่วย") typeMatch = reqType.contains("ป่วย");
      if (label == "ลากิจ") typeMatch = reqType.contains("กิจ");
      if (label == "ลาคลอดบุตร") typeMatch = reqType.contains("คลอด");
      return typeMatch && reqYear == currentYear;
    }).toList();

    int prevTimes = relevantHistory.length;
    double prevDays = relevantHistory.fold<double>(
        0,
        (sum, req) =>
            sum + (double.tryParse(req['totalDays']?.toString() ?? '0') ?? 0));
    bool isCurrentMatch = _selectedLeaveType == label ||
        (label == "ลากิจ" && _selectedLeaveType == "ลากิจส่วนตัว") ||
        (label == "ลาคลอดบุตร" && _selectedLeaveType == "ลาคลอดบุตร");

    String col2Count = prevTimes > 0 ? "$prevTimes" : "-";
    String col2Days = prevDays > 0 ? _formatLeaveDays(prevDays) : "-";

    String col3Count = isCurrentMatch ? "1" : "-";
    String col3Days = isCurrentMatch ? _formatLeaveDays(currentDays) : "-";

    int totalTimes = prevTimes + (isCurrentMatch ? 1 : 0);
    double totalDays = prevDays + (isCurrentMatch ? currentDays.toDouble() : 0);

    String col4Count = totalTimes > 0 ? "$totalTimes" : "-";
    String col4Days = totalDays > 0 ? _formatLeaveDays(totalDays) : "-";

    return TableRow(children: [
      _A4Cell(label),
      _A4SplitCell(col2Count, col2Days),
      _A4SplitCell(col3Count, col3Days),
      _A4SplitCell(col4Count, col4Days),
    ]);
  }

  Widget _A4SplitCell(String left, String right) {
    return Container(
      height: 25,
      child: Row(
        children: [
          Expanded(
              child: Center(
                  child: Text(left, style: GoogleFonts.sarabun(fontSize: 10)))),
          Container(width: 0.6, color: Colors.black),
          Expanded(
              child: Center(
                  child:
                      Text(right, style: GoogleFonts.sarabun(fontSize: 10)))),
        ],
      ),
    );
  }

  String _getManagerName(String adminTitle) {
    if (_allUsers.isEmpty) return "(................................)";
    final manager = _allUsers.firstWhere(
        (u) => (u['ตำแหน่งงานบริหาร']?.toString() == adminTitle),
        orElse: () => {});
    return manager.isNotEmpty
        ? "(${manager['fullName'] ?? '................................'})"
        : "(................................)";
  }

  Widget _buildDatePickerField(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label,
                style: GoogleFonts.sarabun(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF64748B)))),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            // 📏 ลด Padding และขนาดไอคอนลงเพื่อรองรับจอแคบ 340px ครับ 🥇🏆
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Row(children: [
              const Icon(Icons.event_available,
                  size: 16, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, IconData icon,
      {String hint = '', int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: (v) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2)),
        contentPadding: const EdgeInsets.all(16),
      ),
      style: GoogleFonts.sarabun(fontSize: 14),
    );
  }

  Widget _buildSearchableDropdown(
      List<String> options, Function(String) onSelected,
      {String? initialValue, bool enabled = true}) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(
          text: (initialValue != null && initialValue != '---เลือก---')
              ? initialValue
              : ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (!enabled) return const Iterable<String>.empty();
        if (textEditingValue.text.isEmpty) return options;
        return options.where((String option) => option
            .toLowerCase()
            .contains(textEditingValue.text.toLowerCase().trim()));
      },
      onSelected: (String selection) {
        if (!enabled) return;
        onSelected(selection);
        FocusScope.of(context).unfocus();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          onTap: () {
            if (enabled && controller.text.isNotEmpty) controller.clear();
          },
          decoration: InputDecoration(
            hintText: 'พิมพ์เพื่อค้นหาชื่อบุคลากร...',
            prefixIcon:
                const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
            suffixIcon: Icon(
                enabled ? Icons.arrow_drop_down : Icons.lock_outline,
                color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: GoogleFonts.sarabun(
              fontSize: 14, color: enabled ? Colors.black : Colors.black54),
        );
      },
    );
  }

  Widget _buildDropdownField(
      String initialValue, List<String> options, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(initialValue) ? initialValue : options.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
          items: options
              .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type, style: const TextStyle(fontSize: 14))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildUserInfoFooter() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Builder(builder: (context) {
                String pos = _selectedUser?['position'] ?? '-';
                String dept = _selectedUser?['department'] ?? '-';
                String rank = _selectedUser?['academicStanding'] ?? '';

                String combinedInfo = pos;
                if (rank.isNotEmpty && rank != '-' && rank != '---เลือก---')
                  combinedInfo += " | $rank";
                combinedInfo += " | $dept";

                return Text(combinedInfo,
                    style: GoogleFonts.sarabun(
                        fontSize: 12, color: Colors.blue.shade800));
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _A4Cell extends StatelessWidget {
  final String text;
  final bool bold;
  final double? height;
  const _A4Cell(this.text, {this.bold = false, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(5.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.sarabun(
          fontSize:
              10, // ปรับฟอนต์ให้เล็กลงนิดหน่อยเพื่อให้ลงตัวกับ 7 คอลัมน์ครับ
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
