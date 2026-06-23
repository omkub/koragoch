import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:js_util' as js_util;
// ignore: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:html' as html;
import '../services/firebase_service.dart';

class LineSettingsScreen extends StatefulWidget {
  const LineSettingsScreen({super.key});

  @override
  State<LineSettingsScreen> createState() => _LineSettingsScreenState();
}

class _LineSettingsScreenState extends State<LineSettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _lineTokenController = TextEditingController();
  final _lineGroupIdController = TextEditingController();
  final _webhookUrlController = TextEditingController();
  static const String _knownLineGroupId = '';
  
  bool _isSavingLineToken = false;
  bool _isSendingLineTest = false;
  bool _showLineToken = false;
  String? _lineStatusMsg;
  bool _lineStatusIsError = false;
  String _lineNotifyTemplate = '📋 แจ้งเตือนการยื่นใบลา\n👤 ชื่อ: {name}\n📅 ประเภทลา: {type}\n🗓️ ตั้งแต่: {startDate} ถึง {endDate}\n📆 จำนวน: {days} วัน\n✍️ เหตุผล: {reason}';

  @override
  void initState() {
    super.initState();
    _webhookUrlController.text = FirebaseService.appsScriptUrl;
    _loadLineSettings();
  }

  Future<void> _loadLineSettings() async {
    try {
      final snap = await _firebaseService.db.collection('Settings').doc('line_messaging').get();
      if (snap.exists && snap.data() != null) {
        final data = snap.data()!;
        setState(() {
          // 🕵️‍♂️ ไม่ดึง Token มาโชว์แล้วครับ ปลอดภัย Phase 4 🥇🏆
          _lineGroupIdController.text = data['groupId'] ?? '';
          _webhookUrlController.text =
              (data['webhookUrl'] ?? FirebaseService.appsScriptUrl).toString();
          if (data['template'] != null && data['template'].toString().isNotEmpty) {
            _lineNotifyTemplate = data['template'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading LINE settings: $e");
    }
  }

  @override
  void dispose() {
    _lineTokenController.dispose();
    _lineGroupIdController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 1100;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== HEADER =====
            _buildHeader(isMobile),
            const SizedBox(height: 32),

            // ===== NOTICE: LINE Notify ปิดตัวแล้ว =====
            _buildNoticeCard(),
            const SizedBox(height: 24),

            // ===== SECTION 1: Channel Access Token =====
            _buildSettingsCard(isMobile),
            const SizedBox(height: 24),

            // ===== SECTION 2: ทดสอบการส่ง =====
            _buildTestCard(),
            const SizedBox(height: 24),

            // ===== SECTION 3: Template =====
            _buildTemplateCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF06C755).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.notifications_active_rounded, color: const Color(0xFF06C755), size: isMobile ? 24 : 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ตั้งค่าการแจ้งเตือน LINE",
                  style: GoogleFonts.sarabun(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
              Text("ระบบแจ้งเตือนใบลาผ่าน Messaging API",
                  style: GoogleFonts.sarabun(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("LINE Notify ปิดให้บริการแล้ว",
                    style: GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                Text("ระบบนี้ใช้เทคโนโลยีใหม่ LINE Messaging API แทน ซึ่งมีความเสถียรกว่าครับ",
                    style: GoogleFonts.sarabun(fontSize: 13, color: Colors.amber.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(bool isMobile) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.green.shade600, size: 24),
              const SizedBox(width: 8),
              Text("กำหนดค่าการเชื่อมต่อ", style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          
          // 🛡️ ข้อมูลแจ้งเตือนความปลอดภัย (Phase 4) 🥇🏆
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "ระบบเปิดใช้งาน 'Secure Backend' แล้ว: กุญแจสำคัญถูกจัดเก็บไว้ที่หลังบ้านอย่างปลอดภัย (ไม่ต้องกรอก Token ที่นี่ครับ)",
                    style: GoogleFonts.sarabun(fontSize: 13, color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildFieldLabel("Group ID / User ID (ID ห้องแชท)"),
          // 📱 ปรับแต่งการแสดงผลปุ่มค้นหาให้รองรับมือถือครับ 🥇🏆
          if (isMobile) 
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(_lineGroupIdController, "C... หรือ G..."),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _showGroupIdPicker,
                  icon: const Icon(Icons.manage_search_rounded, size: 18),
                  label: const Text("ตรวจสอบ Group ID ล่าสุด"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _buildTextField(_lineGroupIdController, "เช่น C... หรือ G...")),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _showGroupIdPicker,
                  icon: const Icon(Icons.manage_search_rounded, size: 18),
                  label: const Text("ตรวจสอบ Group ID"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _buildFieldLabel("Webhook URL (Google Apps Script Web App)"),
          _buildTextField(
            _webhookUrlController,
            "https://script.google.com/macros/s/.../exec",
          ),
          const SizedBox(height: 24),
          if (_lineStatusMsg != null)
             Padding(
               padding: const EdgeInsets.only(bottom: 16),
               child: Text(_lineStatusMsg!, style: TextStyle(color: _lineStatusIsError ? Colors.red : Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
             ),
          ElevatedButton.icon(
            onPressed: _isSavingLineToken ? null : _saveSettings,
            icon: _isSavingLineToken ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
            label: const Text("บันทึกการตั้งค่า"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06C755),
              foregroundColor: Colors.white,
              minimumSize: const Size(200, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return _buildCard(
      child: Row(
        children: [
          const Icon(Icons.send_rounded, color: Colors.orange, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("ทดสอบระบบ", style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("ลองส่งข้อความจำลองเข้ากลุ่มไลน์เพื่อดูผลลัพธ์ครับ", style: GoogleFonts.sarabun(fontSize: 12, color: Colors.grey)),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: _isSendingLineTest ? null : _sendLineTest,
            icon: _isSendingLineTest ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.flash_on_rounded),
            label: const Text("ส่งทดสอบตอนนี้"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("รูปแบบข้อความ (Template)", style: GoogleFonts.sarabun(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(
            controller: TextEditingController(text: _lineNotifyTemplate),
            maxLines: 6,
            onChanged: (v) => _lineNotifyTemplate = v,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            style: GoogleFonts.sarabun(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['{name}', '{type}', '{startDate}', '{endDate}', '{days}', '{reason}'].map((v) => 
               Chip(label: Text(v, style: const TextStyle(fontSize: 10)), backgroundColor: Colors.blue.shade50, side: BorderSide.none)
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20)],
      ),
      child: child,
    );
  }

  Widget _buildFieldLabel(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: GoogleFonts.sarabun(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)));

  bool _isLikelyLineTargetId(String value) {
    return RegExp(r'^[CUR][0-9a-fA-F]{32,}$').hasMatch(value.trim());
  }

  String _normalizedWebhookUrl() {
    final value = _webhookUrlController.text.trim();
    return value.isEmpty ? FirebaseService.appsScriptUrl : value;
  }

  void _validateWebhookUrl(String value) {
    if (!FirebaseService.isLikelyAppsScriptWebAppUrl(value)) {
      throw Exception('Webhook URL ต้องเป็น Google Apps Script Web App URL ที่ลงท้ายด้วย /exec');
    }
  }

  bool _fillKnownLineGroupId() {
    if (!_isLikelyLineTargetId(_knownLineGroupId)) return false;
    if (mounted) {
      setState(() => _lineGroupIdController.text = _knownLineGroupId);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('เติม Group ID ล่าสุดให้แล้วครับ กดบันทึกการตั้งค่าแล้วส่งทดสอบได้เลย'),
        backgroundColor: Colors.green,
      ));
    }
    return true;
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {bool isPassword = false, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
    );
  }

  // 🕵️‍♂️ ฟังก์ชันดึงไอดีล่าสุดจาก 'สะพานเชื่อม' (Apps Script Middleman) 🥇🏆
  Future<void> _showGroupIdPicker() async {
    if (_lineGroupIdController.text.trim().isEmpty && _fillKnownLineGroupId()) {
      return;
    }
    setState(() => _lineStatusMsg = '⌛ กำลังเรียกดูไอดีล่าสุดจากระบบกลาง...');
    try {
      // 📲 ปรับมาใช้ GET แทน POST เพื่อเลี่ยงปัญหา CORS บนเว็บบราวเซอร์ครับ 🥇🏆
      final bridgeUrl = _normalizedWebhookUrl();
      _validateWebhookUrl(bridgeUrl);
      final String url = "$bridgeUrl?action=get_latest_id&secretKey=${FirebaseService.secretKey}";
      
      final dynamic data = await _getAppsScriptJson(url);
      
      // 🛡️ ตรวจสอบโครงสร้างข้อมูลเพื่อป้องกัน Invalid argument (index) error ครับ 🥇🏆
      if (data is Map && data['status'] == 'success' && data['latestId'] != null && data['latestId'].toString().isNotEmpty) {
          final String id = data['latestId'].toString();
          final String time = data['timestamp']?.toString() ?? '-';
          
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text("พบไอดีล่าสุด!", style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ระบบตรวจพบการเคลื่อนไหวล่าสุดจาก:", style: GoogleFonts.sarabun(fontSize: 14)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                      child: SelectableText(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    ),
                    const SizedBox(height: 8),
                    Text("เวลา: $time", style: GoogleFonts.sarabun(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ยกเลิก")),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _lineGroupIdController.text = id);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ดึงไอดีมาใส่ให้เรียบร้อยแล้วครับ! อย่าลืมกดบันทึกนะ')));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                    child: const Text("ใช้ไอดีนี้"),
                  ),
                ],
              ),
            );
          }
        } else if (data is List) {
          if (_fillKnownLineGroupId()) return;
          throw Exception('ระบบหลังบ้านส่งข้อมูลมาเป็น List (${data.length} รายการ) แทนที่จะเป็นสถานะครับ (โปรดตรวจสอบ Apps Script)');
        } else {
          final existingId = _lineGroupIdController.text.trim();
          if (_isLikelyLineTargetId(existingId)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('พบ Group ID ที่กรอกไว้แล้ว ใช้ค่านี้ได้เลยครับ กดบันทึกการตั้งค่าแล้วส่งทดสอบได้ทันที'),
                backgroundColor: Colors.green,
              ));
            }
            return;
          }
          throw Exception('ยังไม่มีการส่งข้อความเข้ากลุ่ม LINE ล่าสุด หรือระบบหลังบ้านขัดข้องครับ');
        }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ไม่พบข้อมูล: $e'), backgroundColor: Colors.orange));
      }
    } finally {
      setState(() => _lineStatusMsg = null);
    }
  }

  Future<void> _saveSettings() async {
    setState(() { _isSavingLineToken = true; _lineStatusMsg = null; });
    try {
      // 💾 บันทึกเฉพาะข้อมูลที่ไม่เป็นความลับระดับสูง (Phase 4)
      final webhookUrl = _normalizedWebhookUrl();
      _validateWebhookUrl(webhookUrl);
      final groupId = _lineGroupIdController.text.trim();
      if (groupId.isNotEmpty && !_isLikelyLineTargetId(groupId)) {
        throw Exception('LINE ID ไม่ถูกต้อง: Group ID ต้องขึ้นต้นด้วย C, User ID ขึ้นต้นด้วย U หรือ Room ID ขึ้นต้นด้วย R');
      }
      await _firebaseService.db.collection('Settings').doc('line_messaging').set({
        'groupId': groupId,
        'webhookUrl': webhookUrl,
        'template': _lineNotifyTemplate,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      setState(() { _lineStatusMsg = '✅ บันทึกข้อมูลเรียบร้อย (ระบบ Secure Bridge)!'; _lineStatusIsError = false; });
    } catch (e) {
      setState(() { _lineStatusMsg = '❌ ข้อผิดพลาด: $e'; _lineStatusIsError = true; });
    } finally {
      setState(() => _isSavingLineToken = false);
    }
  }

  // 🕵️‍♂️ ฟังก์ชันส่งแจ้งเตือนแบบ CORS-Safe ทำงานได้ทั้งเว็บและมือถือ 🥇🏆
  Future<bool> _sendViaAppsScript(String url) async {
    if (kIsWeb) {
      // 🌐 บนเว็บ: ใช้ JS fetch แบบ no-cors เพื่อทะลุผ่าน CORS บล็อก
      // สคริปต์จะทำงานและส่ง LINE ไปก่อน เราแค่รอ 2 วิแล้วถือว่าสำเร็จครับ 🥇🏆
      final String jsCode =
          "fetch(${jsonEncode(url)}, {method:'GET', mode:'no-cors'}).catch(function(){});";
      js.context.callMethod('eval', [jsCode]);
      await Future.delayed(const Duration(seconds: 2));
      return true;
    } else {
      // 📱 บนมือถือ: ใช้ http.get ปกติ (ไม่มีปัญหา CORS)
      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200;
    }
  }

  Future<Map<String, dynamic>> _getAppsScriptJson(String url) async {
    if (kIsWeb) {
      final completer = Completer<String>();
      final callbackName = 'lineCb_${DateTime.now().microsecondsSinceEpoch}';
      final separator = url.contains('?') ? '&' : '?';
      final callbackUrl = '$url${separator}callback=$callbackName';

      // 🌍 สร้างฟังก์ชัน Callback ไว้ที่ window เพื่อให้สคริปต์เรียกกลับมาครับ 🥇🏆
      // ignore: undefined_function
      js_util.setProperty(
        js.context,
        callbackName,
        js_util.allowInterop((dynamic data) {
          if (!completer.isCompleted) {
            completer.complete(jsonEncode(data ?? {}));
          }
          js.context.deleteProperty(callbackName);
        }),
      );

      // 💉 ฉีดสคริปต์เข้าไปในหน้าเว็บครับ
      final script = html.ScriptElement()
        ..src = callbackUrl
        ..async = true;
      
      script.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(jsonEncode({'status': 'error', 'message': 'Network error'}));
        js.context.deleteProperty(callbackName);
        script.remove();
      });

      html.document.body?.append(script);

      // ⏱️ ตั้งเวลา Timeout เผื่อกรณีติดต่อไม่ได้ครับ (ขยายเป็น 45 วินาทีเพื่อให้เสถียรขึ้น)
      Future.delayed(const Duration(seconds: 45), () {
        if (!completer.isCompleted) completer.complete(jsonEncode({'status': 'error', 'message': 'Apps Script timeout'}));
        js.context.deleteProperty(callbackName);
        script.remove();
      });

      final result = await completer.future;
      js.context.deleteProperty(callbackName);
      script.remove();
      
      final decoded = jsonDecode(result);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List) return {'status': 'error', 'isList': true, 'data': decoded};
      throw Exception('Invalid Apps Script response type: ${decoded.runtimeType}');
    }

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200 && response.statusCode != 302) {
      throw Exception('Server error: ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List) return {'status': 'error', 'isList': true, 'data': decoded};
    throw Exception('Invalid Apps Script response type: ${decoded.runtimeType}');
  }

  Future<void> _sendLineTest() async {
    setState(() => _isSendingLineTest = true);
    try {
      final groupId = _lineGroupIdController.text.trim();
      final bridgeUrl = _normalizedWebhookUrl();
      _validateWebhookUrl(bridgeUrl);
      if (!_isLikelyLineTargetId(groupId) && groupId.isNotEmpty) {
        throw Exception('LINE ID ไม่ถูกต้อง: Group ID ต้องขึ้นต้นด้วย C, User ID ขึ้นต้นด้วย U หรือ Room ID ขึ้นต้นด้วย R');
      }
      if (groupId.isEmpty) throw Exception('กรุณากรอกไอดีห้องแชทก่อนทดสอบครับ');

      // 📲 สร้างข้อความทดสอบจาก Template 🥇🏆
      final String msg = _lineNotifyTemplate
          .replaceAll('{name}', 'ครูทดสอบ ระบบใบลา')
          .replaceAll('{type}', 'ลากิจส่วนตัว')
          .replaceAll('{startDate}', '10/06/2026')
          .replaceAll('{endDate}', '11/06/2026')
          .replaceAll('{days}', '2')
          .replaceAll('{reason}', 'ทดสอบระบบแจ้งเตือนแบบปลอดภัย');

      final String url = "$bridgeUrl?action=line_notification"
          "&secretKey=${FirebaseService.secretKey}"
          "&to=$groupId"
          "&message=${Uri.encodeComponent(msg)}";

      final result = await _getAppsScriptJson(url);
      if (result['status'] != 'success') {
        final lineStatus = result['lineStatus'] == null ? '' : ' (LINE ${result['lineStatus']})';
        throw Exception('${result['message'] ?? 'LINE send failed'}$lineStatus');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 ส่งทดสอบแล้ว! ตรวจสอบห้อง LINE เลยครับ'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ล้มเหลว: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSendingLineTest = false);
    }
  }
}
