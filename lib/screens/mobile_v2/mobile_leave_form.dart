/// ฟอร์มส่งใบลา / แก้ไขใบลาสำหรับมือถือแบบใหม่ (mobile_v2)
/// แยกออกจาก lib/screens/mobile/ เพื่อไม่ให้กระทบหน้าจอมือถือแบบเก่า
///
/// จัดระเบียบออกเป็น 3 หมวดหมู่ที่ชัดเจน:
///   1) ข้อมูลผู้ยื่นและประเภทการลา
///   2) ช่วงวันที่และระยะเวลาการลา
///   3) เหตุผล เบอร์ติดต่อ และใบรับรองแพทย์
/// พร้อมแถบปุ่มด้านล่างติดจอ (ดูตัวอย่างใบลา + ส่งใบลา)
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/firebase_service.dart';
import '../../services/official_trip_service.dart';
import '../../widgets/thai_buddhist_calendar_widget.dart';
import '../../utils/profile_image.dart';
import '../../utils/staff_status.dart';
import '../../widgets/leave_form_page.dart';
import '../../utils/leave_permissions.dart';
import 'mobile_pages.dart';

class MobileLeaveFormV2 extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final VoidCallback? onComplete;

  const MobileLeaveFormV2({
    super.key,
    this.initialData,
    this.onComplete,
  });

  @override
  State<MobileLeaveFormV2> createState() => _MobileLeaveFormV2State();
}

class _MobileLeaveFormV2State extends State<MobileLeaveFormV2> {
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _medicalLinkController = TextEditingController();

  String get _fiscalYearText =>
      OfficialTripService.fiscalYearOf(_startDate).toString();

  Map<String, dynamic>? _selectedUser;
  String? _userRole;
  String? _selectedLeaveType;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isHalfDay = false;
  String _halfDayPeriod = 'morning';
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _allUsers = [];
  List<String> _leaveTypeNames = [];
  String? _editRequestId;

  String? _attachedFileName;
  String? _attachedFileDataUrl;
  String? _attachedFileType;
  bool _openingPreview = false;

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

    final medicalLink = data['medicalCertificate']?.toString() ?? '';
    if (medicalLink.isNotEmpty) {
      _medicalLinkController.text = medicalLink;
    }

    _startDate = _parseThaiDate(data['startDate']) ?? DateTime.now();
    _endDate = _parseThaiDate(data['endDate']) ?? DateTime.now();
    _isHalfDay = data['isHalfDay'] == true ||
        data['isHalfDay']?.toString().toLowerCase() == 'true';
    _halfDayPeriod = (data['halfDayPeriod'] ?? 'morning').toString();
    if (_isMaternityLeave) {
      _isHalfDay = false;
      _endDate = _maternityEndDateFrom(_startDate);
    }
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? editName =
        widget.initialData?['fullName'] ?? widget.initialData?['name'];
    final name = editName ?? prefs.getString('currentUser');
    final role = prefs.getString('userRole');
    final cacheJson = prefs.getString('userFullDataJson');

    if (cacheJson != null && editName == null) {
      try {
        final decoded = jsonDecode(cacheJson);
        if (decoded is Map) {
          final cachedData = Map<String, dynamic>.from(decoded);
          setState(() {
            _selectedUser = cachedData;
            _userRole = role;
            _phoneController.text =
                (cachedData['phone'] ?? cachedData['phoneNumber'] ?? '')
                    .toString();
          });
        } else {
          setState(() => _userRole = role);
        }
      } catch (_) {
        setState(() => _userRole = role);
      }
    } else {
      setState(() => _userRole = role);
    }

    _firebaseService.getLeaveTypesRawFromSupabase().then((types) {
      if (mounted) {
        setState(() {
          _leaveTypeNames = types
              .map((t) => (t['leaveName'] ?? t['Value'] ?? '').toString())
              .where((n) => n.isNotEmpty)
              .toList();
        });
      }
    });

    if (LeavePermissions.canFileForOthers(role)) {
      final teachersCache = prefs.getString('admin_teachers_list_cache');
      if (teachersCache != null) {
        try {
          final List<dynamic> decoded = jsonDecode(teachersCache);
          setState(() => _allUsers = List<Map<String, dynamic>>.from(decoded));
        } catch (_) {}
      }
      _loadAllUsers();
    }

    Map<String, dynamic>? userData;
    if (name != null) {
      userData = await _firebaseService.searchTeacherByName(name);
    }

    final loadedUserData = userData;
    if (loadedUserData != null && mounted) {
      setState(() {
        _selectedUser = loadedUserData;
        _phoneController.text =
            (loadedUserData['phone'] ?? loadedUserData['phoneNumber'] ?? '')
                .toString();
      });
      await prefs.setString('userFullDataJson', jsonEncode(loadedUserData));

      final fullName = loadedUserData['fullName'];
      if (fullName != null && editName == null) {
        await prefs.setString('currentUser', fullName.toString());
      }
    }
  }

  void _loadAllUsers() async {
    _firebaseService.getUsers().then((users) async {
      if (mounted) {
        setState(() => _allUsers = users);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_teachers_list_cache', jsonEncode(users));
      }
    }).catchError((Object e) {
      debugPrint("Load All Users Error: $e");
    });

    _firebaseService.getUsersStream().listen((users) {
      if (mounted) setState(() => _allUsers = users);
    }, onError: (e) => debugPrint("Stream All Users Error: $e"));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _phoneController.dispose();
    _medicalLinkController.dispose();
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

  String _formatDate(DateTime d) => "${d.day}/${d.month}/${d.year + 543}";

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

  bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isHalfDayActive =>
      _isHalfDay && _isSameCalendarDay(_startDate, _endDate);

  bool get _isMaternityLeave =>
      (_selectedLeaveType ?? '').toString().contains('คลอด');

  DateTime _maternityEndDateFrom(DateTime start) {
    final first = DateTime(start.year, start.month, start.day);
    return first.add(const Duration(days: 89));
  }

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
      if (_isMaternityLeave) {
        _isHalfDay = false;
        _endDate = _maternityEndDateFrom(date);
        return;
      }
      if (_isHalfDay || _endDate.isBefore(_startDate)) {
        _endDate = date;
      }
    });
  }

  void _setEndDate(DateTime date) {
    setState(() {
      if (_isMaternityLeave) {
        _isHalfDay = false;
        _endDate = _maternityEndDateFrom(_startDate);
        return;
      }
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

      final String? choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                  leading: const Icon(Icons.image_rounded, color: mobileAccent),
                  title: Text('เลือกรูปภาพ (แนะนำ - เร็วที่สุด)',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, 'img')),
              ListTile(
                  leading:
                      const Icon(Icons.file_present_rounded, color: mobileAccent),
                  title: Text('เลือกไฟล์ PDF / อื่นๆ',
                      style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(ctx, 'file')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (choice == 'img') {
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1200,
          imageQuality: 50,
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
    HapticFeedback.mediumImpact();
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
        if (_editRequestId != null && leave['requestId'] == _editRequestId) {
          continue;
        }

        final String status = (leave['status'] ?? '').toString();
        if (status.contains('รอ') ||
            status.contains('อนุญาต') ||
            status.contains('ส่งใบ')) {
          final DateTime? existingStart = _parseThaiDate(leave['startDate']);
          final DateTime? existingEnd = _parseThaiDate(leave['endDate']);

          if (existingStart != null && existingEnd != null) {
            if (_hasLeaveConflict(leave, newStart, newEnd)) {
              _showError(
                  'ไม่สามารถส่งได้: มีการลาในช่วงวันที่นี้อยู่แล้ว (${leave['startDate']} - ${leave['endDate']})');
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
        if (!mounted) return;
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
        'year': _fiscalYearText,
      };

      if (_editRequestId != null) {
        await _firebaseService.updateLeaveRequest(_editRequestId!, data);
      } else {
        data['fullName'] = _selectedUser!['fullName'];
        data['position'] = _selectedUser!['position'];
        data['academicStanding'] = _selectedUser!['academicStanding'];
        data['department'] = _selectedUser!['department'] ?? '';
        data['createdAt'] = DateTime.now().toIso8601String();

        await _firebaseService.submitLeaveRequest(data);
        _firebaseService.sendLineNotification(data).catchError((Object e) {
          debugPrint("Submit notify error: $e");
          return false;
        });
      }

      if (mounted) {
        _resetForm();
        _showSuccess(_editRequestId != null
            ? "อัปเดตข้อมูลใบลาสำเร็จเรียบร้อยแล้วครับ"
            : "ส่งใบลาสำเร็จเรียบร้อยแล้วครับ");
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 500), curve: Curves.easeOut);

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
      barrierColor: Colors.black.withValues(alpha: 0.4),
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
                    fontWeight: FontWeight.bold, color: mobileAccent)),
          )
        ],
      ),
    );
  }

  static String _shortThaiDate(DateTime d) {
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year + 543}';
  }

  Future<void> _openPreview() async {
    if (_openingPreview) return;
    HapticFeedback.lightImpact();
    final user = _selectedUser ?? const <String, dynamic>{};
    final fullName = (user['fullName'] ?? '').toString();
    setState(() => _openingPreview = true);
    final history = fullName.isEmpty
        ? <Map<String, dynamic>>[]
        : await _firebaseService.getMyLeaveRequestsFromSupabase(fullName);
    if (!mounted) return;
    setState(() => _openingPreview = false);
    final leaf = <String, dynamic>{
      if (_editRequestId != null) 'requestId': _editRequestId,
      'fullName': fullName,
      'position': user['position'] ?? '',
      'academicStanding': user['academicStanding'] ?? '',
      'leaveType': _selectedLeaveType ?? '',
      'reason': _reasonController.text,
      'startDate': _formatDate(_startDate),
      'endDate': _formatDate(_endDate),
      'totalDays': _calculatedTotalDays(),
      'phone': _phoneController.text,
      'year': _fiscalYearText,
      'timestamp':
          widget.initialData?['timestamp'] ?? DateTime.now().toIso8601String(),
    };
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LeaveFormPage(
        leaf: leaf,
        allUsers: _allUsers,
        allLeaveRequests: history,
        leaveTypeNames: _leaveTypeNames,
      ),
    ));
  }

  String get _selectedUserSummary {
    String valueOf(List<String> keys) {
      for (final key in keys) {
        final value = (_selectedUser?[key] ?? '').toString().trim();
        if (value.isNotEmpty &&
            value != '-' &&
            value != '---เลือก---' &&
            !value.contains('ไม่มีวิทยฐานะ')) {
          return value;
        }
      }
      return '';
    }

    final parts = [
      valueOf(['position', 'ตำแหน่ง']),
      valueOf(['academicStanding', 'วิทยฐานะ']),
      valueOf(['department', 'กลุ่มสาระการเรียนรู้', 'กลุ่มสาระ']),
    ].where((part) => part.isNotEmpty).toList();

    return parts.isEmpty
        ? 'ยังไม่ได้ระบุตำแหน่ง / กลุ่มสาระ'
        : parts.join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = LeavePermissions.canFileForOthers(_userRole);

    return Material(
      color: mobileBg,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── หมวดที่ 1: ผู้ยื่นและประเภทการลา ──
                  const MobileSectionHeader(
                    icon: Icons.person_pin_rounded,
                    title: '1. ข้อมูลผู้ยื่นและประเภทการลา',
                  ),
                  _categoryCard(
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
                                    .where(StaffStatus.isListed)
                                    .map((u) => u['fullName']?.toString() ?? '')
                                    .toList(),
                                (val) => _fetchUserData(val),
                                initialValue:
                                    _selectedUser?['fullName']?.toString(),
                                enabled: _editRequestId == null,
                              ),
                        if (_selectedUser != null) ...[
                          const SizedBox(height: 10),
                          _buildUserInfoTag(),
                        ],
                      ] else ...[
                        _buildApplicantSummaryCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildFieldLabel("ประเภทการลา"),
                      _buildDropdownField(
                        _selectedLeaveType ?? '---เลือก---',
                        ["---เลือก---", ..._leaveTypeNames],
                        (val) => setState(() {
                          _selectedLeaveType = val;
                          if (_isMaternityLeave) {
                            _isHalfDay = false;
                            _endDate = _maternityEndDateFrom(_startDate);
                          }
                        }),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── หมวดที่ 2: ช่วงเวลาและจำนวนวันลา ──
                  MobileSectionHeader(
                    icon: Icons.date_range_rounded,
                    title: '2. ช่วงเวลาและจำนวนวันลา',
                    trailingText: 'ปีงบ $_fiscalYearText',
                    iconColor: const Color(0xFF0284C7),
                  ),
                  _categoryCard(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel("ตั้งแต่วันที่"),
                                _buildDatePickerField(
                                  _shortThaiDate(_startDate),
                                  () => _showPremiumDatePicker(
                                      _startDate, _setStartDate),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel("ถึงวันที่"),
                                _buildDatePickerField(
                                  _shortThaiDate(_endDate),
                                  () => _showPremiumDatePicker(
                                      _endDate, _setEndDate),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildHalfDaySelector(),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.event_available_rounded,
                                  color: Color(0xFF15803D), size: 19),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "รวมจำนวนวันที่ลา",
                                style: GoogleFonts.sarabun(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ),
                            Text(
                              "${_formatLeaveDays(_calculatedTotalDays())} วัน",
                              style: GoogleFonts.sarabun(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── หมวดที่ 3: เหตุผลและเอกสารแนบ ──
                  const MobileSectionHeader(
                    icon: Icons.edit_note_rounded,
                    title: '3. เหตุผลและเอกสารแนบ',
                    iconColor: Color(0xFF7C3AED),
                  ),
                  _categoryCard(
                    children: [
                      _buildFieldLabel("เหตุผลการลา"),
                      _buildTextField(
                        _reasonController,
                        Icons.edit_note_rounded,
                        maxLines: 3,
                        hint: "ระบุเหตุผลการลา...",
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel("เบอร์โทรศัพท์ที่ติดต่อได้"),
                      _buildTextField(
                        _phoneController,
                        Icons.phone_rounded,
                        hint: "08x-xxxxxxx",
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel("แนบใบรับรองแพทย์ (ถ้ามี)"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              _medicalLinkController,
                              Icons.link_rounded,
                              hint: "วางลิงก์หรือกดปุ่มแนบไฟล์...",
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: _pickAndUploadMedicalCertificate,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 50,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.upload_file_rounded,
                                      color: mobileAccent, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    'แนบไฟล์',
                                    style: GoogleFonts.sarabun(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: mobileAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_attachedFileName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Color(0xFF16A34A), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "ไฟล์แนบ: $_attachedFileName",
                                    style: GoogleFonts.sarabun(
                                      color: const Color(0xFF15803D),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _attachedFileName = null),
                                  child: const Icon(Icons.close_rounded,
                                      color: Color(0xFF16A34A), size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── แถบปุ่มด้านล่างติดจอ (ดูตัวอย่าง + ส่งใบลา) ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: mobileLine)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mobileAccent,
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _openingPreview ? null : _openPreview,
                      icon: const Icon(Icons.description_outlined, size: 19),
                      label: Text(
                        'ดูตัวอย่าง',
                        style: GoogleFonts.sarabun(
                            fontSize: 14.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: mobileAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSubmitting ? null : _submitForm,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5))
                          : Icon(
                              _editRequestId != null
                                  ? Icons.save_rounded
                                  : Icons.send_rounded,
                              size: 19),
                      label: Text(
                        _editRequestId != null ? 'บันทึกการแก้ไข' : 'ส่งใบลา',
                        style: GoogleFonts.sarabun(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: mobileLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildApplicantSummaryCard() {
    if (_selectedUser == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mobileLine),
        ),
        child: Row(
          children: [
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text("กำลังดึงข้อมูลผู้ยื่น...",
                style: GoogleFonts.sarabun(color: mobileMuted)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mobileLine),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            imageUrl: _selectedUser?['profileImage'],
            size: 42,
            name: (_selectedUser?['fullName'] ?? '?').toString(),
            backgroundColor: const Color(0xFFDBEAFE),
            foregroundColor: mobileAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedUser?['fullName'] ?? '-',
                  style: GoogleFonts.sarabun(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: mobileInk,
                  ),
                ),
                Text(
                  _selectedUserSummary,
                  style: GoogleFonts.sarabun(
                    fontSize: 12.5,
                    color: mobileMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHalfDaySelector() {
    final selectedMode = _isHalfDayActive ? _halfDayPeriod : 'full';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('ช่วงเวลาการลา'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildLeaveDurationButton('full', 'เต็มวัน', selectedMode),
              _buildLeaveDurationButton('morning', 'ครึ่งวันเช้า', selectedMode),
              _buildLeaveDurationButton(
                  'afternoon', 'ครึ่งวันบ่าย', selectedMode),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveDurationButton(
      String value, String label, String selectedMode) {
    final selected = selectedMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_isMaternityLeave) {
              _isHalfDay = false;
              _endDate = _maternityEndDateFrom(_startDate);
              return;
            }
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
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sarabun(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? mobileAccent : mobileMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 17, color: mobileAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedUserSummary,
              style: GoogleFonts.sarabun(
                fontSize: 12.5,
                color: const Color(0xFF1E40AF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: GoogleFonts.sarabun(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: mobileMuted,
          ),
        ),
      );

  Widget _buildTextField(
    TextEditingController ctrl,
    IconData icon, {
    String hint = '',
    int maxLines = 1,
    FocusNode? focusNode,
    bool enabled = true,
    Widget? suffixIcon,
  }) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        focusNode: focusNode,
        enabled: enabled,
        style: GoogleFonts.sarabun(
            fontSize: 14.5,
            color: enabled ? mobileInk : Colors.black54,
            fontWeight: FontWeight.w500),
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
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: mobileLine)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: mobileLine)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: mobileLine)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: mobileAccent, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      );

  Widget _buildDropdownField(
          String value, List<String> items, Function(String) onChanged) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: mobileLine),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: mobileMuted),
            style: GoogleFonts.sarabun(
                fontSize: 14.5,
                color: mobileInk,
                fontWeight: FontWeight.w600),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: (v) => onChanged(v!),
          ),
        ),
      );

  Widget _buildDatePickerField(String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mobileLine),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: mobileAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.sarabun(
                    fontSize: 14,
                    color: mobileInk,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSearchableDropdown(
    List<String> options,
    Function(String) onSelected, {
    String? initialValue,
    bool enabled = true,
  }) =>
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
          Icons.person_search_rounded,
          hint: "ค้นหาชื่อบุคลากร...",
          focusNode: focus,
          enabled: enabled,
          suffixIcon: Icon(
            enabled ? Icons.arrow_drop_down : Icons.lock_outline,
            color: mobileMuted,
          ),
        ),
      );
}
