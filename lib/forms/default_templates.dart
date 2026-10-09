/// แม่แบบเริ่มต้นในโค้ด — ใช้เมื่อฐานข้อมูลยังไม่มีแม่แบบ หรือโหลดไม่ได้
///
/// ค่ามาจากไฟล์ที่สร้างจากโค้ด web (default_templates.g.dart) จึงตรงกับ
/// defaultLeaveTemplate() / defaultTripTemplate() ใน web เสมอ
library;

import 'dart:convert';

import 'default_templates.g.dart';
import 'form_template.dart';

final Map<FormType, FormTemplate> _cache = {};

/// แม่แบบเริ่มต้นของประเภทฟอร์มนั้น (อ่าน JSON ครั้งเดียวแล้วเก็บไว้)
FormTemplate builtInTemplate(FormType type) => _cache[type] ??=
    FormTemplate.fromJson(jsonDecode(switch (type) {
      FormType.leave => defaultLeaveTemplateJson,
      FormType.trip => defaultTripTemplateJson,
    }) as Map<String, dynamic>);
