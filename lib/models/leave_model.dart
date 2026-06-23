import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveModel {
  final String? id;
  final String teacherName;
  final String position; // ตำแหน่ง/กลุ่มสาระ
  final String leaveType; // ลาป่วย, ลากิจ, ลาพักผ่อน, ลาคลอดบุตร
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? evidenceUrl; // ลิงก์รูปหลักฐาน
  final String status; // ค่าเริ่มต้นคือ 'รอการอนุมัติ'
  final DateTime createdAt;
  final String contactInfo; // ข้อมูลติดต่อ (เพิ่มจากที่เห็นในเอกสาร)
  final int durationDays; // จำนวนวันลา (เพิ่มจากที่เห็นในเอกสาร)

  LeaveModel({
    this.id,
    required this.teacherName,
    required this.position,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.evidenceUrl,
    this.status = 'รอการอนุมัติ',
    required this.createdAt,
    required this.contactInfo,
    required this.durationDays,
  });

  // แปลงจาก Firestore document เป็น Object
  factory LeaveModel.fromFirestore(Map<String, dynamic> json, String id) {
    return LeaveModel(
      id: id,
      teacherName: json['teacherName'] ?? '',
      position: json['position'] ?? '',
      leaveType: json['leaveType'] ?? '',
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
      reason: json['reason'] ?? '',
      evidenceUrl: json['evidenceUrl'],
      status: json['status'] ?? 'รอการอนุมัติ',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      contactInfo: json['contactInfo'] ?? '',
      durationDays: json['durationDays'] ?? 0,
    );
  }

  // แปลงจาก Object เป็น Map เพื่อบันทึกลง Firestore
  Map<String, dynamic> toMap() {
    return {
      'teacherName': teacherName,
      'position': position,
      'leaveType': leaveType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'evidenceUrl': evidenceUrl,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'contactInfo': contactInfo,
      'durationDays': durationDays,
    };
  }
}
