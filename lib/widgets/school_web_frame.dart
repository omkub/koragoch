/// แสดงหน้าเว็บโรงเรียน (/central/) แบบฝังในหน้าจอแอประบบวันลา (PC)
///
/// บนเว็บใช้ iframe จริงที่รับคลิกและพิมพ์ได้เต็มรูปแบบ
/// บนแพลตฟอร์มอื่นแสดงการ์ดพร้อมปุ่มเปิดเบราว์เซอร์แทน
library;

export 'school_web_frame_io.dart'
    if (dart.library.js_interop) 'school_web_frame_web.dart';
