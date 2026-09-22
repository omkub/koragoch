// เทสกันโค้ดที่เรียกตัวเองวนไม่รู้จบกลับมาอีก
//
// เคยมีบั๊ก: ฟังก์ชัน getXFromSupabase() เวลา Supabase ยังไม่พร้อมจะ
// "ถอยไปใช้" getX() แต่ getX() ก็เรียก getXFromSupabase() กลับมาอีก
// กลายเป็นวนไม่รู้จบ → แท็บเบราว์เซอร์ค้าง กดอะไรไม่ได้ ต้องรีเฟรชทิ้ง
//
// อาการนี้เกิดเฉพาะตอน Supabase ยังต่อไม่เสร็จ (เปิดแอปใหม่ ๆ เน็ตช้า)
// จึงหลุดการทดสอบด้วยมือได้ง่าย เทสนี้อ่านซอร์สตรง ๆ เพื่อดักไว้

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ไม่มีการถอยไปเรียกฟังก์ชันที่เรียกตัวเองกลับมา', () {
    final source = File('lib/services/firebase_service.dart').readAsStringSync();

    // รูปแบบที่ห้ามมี: ตอน client เป็น null แล้วไปเรียก getXxx(...) ต่อ
    final bad = RegExp(r'if \(client == null\) return get\w+\(');
    final matches = bad.allMatches(source);

    expect(
      matches.map((m) => m.group(0)).toList(),
      isEmpty,
      reason: 'พบการถอยไปเรียกฟังก์ชันอื่นตอน Supabase ยังไม่พร้อม '
          'ซึ่งเคยทำให้วนไม่รู้จบจนแอปค้าง — ให้คืนค่าว่างแทน',
    );
  });

  test('ไม่มี query ที่ใช้คอลัมน์ซึ่งไม่มีอยู่ในตาราง Leaves', () {
    final raw = File('lib/services/firebase_service.dart').readAsStringSync();
    // ตัดบรรทัดคอมเมนต์ออกก่อน ไม่งั้นจะไปเจอคอมเมนต์ที่อธิบายบั๊กนี้เอง
    final source = raw
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    // ตาราง Leaves เก็บ id_user (FK) ไม่มีคอลัมน์ชื่อครู
    // และใช้ timestamp ไม่ใช่ createdat
    expect(source.contains("eq('fullname'"), isFalse,
        reason: 'ตาราง Leaves ไม่มีคอลัมน์ fullname ให้ค้นด้วย id_user แทน');
    expect(source.contains("order('createdat'"), isFalse,
        reason: 'ตาราง Leaves ไม่มีคอลัมน์ createdat ให้เรียงด้วย timestamp แทน');
  });
}
