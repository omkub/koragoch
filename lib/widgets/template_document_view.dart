/// แสดงเอกสาร HTML ที่วาดจากแม่แบบ (lib/forms/form_render.dart) บนหน้าจอ
///
/// บนเว็บแสดงใน iframe จึงเห็นเอกสารเหมือนตอนพิมพ์ทุกประการ
/// แพลตฟอร์มอื่นแสดง [fallback] แทน (ดูเหตุผลที่แยกไฟล์ใน utils/web_platform.dart)
library;

export 'template_document_view_io.dart'
    if (dart.library.js_interop) 'template_document_view_web.dart';
