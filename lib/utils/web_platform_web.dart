/// ของจริงสำหรับเว็บ — ใช้ DOM และ JS interop
///
/// โค้ดในไฟล์นี้ย้ายมาจากหน้าจอ/service เดิมแบบยกมาทั้งดุ้น พฤติกรรมจึงเหมือนเดิม
/// ทุกประการ เปลี่ยนแค่ "ที่อยู่" ให้มารวมกันจุดเดียว
/// ดูเหตุผลที่ต้องแยกไฟล์ได้ที่ web_platform.dart
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;

/// ยิง GET แบบ no-cors ทิ้งไว้ ไม่สนใจผลลัพธ์
///
/// ใช้กับ Apps Script ที่ตอบกลับเป็น HTTP 302 เสมอ จึงอ่านผลไม่ได้อยู่แล้ว
/// ขอแค่ให้คำสั่งไปถึงปลายทางก็พอ
void fireAndForgetGet(String url) {
  final String jsCode =
      "fetch(${jsonEncode(url)}, {method:'GET', mode:'no-cors'}).catch(function(){});";
  globalContext.callMethod<JSAny>('eval'.toJS, jsCode.toJS);
}

/// เรียก Apps Script แล้วรอผลกลับมาเป็น JSON ผ่านเทคนิค JSONP
///
/// บนเว็บเรียก http.get ตรง ๆ ไม่ได้เพราะติด CORS จึงต้องแทรก <script> แล้วให้
/// ปลายทางเรียก callback กลับมาแทน
Future<Map<String, dynamic>> jsonpGet(
  String url, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final completer = Completer<String>();
  final callbackName = 'lineCb_${DateTime.now().microsecondsSinceEpoch}';
  final separator = url.contains('?') ? '&' : '?';
  final callbackUrl = '$url${separator}callback=$callbackName';

  globalContext[callbackName] = ((JSAny? data) {
    if (!completer.isCompleted) {
      completer.complete(
          data != null ? jsonEncode((data as JSObject).dartify()) : '{}');
    }
  }).toJS;

  final script = web.document.createElement('script') as web.HTMLScriptElement
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

  web.document.body?.append(script);

  Future.delayed(timeout, () {
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
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List) {
      return {'status': 'error', 'isList': true, 'data': decoded};
    }
    return <String, dynamic>{'status': 'error', 'message': 'Invalid response'};
  } finally {
    globalContext[callbackName] = null;
    script.remove();
  }
}

/// ข้อมูลเบราว์เซอร์ของผู้ใช้ สำหรับเก็บลงประวัติการเข้าใช้งาน
String get platformUserAgent => web.window.navigator.userAgent;

/// เปิดหน้า HTML ที่สร้างขึ้นเองในแท็บใหม่ (ใช้กับหน้าพิมพ์/ดูตัวอย่างรายงาน)
///
/// คืน false เมื่อเบราว์เซอร์บล็อก pop-up เพื่อให้หน้าจอแจ้งผู้ใช้ได้
bool openHtmlInNewTab(String htmlContent) {
  final blob = web.Blob(
    [htmlContent.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final popup = web.window.open(url, '_blank');

  if (popup == null) {
    web.URL.revokeObjectURL(url);
    return false;
  }

  // ปล่อยให้แท็บใหม่โหลดเสร็จก่อนค่อยคืนหน่วยความจำ
  Future.delayed(
      const Duration(seconds: 20), () => web.URL.revokeObjectURL(url));
  return true;
}

/// สั่งให้เบราว์เซอร์ดาวน์โหลดไฟล์จากข้อมูลในหน่วยความจำ
bool downloadBytes(List<int> bytes, String fileName, String mimeType) {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}

/// เปิดหน้าต่างเลือกรูป แล้วย่อขนาดให้ก่อนคืนเป็น data URL
///
/// ย่อฝั่งผู้ใช้ก่อนอัปโหลดเพื่อไม่ให้ไฟล์ใหญ่เกินจำเป็น
/// คืน null เมื่อผู้ใช้กดยกเลิก
Future<String?> pickAndCompressImage({
  int maxSize = 350,
  double quality = 0.85,
}) {
  final completer = Completer<String?>();

  final uploadInput =
      web.document.createElement('input') as web.HTMLInputElement
        ..type = 'file'
        ..accept = 'image/*';

  uploadInput.onChange.listen((_) {
    final files = uploadInput.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = web.FileReader();
    reader.readAsDataURL(files.item(0)!);

    reader.onLoadEnd.listen((_) {
      // แปลงผ่าน JSString ไม่ใช่ cast ตรง ๆ เป็น String
      // เพราะการ cast ข้ามฝั่ง JS/Dart ให้ผลไม่เหมือนกันระหว่าง JS กับ WebAssembly
      final img = web.document.createElement('img') as web.HTMLImageElement
        ..src = (reader.result as JSString).toDart;

      img.onLoad.listen((_) {
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

        final canvas =
            web.document.createElement('canvas') as web.HTMLCanvasElement
              ..width = width
              ..height = height;
        final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
        ctx.drawImage(img, 0, 0, width.toDouble(), height.toDouble());

        if (!completer.isCompleted) {
          completer.complete(canvas.toDataURL('image/jpeg', quality.toJS));
        }
      });
    });
  });

  uploadInput.click();
  return completer.future;
}
