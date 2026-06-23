import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:js_util' as js_util;
// ignore: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:html' as html;
import 'package:rxdart/rxdart.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseService {
  // 🛡️ รหัสลับสำหรับคุยกับ Google Apps Script (Phase 4) 🥇🏆
  static const String secretKey = "RBP_SECURE_2026";

  // 📲 URL ของระบบหลังบ้านตัวหลัก (All-in-One Secure Bridge) 🥇🏆🏎️
  static const String appsScriptUrl =
      'https://script.google.com/macros/s/AKfycbxKBXqO90MOsd-MizfsZ-VvmeUnKcx-Phnoi6By36EnP1dgsdCDZ3Q26ch67QfPySyZ/exec';
  static const String driveProfileFolderId =
      '1Gor8_V0nRjHU5qLYGke4EE86L1c2dB2k';
  static const String driveLeaveFolderId = '1VAtGdnzC18-ixgJomFUsSAKqgZNQ782S';

  // 🔥 แคชอินสแตนซ์ของ DB เพื่อความรวดเร็วครับ 🥇🏎️
  FirebaseFirestore? _firestoreInstance;

  FirebaseFirestore get _db {
    _firestoreInstance ??= FirebaseFirestore.instanceFor(
        app: Firebase.app(), databaseId: 'school');
    return _firestoreInstance!;
  }

  FirebaseFirestore get db => _db;

  static bool isLikelyAppsScriptWebAppUrl(String value) {
    return RegExp(r'^https:\/\/script\.google\.com\/macros\/s\/[^\s\/]+\/exec$')
        .hasMatch(value.trim());
  }

  Future<Map<String, dynamic>> getLineMessagingSettings() async {
    final snap = await db.collection('Settings').doc('line_messaging').get();
    return snap.data() ?? <String, dynamic>{};
  }

  String _appsScriptUrlFromSettings(Map<String, dynamic> settings) {
    final savedUrl = (settings['webhookUrl'] ?? '').toString().trim();
    return isLikelyAppsScriptWebAppUrl(savedUrl) ? savedUrl : appsScriptUrl;
  }

  Future<String> getAppsScriptUrl() async {
    return _appsScriptUrlFromSettings(await getLineMessagingSettings());
  }

  String _buildAppsScriptGetUrl(
    String baseUrl,
    Map<String, String> queryParameters,
  ) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...queryParameters,
    }).toString();
  }

  // 🛡️ ดึง UID ของผู้ใช้งานปัจจุบันครับ 🥇🏆
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

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

  // 🛡️ ฟังก์ชันผูก UID เข้ากับชื่อครู และซิงค์สิทธิ์ไปยัง UserRoles (Phase 3 Fix) 🥇🏆
  Future<bool> linkTeacherWithUid(
    String fullName,
    String uid, {
    String? teacherDocId,
    String? username,
    String? preferredRole,
  }) async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? teacherDoc;

      if (teacherDocId != null && teacherDocId.trim().isNotEmpty) {
        final snap =
            await _db.collection('Teachers').doc(teacherDocId.trim()).get();
        if (snap.exists) {
          teacherDoc = snap;
        }
      }

      if (teacherDoc == null &&
          username != null &&
          username.trim().isNotEmpty) {
        final query = await _db
            .collection('Teachers')
            .where('username', isEqualTo: username.trim())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) teacherDoc = query.docs.first;
      }

      if (teacherDoc == null && fullName.trim().isNotEmpty) {
        final query = await _db
            .collection('Teachers')
            .where('fullName', isEqualTo: fullName.trim())
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) teacherDoc = query.docs.first;
      }

      if (teacherDoc != null) {
        final docData = teacherDoc.data() ?? <String, dynamic>{};
        final role = _resolveEffectiveRole([
          docData['role'],
          docData['permission'],
          preferredRole,
        ]);
        final resolvedFullName =
            (docData['fullName'] ?? docData['name'] ?? fullName).toString();

        // 1. อัปเดตที่ห้อง Teachers เดิม
        await _db.collection('Teachers').doc(teacherDoc.id).update({
          'firebase_uid': uid,
          'role': role,
          'permission': role,
          'lastSyncAt': FieldValue.serverTimestamp(),
        });

        // 2. 🛡️ ซิงค์กุญแจสำคัญไปที่ห้อง UserRoles โดยใช้ UID เป็นชื่อเอกสาร (หัวใจของความปลอดภัยครับ) 🥇🏆
        await _db.collection('UserRoles').doc(uid).set({
          'role': role,
          'permission': role,
          'fullName': resolvedFullName,
          'teacherDocId': teacherDoc.id,
          'lastSyncAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint(
            "Successfully linked UID and Sync Roles for: $resolvedFullName");
        return true;
      }
    } catch (e) {
      debugPrint("Error linking UID and Roles: $e");
    }
    return false;
  }

  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _db.collection('Teachers').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();

        // 🛡️ ทำความสะอาดข้อมูลก่อนส่งออกไป (ป้องกัน JSON Error ทั่วทั้งแอปครับ) 🥇🏆
        final sanitized = Map<String, dynamic>.from(data);
        sanitized.forEach((key, value) {
          if (value is Timestamp)
            sanitized[key] = value.toDate().toIso8601String();
        });

        return {
          ...sanitized,
          'id': doc.id,
          'fullName': sanitized['fullName'] ??
              sanitized['name'] ??
              sanitized['Name'] ??
              doc.id,
          'academicStanding': sanitized['academicStanding'] ??
              sanitized['academic'] ??
              sanitized['วิทยฐานะ'] ??
              '',
        };
      }).toList();

      // 🥇 เรียงลำดับชื่อด้วยฝั่งแอปพลิเคชัน ป้องกันปัญหาคนที่มีแค่ช่อง name แต่ไม่มี fullName หายไปจากจอครับ! 🏆
      list.sort((a, b) => (a['fullName'] ?? '')
          .toString()
          .compareTo((b['fullName'] ?? '').toString()));
      return list;
    });
  }

  // ดึงรายชื่อครูแบบครั้งเดียวเพื่อความแม่นยำในการเริ่มต้นหน้าจอครับ 🏆
  Future<List<Map<String, dynamic>>> getUsers() async {
    final snapshot = await _db.collection('Teachers').get();
    final list = snapshot.docs.map((doc) {
      final data = doc.data();

      // 🛡️ ทำความสะอาดข้อมูลก่อนส่งออกไป 🥇🏆
      final sanitized = Map<String, dynamic>.from(data);
      sanitized.forEach((key, value) {
        if (value is Timestamp)
          sanitized[key] = value.toDate().toIso8601String();
      });

      return {
        'id': doc.id,
        ...sanitized,
        'fullName': sanitized['fullName'] ??
            sanitized['name'] ??
            sanitized['Name'] ??
            doc.id,
        'academicStanding': sanitized['academicStanding'] ??
            sanitized['academic'] ??
            sanitized['วิทยฐานะ'] ??
            '',
      };
    }).toList();

    // 🥇 เรียงลำดับฝั่งแอปพลิเคชันครับ 🏆
    list.sort((a, b) => (a['fullName'] ?? '')
        .toString()
        .compareTo((b['fullName'] ?? '').toString()));
    return list;
  }

  // เพิ่มรายชื่อครูคนใหม่ลงฐานข้อมูลครับ 🏎️🏆
  Future<void> addUser(Map<String, dynamic> data) async {
    await _db.collection('Teachers').add(data);
  }

  // แก้ไขข้อมูลครูครับ 🏎️🏆
  Future<void> updateUser(String docId, Map<String, dynamic> data) async {
    await _db.collection('Teachers').doc(docId).update(data);
  }

  // ลบข้อมูลครูครับ 🏎️🏆
  Future<void> deleteUser(String docId) async {
    await _db.collection('Teachers').doc(docId).delete();
  }

  // 🛠️ ฟังก์ชันช่วยหาฟิลด์ที่เป็นค่า String (หาฟิลด์ Value/Name แบบไม่สนตัวเล็กตัวใหญ่) 🥇🏆
  String _extractValue(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return doc.id;

    // 1. ลองหาฟิลด์ที่ชื่อตรงกับที่ต้องการก่อน (Value, Name, name, Type Name แบบไม่สน Case)
    for (String key in data.keys) {
      final k = key.toLowerCase();
      if (k == 'value' ||
          k == 'name' ||
          k.contains('name') ||
          k.contains('value')) {
        final val = data[key]?.toString() ?? '';
        final cleanVal = val.trim().toUpperCase();
        if (val.trim().isNotEmpty &&
            cleanVal != 'TRUE' &&
            cleanVal != 'FALSE') {
          return val.trim();
        }
      }
    }

    // 2. ถ้าไม่เจอ ให้เลือกฟิลด์แรกที่เป็น String และชื่อไม่มีคำว่า ID
    for (var entry in data.entries) {
      if (entry.value is String && !entry.key.toUpperCase().contains('ID')) {
        final val = entry.value.toString().trim();
        if (val.isNotEmpty &&
            val.toUpperCase() != 'TRUE' &&
            val.toUpperCase() != 'FALSE') {
          return val;
        }
      }
    }

    return doc.id;
  }

  // ดึงตำแหน่งงานบริหารจากฐานข้อมูลครับ 🥇🏆
  Future<List<String>> getAdminRoles() async {
    final snapshot = await _db.collection('AdminRoles').get();
    final List<String> roles = snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(); // ป้องกันซ้ำ
    if (!roles.contains('ไม่มีตำแหน่งบริหาร'))
      roles.insert(0, 'ไม่มีตำแหน่งบริหาร');
    return roles;
  }

  // ดึงตำแหน่งงานทั่วไปครับ 🥇🏆
  Future<List<String>> getPositions() async {
    final snapshot = await _db.collection('Positions').get();
    return snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(); // ป้องกันซ้ำ
  }

  // ดึงสิทธิ์การเข้าถึง (Roles) ครับ 🥇🏆
  Future<List<String>> getPermissions() async {
    final snapshot = await _db
        .collection('Roles')
        .get(); // เปลี่ยนเป็น Roles ตามที่คุณครูแนะนำครับ
    return snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty && s != 'TRUE' && s != 'FALSE')
        .toSet()
        .toList();
  }

  // ดึงวิทยฐานนะครับ 🥇🏆
  Future<List<String>> getAcademics() async {
    final snapshot = await _db.collection('Academics').get();
    return snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(); // ป้องกันซ้ำ
  }

  Future<List<String>> getLeaveTypes() async {
    final snapshot = await _db.collection('LeaveTypes').get();
    return snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(); // ป้องกันซ้ำ
  }

  // ดึงกลุ่มสาระการเรียนรู้จากฐานข้อมูล Departments ครับ 🕵️‍♂️🏎️🏆
  Future<List<String>> getDepartments() async {
    final snapshot = await _db.collection('Departments').get();
    return snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(); // ป้องกันซ้ำ
  }

  // ดึงรายการวิชาที่สอนจากฐานข้อมูล Subjects ครับ 🕵️‍♂️🏎️🏆
  Future<List<String>> getSubjects() async {
    final snapshot = await _db.collection('Subjects').get();
    return snapshot.docs
        .map((doc) => _extractValue(doc))
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList(); // ป้องกันซ้ำ
  }

  // 📅 ระบบจัดการรอบงบประมาณ (Fiscal Rounds) 🥇🏆
  Stream<List<Map<String, dynamic>>> getFiscalRoundsStream() {
    return _db
        .collection('FiscalRounds')
        .orderBy('year', descending: true)
        .orderBy('round', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    });
  }

  Future<void> addFiscalRound(Map<String, dynamic> data) async {
    await _db.collection('FiscalRounds').add({
      ...data,
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteFiscalRound(String docId) async {
    await _db.collection('FiscalRounds').doc(docId).delete();
  }

  // ดึงรายการรอบงบประมาณที่ตรงกับปฏิทินปัจจุบัน (Auto-match) 🥇🏎️🏆
  Future<Map<String, dynamic>?> getActiveFiscalRound() async {
    try {
      final snapshot = await _db
          .collection('FiscalRounds')
          .orderBy('year', descending: true)
          .orderBy('round', descending: true)
          .get();
      final now = DateTime.now();
      // แปลงปีเป็น พ.ศ. เพื่อเทียบกับข้อมูลในระบบครับ 🇹🇭
      final todayStr = "${now.day}/${now.month}/${now.year + 543}";

      for (var doc in snapshot.docs) {
        final r = doc.data();
        if (isDateInRange(todayStr, r['startDate'] ?? '', r['endDate'] ?? '')) {
          return {...r, 'id': doc.id, 'isAutoSelected': true};
        }
      }
    } catch (e) {
      debugPrint("Error in getActiveFiscalRound: $e");
    }
    return null;
  }

  // ดึงรายการรอบงบประมาณทั้งหมดครับ 🕵️‍♂️🏎️🏆
  Future<List<Map<String, dynamic>>> getFiscalRounds() async {
    try {
      final snapshot = await _db
          .collection('FiscalRounds')
          .orderBy('year', descending: true)
          .get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      debugPrint("Error in getFiscalRounds: $e");
      return [];
    }
  }

  // 🛠️ ฟังก์ชันช่วยตรวจสอบว่าวันที่อยู่ในช่วงงบประมาณหรือไม่ (รูปแบบ วว/ดด/ปปปป) 🥇
  static bool isDateInRange(String dateStr, String startStr, String endStr) {
    try {
      if (dateStr.isEmpty || startStr.isEmpty || endStr.isEmpty) return false;

      DateTime parse(String s) {
        // 🕵️‍♂️ ตัดช่องว่างและจัดการรูปแบบที่ซับซ้อนครับ 🥇🏆
        final cleanS = s.trim().replaceAll(' ', '');
        final p = cleanS.split('/');
        if (p.length != 3) throw Exception('Invalid date format: $s');

        int year = int.parse(p[2]);
        // 🛡️ ระบบตรวจจับปีอัตโนมัติ: ถ้า < 2400 ให้ถือว่าเป็น ค.ศ. แล้วบวก 543 เพื่อเทียบเป็น พ.ศ. ทั้งหมดครับ 🕵️‍♂️🥇
        if (year < 2400) year += 543;

        return DateTime(year, int.parse(p[1]), int.parse(p[0]));
      }

      final date = parse(dateStr);
      final start = parse(startStr);
      final end = parse(endStr);

      // 🛡️ ปรับเวลาเป็น 00:00 - 23:59 เพื่อความแม่นยำในการเปรียบเทียบข้ามวันครับ 🥇🏆
      final d = DateTime(date.year, date.month, date.day);
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);

      return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
          (d.isAtSameMomentAs(e) || d.isBefore(e));
    } catch (e) {
      debugPrint(
          "isDateInRange Error: $e (input: $dateStr, range: $startStr - $endStr)");
      return false;
    }
  }

  // 🛠️ ฟังก์ชันพาร์สวันที่แบบรวดเร็ว เพื่อลดการสร้าง Object ซ้ำซ้อนครับ 🏎️🏆
  static DateTime? parseFast(String s) {
    try {
      final cleanS = s.trim().replaceAll(' ', '');
      final p = cleanS.split('/');
      if (p.length != 3) return null;
      int year = int.parse(p[2]);
      if (year < 2400) year += 543;
      return DateTime(year, int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return null;
    }
  }

  static DateTime? _parseLeaveDateValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? leaveCreatedDate(Map<String, dynamic> leave) {
    return _parseLeaveDateValue(leave['createdAt']);
  }

  static int _leaveStatusWeight(String status) {
    if (status.contains('รอ') || status.contains('พิจารณา')) return 0;
    if (status.contains('ส่งใบ') ||
        status.contains('อนุมัติ') ||
        status.contains('อนุญาต')) {
      return 1;
    }
    if (status.contains('ยังไม่ส่ง') || status.contains('ไม่อนุญาต')) return 2;
    return 3;
  }

  static int compareLeaveRecency(
      Map<String, dynamic> a, Map<String, dynamic> b) {
    final dateA = leaveCreatedDate(a);
    final dateB = leaveCreatedDate(b);
    if (dateA != null && dateB != null) {
      final dateCompare = dateB.compareTo(dateA);
      if (dateCompare != 0) return dateCompare;
    } else if (dateA != null) {
      return -1;
    } else if (dateB != null) {
      return 1;
    }

    final statusCompare = _leaveStatusWeight((a['status'] ?? '').toString())
        .compareTo(_leaveStatusWeight((b['status'] ?? '').toString()));
    if (statusCompare != 0) return statusCompare;

    return (b['requestId'] ?? b['id'] ?? '')
        .toString()
        .compareTo((a['requestId'] ?? a['id'] ?? '').toString());
  }

  static String formatLeaveDayCount(dynamic value) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (number == null) return '-';
    return number % 1 == 0 ? number.toInt().toString() : number.toString();
  }

  static bool isHalfDayLeave(Map<String, dynamic> leave) {
    final raw = leave['isHalfDay'];
    if (raw is bool) return raw;
    return raw?.toString().toLowerCase() == 'true';
  }

  static String halfDayPeriodText(dynamic value) {
    final period = value?.toString().toLowerCase() ?? '';
    if (period == 'morning') return 'ครึ่งเช้า';
    if (period == 'afternoon') return 'ครึ่งบ่าย';
    return 'ครึ่งวัน';
  }

  static String leaveTypeWithHalfDay(Map<String, dynamic> leave) {
    final type = (leave['leaveType'] ?? 'ไม่ระบุ').toString();
    if (!isHalfDayLeave(leave)) return type;
    return '$type (${halfDayPeriodText(leave['halfDayPeriod'])})';
  }

  // 🛠️ รวม Stream ของรอบงบประมาณ ข้อมูลใบลา และประเภทการลาเข้าด้วยกัน เพื่อลดความซับซ้อนของ UI ครับ 🥇🏆🏎️
  Stream<Map<String, dynamic>> getDashboardDataStream() {
    return CombineLatestStream.combine3(
      getFiscalRoundsStream(),
      getLeaveRequestsStream(),
      getLeaveTypesStream(),
      (List<Map<String, dynamic>> rounds, List<Map<String, dynamic>> leaves,
          List<Map<String, dynamic>> types) {
        return {
          'rounds': rounds,
          'allLeaves': leaves,
          'leaveTypes': types,
        };
      },
    );
  }

  // ดึงประเภทการลาทั้งหมดจากฐานข้อมูลครับ 🕵️‍♂️🏎️🏆
  Stream<List<Map<String, dynamic>>> getLeaveTypesStream() {
    return _db
        .collection('LeaveTypes')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                  'Value': _extractValue(
                      doc), // 🛡️ สกัดค่าออกมาให้เป็นมาตรฐาน 'Value' ครับ 🥇🏆
                })
            .toList());
  }

  // ดึงประวัติการลาของตัวเองแบบเรียลไทม์ครับ 🕵️‍♂️🏎️🏆
  Stream<List<Map<String, dynamic>>> getLeaveRequestsStream() {
    return _db.collection('Leaves').snapshots().map((snapshot) => snapshot.docs
        .map((doc) => {...doc.data(), 'requestId': doc.id})
        .toList()
      ..sort(FirebaseService.compareLeaveRecency));
  }

  Future<List<Map<String, dynamic>>> getLeaveRequests() async {
    final snapshot = await _db.collection('Leaves').get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'requestId': doc.id})
        .toList()
      ..sort(FirebaseService.compareLeaveRecency);
  }

  Stream<List<Map<String, dynamic>>> getMyLeaveRequestsStream(String fullName) {
    return _db
        .collection('Leaves')
        .where('fullName', isEqualTo: fullName)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'requestId': doc.id})
            .toList()
          ..sort(FirebaseService.compareLeaveRecency));
  }

  Future<List<Map<String, dynamic>>> getMyLeaveRequests(String fullName) async {
    final snapshot = await _db
        .collection('Leaves')
        .where('fullName', isEqualTo: fullName)
        .get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'requestId': doc.id})
        .toList()
      ..sort(FirebaseService.compareLeaveRecency);
  }

  // ดึงประวัติการลา "ล่าสุด" ของครูเพื่อไปแสดงในฟอร์มครับ 🕵️‍♂️🏎️🏆
  Future<Map<String, dynamic>?> getLastLeaveRequest(String fullName) async {
    final snapshot = await _db
        .collection('Leaves')
        .where('fullName', isEqualTo: fullName)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final leaves = snapshot.docs
          .map((doc) => {...doc.data(), 'requestId': doc.id})
          .toList()
        ..sort(FirebaseService.compareLeaveRecency);
      return leaves.first;
    }
    return null;
  }

  // ส่งใบลาเข้าระบบครับ 🏎️🏁
  Future<void> submitLeaveRequest(Map<String, dynamic> data) async {
    final String docId = 'LV-${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('Leaves').doc(docId).set({
      ...data,
      'uid':
          currentUid, // 🛡️ บันทึกรหัสเจ้าของใบลาเพื่อความปลอดภัยสูงสุด (Phase 3) 🥇🏆
      'requestId': docId, // ✅ บันทึก ID ลงในข้อมูลด้วยเพื่อความสะดวกครับ
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'รอพิจารณา', // สถานะตั้งต้นครับ 🥇
    });
  }

  // แก้ไขใบลาครับ 🏎️🏁
  Future<void> updateLeaveRequest(
      String requestId, Map<String, dynamic> data) async {
    await _db.collection('Leaves').doc(requestId).update({
      ...data,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 🔥 ลบไฟล์ใน Google Drive ผ่าน Apps Script ครับ 🥇🏆🏎️
  Future<Map<String, dynamic>> uploadDriveFile({
    required String fileData,
    required String fileName,
    required String mimeType,
    required String folderType,
    String? folderId,
  }) async {
    final bridgeUrl = await getAppsScriptUrl();
    final response = await http
        .post(
          Uri.parse(bridgeUrl),
          body: jsonEncode({
            'action': 'upload',
            'folderType': folderType,
            'folderId': folderId ??
                (folderType == 'profile'
                    ? driveProfileFolderId
                    : driveLeaveFolderId),
            'fileName': fileName,
            'name': fileName,
            'mimeType': mimeType,
            'file64': _stripDataUrlPrefix(fileData),
            'secretKey': secretKey,
          }),
        )
        .timeout(const Duration(minutes: 2));

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Drive upload failed with status ${response.statusCode}');
    }

    final resData = jsonDecode(response.body) as Map<String, dynamic>;
    if (resData['status'] != 'success' ||
        (resData['url']?.toString().isEmpty ?? true)) {
      throw Exception(resData['message'] ?? 'Drive upload failed');
    }

    return resData;
  }

  String _stripDataUrlPrefix(String value) {
    const marker = 'base64,';
    final index = value.indexOf(marker);
    if (index == -1) return value;
    return value.substring(index + marker.length);
  }

  Future<bool> deleteDriveFileStrict(String? fileUrlOrId) async {
    final source = fileUrlOrId?.trim() ?? '';
    if (source.isEmpty) return false;

    final fileId = _extractDriveFileId(source);
    if (fileId == null) {
      var checkSource = source.toLowerCase();
      try {
        checkSource = Uri.decodeFull(checkSource);
      } catch (_) {
        // Keep the original value when it is not URI-encoded.
      }

      final looksLikeDriveUrl = checkSource.contains('drive.google.com') ||
          checkSource.contains('googleusercontent.com');
      if (looksLikeDriveUrl) {
        throw Exception('Cannot find Google Drive file ID from URL');
      }
      return false;
    }

    final bridgeUrl = await getAppsScriptUrl();
    final response = await http
        .post(
          Uri.parse(bridgeUrl),
          body: jsonEncode({
            'action': 'delete',
            'fileId': fileId,
            'secretKey': secretKey,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Drive delete failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Drive delete returned an invalid response');
    }

    final resData = Map<String, dynamic>.from(decoded);
    if (resData['status'] != 'success') {
      throw Exception(resData['message'] ?? 'Drive delete failed');
    }

    debugPrint("Drive Delete Result: ${resData['status']} ($fileId)");
    return true;
  }

  String? _extractDriveFileId(String value) {
    var source = value.trim();
    if (source.isEmpty) return null;

    final rawId = RegExp(r'^[a-zA-Z0-9_-]{20,}$');
    if (!source.contains('/') &&
        !source.contains('?') &&
        !source.contains('&') &&
        !source.contains('=') &&
        rawId.hasMatch(source)) {
      return source;
    }

    try {
      source = Uri.decodeFull(source);
    } catch (_) {
      // Keep the original value when it is not URI-encoded.
    }

    final uri = Uri.tryParse(source);
    final queryId = uri?.queryParameters['id'];
    if (queryId != null && rawId.hasMatch(queryId)) {
      return queryId;
    }

    final patterns = [
      RegExp(r'/d/([a-zA-Z0-9_-]{20,})'),
      RegExp(r'[?&]id=([a-zA-Z0-9_-]{20,})'),
      RegExp(r'googleusercontent\.com/d/([a-zA-Z0-9_-]{20,})'),
      RegExp(r'id%3D([a-zA-Z0-9_-]{20,})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(source);
      final fileId = match?.group(1);
      if (fileId != null && rawId.hasMatch(fileId)) {
        return fileId;
      }
    }

    return null;
  }

  Future<void> deleteDriveFile(String? fileUrl) async {
    if (fileUrl == null ||
        fileUrl.isEmpty ||
        !fileUrl.contains('drive.google.com')) return;

    final fileId = _extractFileId(fileUrl);
    if (fileId == null) return;

    try {
      final bridgeUrl = await getAppsScriptUrl();
      final response = await http.post(
        Uri.parse(bridgeUrl),
        body: jsonEncode({
          'action': 'delete',
          'fileId': fileId,
          'secretKey': secretKey, // 🛡️ แนบรหัสลับไปด้วยครับ (Phase 4) 🥇🏆
        }),
      );

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        print("Drive Delete Result: ${resData['status']}");
      }
    } catch (e) {
      print("Error deleting drive file: $e");
    }
  }

  // Helper สำหรับแคะ ID ออกจากลิ้งครับ 🕵️‍♂️
  String? _extractFileId(String url) {
    RegExp regExp = RegExp(r'(?:id=|\/d\/)([a-zA-Z0-9-_]+)');
    Match? match = regExp.firstMatch(url);
    return match?.group(1);
  }

  static String formatThaiDate(dynamic dateValue) {
    if (dateValue == null || dateValue == "") return '-';

    DateTime? date;
    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    } else if (dateValue is DateTime) {
      date = dateValue;
    } else if (dateValue is String) {
      try {
        final parts = dateValue.split('/');
        if (parts.length == 3) {
          int day = int.parse(parts[0]);
          int month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 2100)
            year += 543; // 🛡️ รองรับกรณีฐานข้อมูลดันเก็บเป็นปี ค.ศ. 🥇🏆
          date = DateTime(year - 543, month, day);
        }
      } catch (e) {
        return dateValue;
      }
    }

    if (date == null) return dateValue.toString();

    const months = [
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
    return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
  }

  // 📲 ส่งแจ้งเตือนผ่าน LINE Messaging API แบบปลอดภัยสูง (Phase 4.8 Update) 🥇🏆🏎️
  Future<bool> sendLineNotification(Map<String, dynamic> leaveData) async {
    try {
      debugPrint("🔔 Starting LINE Notification process...");

      // 🕵️‍♂️ 1. ดึงการตั้งค่าทั้งหมดจาก Settings/line_messaging เพื่อความแม่นยำครับ 🥇🏆
      final snap = await db.collection('Settings').doc('line_messaging').get();
      final settings = snap.data() ?? <String, dynamic>{};
      final bridgeUrl = _appsScriptUrlFromSettings(settings);

      String to = (settings['groupId'] ?? '').toString().trim();
      String template = (settings['template'] ?? '').toString();

      if (snap.exists && snap.data() != null) {
        final settings = snap.data()!;
        to = settings['groupId'] ?? '';
        template = settings['template'] ?? '';
        debugPrint(
            "📍 Settings found: GroupID length=${to.length}, Template length=${template.length}");
      } else {
        debugPrint(
            "⚠️ LINE Notification Warning: 'Settings/line_messaging' document not found.");
      }

      // 🛡️ Fallback: ถ้าในใบลาแนบ To มาให้ (เผื่ออนาคต) ให้ใช้ตัวนั้นครับ
      if (to.isEmpty && leaveData['to'] != null) to = leaveData['to'];

      if (to.isEmpty) {
        debugPrint(
            "❌ LINE Notification Aborted: No Group ID found. Please check Line Settings.");
        return false;
      }

      // 🕵️‍♂️ 2. สร้างข้อความ: ใช้ Template จากระบบ หรือใช้แบบ Standard ถ้าไม่ได้ตั้งค่าไว้ครับ 🥇🏆
      String msg = "";
      if (template.isNotEmpty) {
        msg = template
            .replaceAll('{name}',
                (leaveData['fullName'] ?? leaveData['name'] ?? '-').toString())
            .replaceAll('{type}', leaveData['leaveType'] ?? '-')
            .replaceAll('{startDate}', leaveData['startDate'] ?? '-')
            .replaceAll('{endDate}', leaveData['endDate'] ?? '-')
            .replaceAll('{days}', (leaveData['totalDays'] ?? '-').toString())
            .replaceAll('{reason}', leaveData['reason'] ?? '-');
        debugPrint("📝 Message generated from Template");
      } else {
        msg = "📋 แจ้งเตือนผลการพิจารณาใบลา\n"
            "👤 ชื่อ: ${leaveData['fullName'] ?? leaveData['name'] ?? '-'}\n"
            "📅 ประเภทลา: ${leaveData['leaveType'] ?? '-'}\n"
            "🗓️ ตั้งแต่: ${leaveData['startDate'] ?? '-'}\n"
            "🗓️ ถึง: ${leaveData['endDate'] ?? '-'}\n"
            "📆 จำนวน: ${leaveData['totalDays'] ?? '-'} วัน\n"
            "✍️ เหตุผล: ${leaveData['reason'] ?? '-'}";
        debugPrint("📝 Message generated from Standard layout");
      }

      // 📲 3. เตรียมส่งผ่าน Secure Bridge (Apps Script)
      final String url = _buildAppsScriptGetUrl(bridgeUrl, {
        'action': 'line_notification',
        'secretKey': FirebaseService.secretKey,
        'to': to,
        'message': msg,
      });

      if (kIsWeb) {
        // Mobile web/LINE browser can cancel fire-and-forget fetches. Await the
        // browser promise and fall back to an image beacon so the GET is flushed.
        final result = await _getWebJsonp(url);
        if (result['status'] != 'success') {
          debugPrint(
              "⚠️ Web fetch failed, retrying LINE notify via image beacon.");
          debugPrint(
              "LINE Notification failed: ${result['message'] ?? result}");
          return false;
        }
        debugPrint("🚀 LINE Notification triggered via Web Fetch (no-cors)");
        return true;
      } else {
        // 📱 บนมือถือ: ใช้ http.get ปกติ (ขยายเป็น 30 วินาที)
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        debugPrint("📱 LINE Notification status code: ${response.statusCode}");
        return response.statusCode >= 200 && response.statusCode < 400;
      }
    } catch (e) {
      debugPrint("❌ LINE Notification Critical Exception: $e");
      return false;
    }
  }

  Future<bool> _sendWebNoCorsGet(String url) async {
    try {
      final String jsCode = """
        fetch(${jsonEncode(url)}, {
          method: 'GET',
          mode: 'no-cors',
          cache: 'no-store',
          keepalive: true
        }).then(function() {
          return true;
        }).catch(function(e) {
          console.error('Notify Error:', e);
          return false;
        });
      """;
      final result = await js_util
          .promiseToFuture<dynamic>(js.context.callMethod('eval', [jsCode]))
          .timeout(const Duration(seconds: 12), onTimeout: () => false);
      return result == true;
    } catch (e) {
      debugPrint("❌ Web LINE fetch exception: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> _getWebJsonp(String url) async {
    final completer = Completer<String>();
    final callbackName = 'lineCb_${DateTime.now().microsecondsSinceEpoch}';
    final separator = url.contains('?') ? '&' : '?';
    final callbackUrl = '$url${separator}callback=$callbackName';

    // ignore: undefined_function
    js_util.setProperty(
      js.context,
      callbackName,
      js_util.allowInterop((dynamic data) {
        if (!completer.isCompleted) {
          completer.complete(jsonEncode(data ?? {}));
        }
      }),
    );

    final script = html.ScriptElement()
      ..src = callbackUrl
      ..async = true;

    script.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(jsonEncode({
          'status': 'error',
          'message': 'Cannot reach Apps Script',
        }));
      }
    });

    html.document.body?.append(script);

    // ขยายเป็น 45 วินาทีเพื่อให้มั่นใจว่าได้รับคำตอบกลับครับ ⏱️
    Future.delayed(const Duration(seconds: 45), () {
      if (!completer.isCompleted) {
        completer.complete(jsonEncode({
          'status': 'error',
          'message': 'Apps Script timeout',
        }));
      }
    });

    try {
      final result = await completer.future;
      final decoded = jsonDecode(result);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{'status': 'error', 'message': 'Invalid response'};
    } finally {
      js.context.deleteProperty(callbackName);
      script.remove();
    }
  }

  Future<bool> _sendWebImageBeacon(String url) async {
    try {
      final String jsCode = """
        new Promise(function(resolve) {
          var img = new Image();
          var done = false;
          var finish = function(value) {
            if (!done) {
              done = true;
              resolve(value);
            }
          };
          img.onload = function() { finish(true); };
          img.onerror = function() { finish(true); };
          setTimeout(function() { finish(false); }, 12000);
          img.src = ${jsonEncode(url + '&_ts=${DateTime.now().millisecondsSinceEpoch}')};
        });
      """;
      final result = await js_util
          .promiseToFuture<dynamic>(js.context.callMethod('eval', [jsCode]))
          .timeout(const Duration(seconds: 13), onTimeout: () => false);
      return result == true;
    } catch (e) {
      debugPrint("❌ Web LINE image beacon exception: $e");
      return false;
    }
  }

  // 📲 ส่งแจ้งเตือนการ "เปลี่ยนสถานะ" เช่น อนุญาต/ไม่อนุญาต ไปที่ LINE กลุ่มครับ 🥇🏆🏎️
  Future<void> sendLineStatusNotification(
      Map<String, dynamic> leaveData, String newStatus) async {
    try {
      final snap = await db.collection('Settings').doc('line_messaging').get();
      if (!snap.exists) return;

      final settings = snap.data() ?? <String, dynamic>{};
      final bridgeUrl = _appsScriptUrlFromSettings(settings);
      final to = (settings['groupId'] ?? '').toString().trim();
      if (to.isEmpty) return;

      // 📝 สร้างข้อความแจ้งการเปลี่ยนสถานะแบบพรีเมียมครับ 🥇🏆
      String msg = "🔔 อัพเดทสถานะใบลาครับ\n"
          "👤 ชื่อ: ${leaveData['fullName'] ?? '-'}\n"
          "📅 ประเภท: ${leaveData['leaveType'] ?? '-'}\n"
          "📍 สถานะใหม่: $newStatus\n"
          "📆 วันลา: ${leaveData['startDate']} - ${leaveData['endDate']}\n"
          "------------------\n"
          "ตรวจสอบรายละเอียดได้ในระบบครับ";

      final String url = _buildAppsScriptGetUrl(bridgeUrl, {
        'action': 'line_notification',
        'secretKey': FirebaseService.secretKey,
        'to': to,
        'message': msg,
      });

      if (kIsWeb) {
        final String jsCode =
            "fetch(${jsonEncode(url)}, {method:'GET', mode:'no-cors'}).catch(function(e){});";
        js.context.callMethod('eval', [jsCode]);
      } else {
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("❌ Status Notification Error: $e");
    }
  }

  // 👨‍🏫 อัปเดตข้อมูลบุคลากรด้วย ID (เร็วกว่าการหาด้วยชื่อครับ) 🥇🏆🏎️
  Future<void> updateTeacherById(
      String docId, Map<String, dynamic> newData) async {
    await db.collection('Teachers').doc(docId).update(newData);
  }

  // 👨‍🏫 อัปเดตข้อมูลบุคลากร (ใช้สำหรับหน้า Profile มือถือครับ) 🥇🏆🏎️
  Future<void> updateTeacherData(
      String fullName, Map<String, dynamic> newData) async {
    final query = await db
        .collection('Teachers')
        .where('fullName', isEqualTo: fullName)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      await db.collection('Teachers').doc(query.docs.first.id).update(newData);
    }
  }

  // 🕵️‍♂️ ค้นหาข้อมูลบุคลากรด้วย UID (เสถียรกว่าการหาด้วยชื่อครับ) 🥇🏆
  Future<Map<String, dynamic>?> searchTeacherByUid(String uid) async {
    final query = await db
        .collection('Teachers')
        .where('firebase_uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      // 🛡️ ฟอกข้อมูล Timestamp ทุกตัวให้เป็น String ป้องกัน Error JSON (minified:hl) 🥇🏆🏎️
      data.forEach((key, value) {
        if (value is Timestamp) {
          data[key] = value.toDate().toIso8601String();
        }
      });

      return {...data, 'docId': query.docs.first.id};
    }
    return null;
  }

  // 🕵️‍♂️ ค้นหาข้อมูลบุคลากรด้วยชื่อ (ใช้ดึงข้อมูลมาแก้ในโปรไฟล์ครับ)
  Future<Map<String, dynamic>?> searchTeacherByName(String fullName) async {
    final query = await db
        .collection('Teachers')
        .where('fullName', isEqualTo: fullName.trim())
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      // 🛡️ ฟอกข้อมูลให้สะอาด 100% ครับ 🥇🏆
      data.forEach((key, value) {
        if (value is Timestamp) {
          data[key] = value.toDate().toIso8601String();
        }
      });

      return {...data, 'docId': query.docs.first.id};
    }
    return null;
  }

  // 🛡️ บันทึกประวัติการเข้าใช้งาน (Login Logging) 🥇🏆🏎️
  Future<void> logLogin(String username, String fullName, String role) async {
    try {
      await _db.collection('LoginLogs').add({
        'username': username,
        'fullName': fullName,
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'Web' : 'Mobile',
        'userAgent':
            kIsWeb ? js.context['navigator']['userAgent'] : 'Mobile App',
      });
      debugPrint("Login logged successfully for: $username");
    } catch (e) {
      debugPrint("Error logging login: $e");
    }
  }

  // 🛡️ ดึงข้อมูลประวัติการการเข้าใช้งาน (สำหรับ Admin) 🥇🏆
  Stream<List<Map<String, dynamic>>> getLoginLogsStream({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _db.collection('LoginLogs');

    if (startDate != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }

    if (endDate != null) {
      query = query.where(
        'timestamp',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    return query
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => <String, dynamic>{
                  ...Map<String, dynamic>.from(doc.data() as Map),
                  'id': doc.id,
                })
            .toList());
  }

  // 📅 ดึงกิจกรรมทั้งหมดเพื่อแสดงในปฏิทิน (Admin เห็นทุกคน / User เห็นเฉพาะของตัวเอง) 🥇🏆🏎️
  Stream<List<Map<String, dynamic>>> getCalendarActivitiesStream(
      {String? fullName}) {
    Query query = _db.collection('Leaves');
    if (fullName != null && fullName != 'ผู้ดูแลระบบ') {
      query = query.where('fullName', isEqualTo: fullName);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
        };
      }).toList();
    });
  }

  // 📲 ส่งแจ้งเตือนการ "ขอรีเซ็ตรหัสผ่าน" ไปยังแอดมินทาง LINE ครับ 🥇🏆🏎️
  Future<void> sendLinePasswordResetNotification(
      String username, String fullName) async {
    try {
      final snap = await db.collection('Settings').doc('line_messaging').get();
      if (!snap.exists) return;

      final settings = snap.data() ?? <String, dynamic>{};
      final bridgeUrl = _appsScriptUrlFromSettings(settings);
      final to = (settings['groupId'] ?? '').toString().trim();
      if (to.isEmpty) return;

      // 📝 สร้างข้อความแจ้งขอรีเซ็ตรหัสผ่านครับ 🥇🏆
      String msg = "⚠️ แจ้งเตือน: มีการขอรีเซ็ตรหัสผ่าน\n"
          "👤 ชื่อผู้ใช้: $username\n"
          "👤 ชื่อ-นามสกุล: $fullName\n"
          "------------------\n"
          "โปรดดำเนินการตรวจสอบและรีเซ็ตในเมนูจัดการผู้ใช้ครับ";

      final String url = _buildAppsScriptGetUrl(bridgeUrl, {
        'action': 'line_notification',
        'secretKey': FirebaseService.secretKey,
        'to': to,
        'message': msg,
      });

      if (kIsWeb) {
        final String jsCode =
            "fetch(${jsonEncode(url)}, {method:'GET', mode:'no-cors'}).catch(function(e){});";
        js.context.callMethod('eval', [jsCode]);
      } else {
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("❌ Password Reset Notify Error: $e");
    }
  }
}
