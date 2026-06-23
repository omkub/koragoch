import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🛡️ นำเข้า Firebase Auth ครับ (Phase 2)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../firebase_options.dart';
import 'responsive_layout.dart';
import '../services/firebase_service.dart'; // 🛡️ นำเข้า FirebaseService ครับ 🥇🏆

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseService _firebaseService =
      FirebaseService(); // 🛡️ สร้าง Instance ครับ 🥇🏆
  bool _isLoading = false;
  bool _rememberMe = false;

  FirebaseFirestore get _db => _firebaseService.db;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (!rememberMe) return;

    _usernameController.text = prefs.getString('saved_username') ?? '';
    _passwordController.text = prefs.getString('saved_password') ?? '';

    if (mounted) {
      setState(() => _rememberMe = true);
    }
  }

  Future<void> _clearSessionPrefs(SharedPreferences prefs) async {
    await prefs.remove('isLoggedIn');
    await prefs.remove('loginAt');
    await prefs.remove('currentUser');
    await prefs.remove('userRole');
    await prefs.remove('userFullDataJson');
  }

  String _stablePasswordTag(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _fallbackAuthEmail(String teacherDocId, String authPassword) {
    final safeDocId =
        teacherDocId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'user_${safeDocId}_${_stablePasswordTag(authPassword)}@rbp.ac.th';
  }

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

  Future<UserCredential> _signInOrCreateAuthUser(
    FirebaseAuth auth,
    String email,
    String password,
  ) async {
    try {
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (signInError) {
      debugPrint(
          'Firebase Auth sign-in failed for $email: ${signInError.code}');
      return auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 🛡️ Pre-flight Check: ตรวจสอบสะพานเชื่อม Firebase ก่อนเริ่มงานครับ 🥇🏆
      if (Firebase.apps.isEmpty) {
        debugPrint("Firebase not ready. Waiting 500ms...");
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final auth = FirebaseAuth.instance;
      final firestoreAtSchool = _firebaseService.db;

      final String username = _usernameController.text.trim();
      final String password = _passwordController.text.trim();

      // 🛡️ 1. แปลงชื่อเป็นอีเมล และเสริมรหัสผ่านให้ปลอดภัยระดับสูง (แก้ปัญหารหัสสั้นกว่า 6 ตัว) 🥇🏆
      final String pseudoEmail = "$username@rbp.ac.th";
      final String pseudoPassword = "$password-SLA2026!";

      bool loginSuccess = false;
      Map<String, dynamic>? userData;

      // 🛡️ [ด่านตรวจที่ 0] ตรวจสอบข้อมูลจาก Firestore ก่อนเริ่ม Auth ครับ 🥇🏆
      final query = await firestoreAtSchool
          .collection('Teachers')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        _showError('ไม่พบข้อมูลผู้ใช้งานนี้ในระบบครับ');
        return;
      }
      final teacherDocId = query.docs.first.id;
      userData = {
        ...query.docs.first.data(),
        'id': teacherDocId,
      };
      final effectiveRole = _resolveEffectiveRole([
        userData['role'],
        userData['permission'],
      ]);

      // 🛡️ [ด่านตรวจที่ 1] เช็คสถานะการแจ้งลืมรหัสก่อนเลยครับ
      final forgotStatus = (userData['forgotPasswordStatus'] ?? '').toString();
      if (forgotStatus == 'waiting' || forgotStatus == 'reset_by_admin') {
        _showError(
            '⚠️ บัญชีนี้อยู่ระหว่างการรีเซ็ตรหัสผ่านครับ\nโปรดใช้รหัสชั่วคราว 123456 เพื่อตั้งรหัสใหม่ผ่านเมนู "แจ้งลืมรหัสผ่าน" ที่หน้าล็อกอินครับ');
        return;
      }
      // 🛡️ [ด่านตรวจที่ 2] ตรวจสอบว่ารหัสผ่านตรงกับฐานข้อมูลล่าสุด
      if (userData['password'].toString().trim() != password) {
        _showError('รหัสผ่านไม่ถูกต้องครับ 🔐');
        return;
      }

      try {
        UserCredential uc = await _signInOrCreateAuthUser(
          auth,
          pseudoEmail,
          pseudoPassword,
        );

        if (uc.user != null) {
          final synced = await _firebaseService.linkTeacherWithUid(
            userData['fullName'] ?? '',
            uc.user!.uid,
            teacherDocId: teacherDocId,
            username: username,
            preferredRole: effectiveRole,
          );
          if (!synced) {
            throw Exception('ไม่สามารถซิงค์สิทธิ์ผู้ใช้งานกับฐานข้อมูลได้');
          }
          loginSuccess = true;
        }
      } catch (primaryAuthError) {
        debugPrint(
          'Primary Auth account is unusable for $username. Trying fallback account: $primaryAuthError',
        );

        final fallbackEmail = _fallbackAuthEmail(teacherDocId, pseudoPassword);
        UserCredential uc = await _signInOrCreateAuthUser(
          auth,
          fallbackEmail,
          pseudoPassword,
        );

        if (uc.user != null) {
          final synced = await _firebaseService.linkTeacherWithUid(
            userData['fullName'] ?? '',
            uc.user!.uid,
            teacherDocId: teacherDocId,
            username: username,
            preferredRole: effectiveRole,
          );
          if (!synced) {
            throw Exception('ไม่สามารถซิงค์สิทธิ์ผู้ใช้งานกับฐานข้อมูลได้');
          }
          loginSuccess = true;
        }
      }

      // --- 🛡️ 5. เซฟเซสชันและเข้าสู่ระบบ ---
      if (loginSuccess && userData != null) {
        final prefs = await SharedPreferences.getInstance();

        // 🧹 ล้างข้อมูลขยะจาก User คนก่อนหน้าทิ้งให้หมดครับ เพื่อความสะอาด 100% 🥇🏆
        await _clearSessionPrefs(prefs);

        if (_rememberMe) {
          await prefs.setBool('remember_me', true);
          await prefs.setString('saved_username', username);
          await prefs.setString('saved_password', password);
        } else {
          await prefs.remove('remember_me');
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');
        }

        await prefs.setBool('isLoggedIn', true);
        await prefs.setInt('loginAt', DateTime.now().millisecondsSinceEpoch);
        await prefs.setString('currentUser',
            userData['fullName'] ?? userData['name'] ?? 'ผู้ใช้งาน');
        await prefs.setString('userRole', effectiveRole);

        // 🛡️ บันทึกประวัติการเข้าใช้งานลงฐานข้อมูลครับ 🥇🏆🏎️
        await _firebaseService.logLogin(
            username,
            userData['fullName'] ?? userData['name'] ?? 'ผู้ใช้งาน',
            effectiveRole);

        // 🚀 ขั้นสุดยอด: เซฟข้อมูลทั้งก้อนไว้ในเครื่อง พร้อมระบบป้องกัน JSON Error ขั้นเทพ 🥇🏆🏎️
        final safeJson = jsonEncode({
          ...userData,
          'id': teacherDocId,
          'role': effectiveRole,
          'permission': effectiveRole,
        }, toEncodable: (item) {
          if (item is Timestamp) return item.toDate().toIso8601String();
          if (item is DateTime) return item.toIso8601String();
          return item.toString(); // Fallback โหดๆ สำหรับของแปลกครับ
        });

        await prefs.setString('userFullDataJson', safeJson);

        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (ctx) => const ResponsiveLayout()));
        }
      }
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.sarabun()),
        backgroundColor: const Color(0xFF0F172A)));
  }

  // 🔥 ฟังก์ชันแสดงหน้าจอ "ตรวจสอบตัวตน" (Forgot Password Dialog) ฉบับอัปเกรดพรีเมียม 100% 🕵️‍♂️🥇🏆
  // 🕵️‍♂️ ปฏิรูประบบกู้คืนรหัสผ่านพรีเมียมแบบ 2-Step ครับ 🥇🏆
  void _showForgotPasswordDialog() {
    int currentStep = 0; // 0: Verify, 1: Reset New Password
    String targetUserId = '';
    String targetFullname = '';

    final TextEditingController recoverUserCtrl = TextEditingController();
    final TextEditingController recoverKeyCtrl = TextEditingController();
    final TextEditingController newPassCtrl = TextEditingController();
    final TextEditingController confirmPassCtrl = TextEditingController();

    bool isProcessing = false;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: Center(
              child: SingleChildScrollView(
                child: StatefulBuilder(builder: (context, setDialogState) {
                  return AlertDialog(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36)),
                    contentPadding: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    content: Container(
                      width: 420,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Column(
                          key: ValueKey<int>(currentStep),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🔷 Modern Header
                            _buildDialogHeader(currentStep == 0
                                ? 'ตรวจสอบตัวตน'
                                : 'ตั้งรหัสผ่านใหม่'),

                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(36, 32, 36, 32),
                              child: currentStep == 0
                                  ? _buildStep1View(
                                      userCtrl: recoverUserCtrl,
                                      keyCtrl: recoverKeyCtrl,
                                      isLoading: isProcessing,
                                      onVerify: () async {
                                        setDialogState(
                                            () => isProcessing = true);
                                        final success = await _verifyResetSatus(
                                            username:
                                                recoverUserCtrl.text.trim(),
                                            inputKey:
                                                recoverKeyCtrl.text.trim(),
                                            onUserFound: (id, name) {
                                              targetUserId = id;
                                              targetFullname = name;
                                            });
                                        setDialogState(() {
                                          isProcessing = false;
                                          if (success) currentStep = 1;
                                        });
                                      })
                                  : _buildStep2View(
                                      newPassCtrl: newPassCtrl,
                                      confirmPassCtrl: confirmPassCtrl,
                                      isLoading: isProcessing,
                                      onSave: () async {
                                        if (newPassCtrl.text !=
                                            confirmPassCtrl.text) {
                                          _showError('รหัสผ่านไม่ตรงกันครับ');
                                          return;
                                        }
                                        if (newPassCtrl.text.length < 6) {
                                          _showError(
                                              'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษรครับ');
                                          return;
                                        }

                                        setDialogState(
                                            () => isProcessing = true);
                                        final ok = await _saveNewPassword(
                                            targetUserId, newPassCtrl.text);
                                        setDialogState(
                                            () => isProcessing = false);

                                        if (ok) {
                                          Navigator.pop(ctx);
                                          _showSuccessDialog(
                                              'ตั้งรหัสผ่านใหม่สำเร็จ!',
                                              'ขณะนี้คุณครูสามารถใช้รหัสผ่านใหม่\nในการเข้าสู่ระบบได้ทันทีครับ');
                                        }
                                      }),
                            ),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('ยกเลิกและกลับหน้าเดิม',
                                        style: GoogleFonts.sarabun(
                                            color: const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🏛️ Header สำหรับหน้าต่างกู้รหัสครับ
  Widget _buildDialogHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.shield_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          Text(title,
              style: GoogleFonts.sarabun(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }

  // 🏁 Step 1: ตรวจสอบ Username + รหัส 123456
  Widget _buildStep1View({
    required TextEditingController userCtrl,
    required TextEditingController keyCtrl,
    required bool isLoading,
    required VoidCallback onVerify,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'ยืนยันสิทธิ์กู้คืนรหัสผ่านด้วยรหัสชั่วคราว\nที่คุณได้รับจากแอดมินโรงเรียนครับ',
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(
                color: const Color(0xFF64748B), height: 1.5, fontSize: 13)),
        const SizedBox(height: 32),
        _buildDialogFieldLabel('ชื่อผู้ใช้งาน (Username)'),
        const SizedBox(height: 8),
        _buildPremiumDialogField(
            controller: userCtrl,
            hint: 'ระบุรอยชื่อผู้ใช้งาน',
            icon: Icons.person_outline),
        const SizedBox(height: 20),
        _buildDialogFieldLabel('รหัสชั่วจากแอดมิน (24 ชม.)'),
        const SizedBox(height: 8),
        _buildPremiumDialogField(
            controller: keyCtrl,
            hint: 'กรอกรหัสลับ 6 หลัก',
            icon: Icons.vpn_key_outlined),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isLoading
                ? null
                : () => _notifyAdminRequest(userCtrl.text.trim()),
            icon: const Icon(Icons.notifications_active_outlined,
                size: 16, color: Colors.orange),
            label: Text('ยังไม่มีรหัส? แจ้งแอดมินที่นี่',
                style: GoogleFonts.sarabun(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: isLoading ? null : onVerify,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text('ตรวจสอบสิทธิ์กู้คืนรหัส',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // 📝 Step 2: ตั้งรหัสผ่านใหม่
  Widget _buildStep2View({
    required TextEditingController newPassCtrl,
    required TextEditingController confirmPassCtrl,
    required bool isLoading,
    required VoidCallback onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'ยืนยันสิทธิ์สำเร็จ! กรุณาตั้งรหัสผ่านใหม่\nที่คุณต้องการใช้ล็อกอินในครั้งถัดไปครับ',
            textAlign: TextAlign.center,
            style: GoogleFonts.sarabun(
                color: Colors.green, height: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 32),
        _buildDialogFieldLabel('รหัสผ่านใหม่ (New Password)'),
        const SizedBox(height: 8),
        _buildPremiumDialogField(
            controller: newPassCtrl,
            hint: 'รหัสใหม่ 6 หลักขึ้นไป',
            icon: Icons.lock_outline,
            isPass: true),
        const SizedBox(height: 20),
        _buildDialogFieldLabel('ยืนยันรหัสผ่านใหม่อีกครั้ง'),
        const SizedBox(height: 8),
        _buildPremiumDialogField(
            controller: confirmPassCtrl,
            hint: 'กรอกรหัสเดิมอีกครั้ง',
            icon: Icons.lock_reset_rounded,
            isPass: true),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: isLoading ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text('บันทึกรหัสผ่านใหม่',
                  style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // 🔍 ตรวจสอบสิทธิ์กู้รหัสจาก Firestore
  Future<bool> _verifyResetSatus({
    required String username,
    required String inputKey,
    required Function(String, String) onUserFound,
  }) async {
    if (username.isEmpty || inputKey.isEmpty) {
      _showError('กรุณากรอกข้อมูลให้ครบถ้วนครับ');
      return false;
    }

    if (inputKey != '123456') {
      _showError('รหัสลับจากแอดมินไม่ถูกต้องครับ!');
      return false;
    }

    try {
      final query = await FirebaseFirestore.instanceFor(
              app: Firebase.app(), databaseId: 'school')
          .collection('Teachers')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showError('ไม่พบชื่อผู้ใช้งานนี้ในฐานข้อมูลครับ');
        return false;
      }

      final doc = query.docs.first;
      final status = doc.data();

      // 🛡️ ตรวจสอบว่าแอดมิน "รีเซ็ต" ให้หรือยังครับ 🥇
      if (status['forgotPasswordStatus'] != 'reset_by_admin') {
        _showError(
            'แอดมินยังไม่ได้รีเซ็ตรหัสให้คุณครับ\nกรุณากด "แจ้งแอดมิน" และรอสักครู่ครับ');
        return false;
      }

      // 🕰️ ตรวจสอบเวลา 24 ชม. ครับ (รองรับทั้งแบบ String และ Timestamp) 🥇
      final expireValue = status['resetAllowedUntil'];
      if (expireValue == null) {
        _showError(
            'แอดมินยังไม่ได้ "อนุญาต" การกู้รหัสของคุณครับ\nกรุณาติดต่อแอดมินก่อนครับ');
        return false;
      }

      DateTime expireDate;
      if (expireValue is Timestamp) {
        expireDate = expireValue.toDate();
      } else {
        expireDate = DateTime.parse(expireValue.toString());
      }

      if (expireDate.isBefore(DateTime.now())) {
        _showError(
            'สิทธิ์การกู้รหัสของคุณ "หมดอายุ" แล้วครับ\nกรุณาให้แอดมินเปิดสิทธิ์ให้ใหม่อีกครั้งครับ');
        return false;
      }

      onUserFound(doc.id, status['fullName'] ?? '');
      return true;
    } catch (e) {
      _showError('เกิดความผิดพลาด: $e');
      return false;
    }
  }

  // 🔔 ฟังก์ชันแจ้งเตือนแอดมิน (ส่งสัญญาณ Waiting ไปที่ Firestore) 🥇🏆
  void _notifyAdminRequest(String username) async {
    if (username.isEmpty) {
      _showError('กรุณากรอก Username ก่อนกดแจ้งแอดมินครับ');
      return;
    }

    try {
      final query = await FirebaseFirestore.instanceFor(
              app: Firebase.app(), databaseId: 'school')
          .collection('Teachers')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showError('ไม่พบชื่อผู้ใช้งานนี้ในระบบครับ');
        return;
      }

      final docId = query.docs.first.id;
      await FirebaseFirestore.instanceFor(
              app: Firebase.app(), databaseId: 'school')
          .collection('Teachers')
          .doc(docId)
          .update({
        'forgotPasswordStatus': 'waiting',
        'requestTimestamp': FieldValue.serverTimestamp(),
      });

      // 📲 ส่งแจ้งเตือนแอดมินผ่านระบบ Firestore (แอดมินจะเห็น Badge แจ้งเตือนบนไอคอนเมนูครับ)
      final String fullName = query.docs.first.data()['fullName'] ?? username;
      // _firebaseService.sendLinePasswordResetNotification(username, fullName); // 🔴 ปิดการแจ้งเตือน LINE ตามคำสั่ง (เหลือ 2 จุด)

      _showSuccessDialog('ส่งคำขอสำเร็จ!',
          'ระบบได้แจ้งแอดมินให้ทราบแล้ว\nโปรดรอแอดมินรีเซ็ตรหัสให้ภายในครู่เดียวครับ');
    } catch (e) {
      _showError('ไม่สามารถส่งคำขอได้: $e');
    }
  }

  // 💾 บันทึกรหัสผ่านใหม่ลง Firestore
  Future<bool> _saveNewPassword(String userId, String newPassword) async {
    try {
      await FirebaseFirestore.instanceFor(
              app: Firebase.app(), databaseId: 'school')
          .collection('Teachers')
          .doc(userId)
          .update({
        'password': newPassword,
        'forgotPasswordStatus': null,
        'resetAllowedUntil': null,
        'tempPassword': null, // ล้างค่ารหัสชั่วคราวด้วยครับ
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _showError('ไม่สามารถบันทึกรหัสใหม่ได้: $e');
      return false;
    }
  }

  // 🏆 แสดงผลสำเร็จพรีเมียม
  void _showSuccessDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 72, color: Colors.green),
            const SizedBox(height: 24),
            Text(title,
                style: GoogleFonts.sarabun(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.sarabun(color: Colors.blueGrey)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(c),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumDialogField(
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      bool isPass = false}) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.sarabun(fontSize: 13, color: const Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
        ),
      ),
      style: GoogleFonts.sarabun(fontSize: 14, color: const Color(0xFF1E293B)),
    );
  }

  Widget _buildDialogFieldLabel(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        t,
        style: GoogleFonts.sarabun(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor:
          isMobile ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            // 📱 ในมือถือกางให้เต็มจอ 100% เลยครับ 🥇🏆
            width: isMobile ? screenWidth : 1000,
            height: isMobile ? null : 600,
            constraints: isMobile
                ? BoxConstraints(minHeight: MediaQuery.of(context).size.height)
                : null,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  isMobile ? BorderRadius.zero : BorderRadius.circular(24),
              boxShadow: isMobile
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
            ),
            clipBehavior: Clip.antiAlias,
            child: isMobile
                ? Column(
                    children: [_buildLeftPanel(true), _buildRightPanel(true)])
                : Row(children: [
                    Expanded(flex: 4, child: _buildLeftPanel(false)),
                    Expanded(flex: 6, child: _buildRightPanel(false))
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel(bool isMobile) {
    return Container(
      height: isMobile ? 300 : double.infinity,
      color: const Color(0xFF0F172A),
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: DotPainter(),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: isMobile ? 100 : 140,
                  height: isMobile ? 100 : 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: ClipOval(
                    child: Image.asset('image/Logo.jpg', fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'ระบบวันลา',
                  style: GoogleFonts.sarabun(
                    color: Colors.white,
                    fontSize: isMobile ? 28 : 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'และข้อมูลบุคลากรออนไลน์\nเพื่อครูและบุคลากรทางการศึกษา',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.sarabun(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'ระบบบริหารจัดการโรงเรียน v2.0',
                  style: GoogleFonts.sarabun(
                    color: Colors.white24,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical:
            isMobile ? 30 : 40, // 📏 ลด Padding แนวตั้งลงเพื่อกันล้นครับ 🥇
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile) ...[
            Text(
              'เข้าสู่ระบบ',
              style: GoogleFonts.sarabun(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ยินดีต้อนรับกลับ! กรุณากรอกข้อมูลเพื่อล็อกอิน',
              style: GoogleFonts.sarabun(
                color: const Color(0xFF94A3B8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32), // 📏 ลดช่องว่างลงครับ
          ] else
            const SizedBox(height: 10),
          _buildFieldLabel('ชื่อผู้ใช้งาน'),
          const SizedBox(height: 6),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              hintText: 'Username / ID',
              prefixIcon: const Icon(Icons.person_outline,
                  size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: GoogleFonts.sarabun(color: Colors.black),
          ),
          const SizedBox(height: 20), // 📏 ลดช่องว่างลงครับ
          _buildFieldLabel('รหัสผ่าน'),
          const SizedBox(height: 6),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline,
                  size: 20, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: GoogleFonts.sarabun(color: Colors.black),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (v) =>
                          setState(() => _rememberMe = v ?? false),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      activeColor: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'จำการเข้าสู่ระบบ',
                    style: GoogleFonts.sarabun(
                        color: const Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text(
                  'แจ้งลืมรหัสผ่าน',
                  style: GoogleFonts.sarabun(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32), // 📏 ลดช่องว่างลงครับ
          ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'เข้าสู่ระบบ',
                        style: GoogleFonts.sarabun(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String t) {
    return Text(
      t,
      style: GoogleFonts.sarabun(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: const Color(0xFF64748B),
      ),
    );
  }
}

class DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0;

    const spacing = 15.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
