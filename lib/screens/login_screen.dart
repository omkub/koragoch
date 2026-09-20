import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🚀 ล็อกอินผ่าน Supabase แล้วครับ
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
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

  // 🚀 หา "ชื่อสิทธิ์" (ครู/ผู้บริหาร/ผู้ดูแลระบบ) จาก Supabase ครับ
  // Supabase เก็บสิทธิ์เป็น id_role (FK) ในตาราง Teachers แล้วไปอ้างชื่อจริงที่ roles.Accessrights
  // (คนละแบบกับ Firebase เดิมที่เก็บชื่อสิทธิ์เป็น string ตรงๆ บน Teacher)
  Future<String> _resolveRoleFromSupabase(
    SupabaseClient supabase,
    Map<String, dynamic> userData,
  ) async {
    // เผื่อบางแถวมีชื่อสิทธิ์เก็บตรงๆ อยู่แล้ว ใช้ได้เลย
    final direct = _resolveEffectiveRole([
      userData['role'],
      userData['permission'],
    ]);
    if (direct != 'ครู') return direct;

    final idRole = userData['id_role'];
    if (idRole != null) {
      try {
        final rows = await supabase
            .from('roles')
            .select('Accessrights')
            .eq('ID_Roles', idRole)
            .limit(1);
        if (rows.isNotEmpty) {
          final name = (rows.first['Accessrights'] ?? '').toString().trim();
          if (name.isNotEmpty) return _resolveEffectiveRole([name]);
        }
      } catch (e) {
        debugPrint('resolve role error: $e');
      }
    }
    return direct;
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 🚀 ล็อกอินผ่าน Supabase Auth (รหัสผ่านแฮชด้วย bcrypt)
      // ยังคงอ่านตาราง Teachers เพื่อเอาสิทธิ์/สถานะรีเซ็ตรหัสมาใช้เหมือนเดิม
      final supabase = Supabase.instance.client;

      final String username = _usernameController.text.trim();
      final String password = _passwordController.text.trim();
      bool loginSuccess = false;
      Map<String, dynamic>? userData;

      // 🛡️ [ด่านตรวจที่ 0] หาผู้ใช้จากตาราง Teachers (Supabase) ด้วย username
      final rows = await supabase
          .from('Teachers')
          .select()
          .eq('username', username)
          .limit(1);
      if (rows.isEmpty) {
        _showError('ไม่พบข้อมูลผู้ใช้งานนี้ในระบบครับ');
        return;
      }
      userData = Map<String, dynamic>.from(rows.first as Map);
      // Supabase ใช้ id_user (เลขรัน) เป็น PK ส่วน doc id เดิมของ Firebase อยู่ที่ firebase_uid
      final teacherPk = userData['id_user'];
      final teacherDocId =
          (userData['firebase_uid'] ?? teacherPk ?? '').toString();

      // 🚀 หาชื่อสิทธิ์จาก id_role -> roles.Accessrights
      final effectiveRole = await _resolveRoleFromSupabase(supabase, userData);

      // 🛡️ [ด่านตรวจที่ 1] อยู่ระหว่างรอแอดมินออกรหัสชั่วคราวหรือไม่
      //
      // ถ้าแอดมินออกรหัสให้แล้ว (reset_by_admin) จะไม่บล็อกที่นี่ — ปล่อยให้ตรวจ
      // รหัสตามปกติ เพราะรหัสชั่วคราวคือรหัสผ่านจริงชั่วคราว แล้วค่อยเด้งให้
      // ตั้งรหัสใหม่หลังผ่านด่านรหัสผ่าน (ดูด้านล่าง)
      final forgotStatus = (userData['forgotPasswordStatus'] ?? '').toString();
      if (forgotStatus == 'waiting') {
        _showError(
            '⚠️ คำขอรีเซ็ตรหัสผ่านของคุณครูกำลังรอแอดมินอนุมัติครับ\nเมื่อได้รหัสชั่วคราวแล้วนำมากรอกในช่องรหัสผ่านนี้ได้เลย');
        return;
      }
      // 🔄 ถ้าในฐานข้อมูลเป็น MIGRATED หรือผู้ใช้กรอกรหัสด้วย MIGRATED
      // ให้อัปเดตรหัสผ่านใน Supabase เป็น 123456 ทันที และอนุญาตให้เข้าใช้งานได้เลย
      final String dbPassword = userData['password']?.toString().trim() ?? '';
      final bool isMigrated = dbPassword == 'MIGRATED' || password == 'MIGRATED';

      if (isMigrated) {
        await supabase
            .from('Teachers')
            .update({'password': '123456', 'originalPassword': null}).eq(
                'id_user', teacherPk);
        userData['password'] = '123456';
      }

      // 🛡️ [ด่านตรวจที่ 2] ตรวจสอบรหัสผ่าน
      //
      // ทางหลัก: Supabase Auth — รหัสผ่านถูกแฮชด้วย bcrypt ฝั่งเซิร์ฟเวอร์
      // ไม่มีใครอ่านรหัสจริงได้ และได้ session/token มาใช้กับ RLS ต่อ
      bool passValid = false;
      try {
        final authResult = await supabase.auth.signInWithPassword(
          email: FirebaseService.authEmailForUsername(username),
          password: password,
        );
        passValid = authResult.user != null;
      } on AuthException catch (e) {
        debugPrint('ℹ️  Supabase Auth ปฏิเสธ (${e.message}) — จะลองทางเดิมต่อ');
      } catch (e) {
        debugPrint('⚠️  เรียก Supabase Auth ไม่สำเร็จ: $e');
      }

      // ทางถอยชั่วคราว: เทียบกับคอลัมน์ password เดิมในตาราง Teachers
      //
      // มีไว้ให้ช่วงเปลี่ยนผ่านไม่สะดุด — ครูที่ยังไม่มีบัญชี Auth หรือเพิ่งถูก
      // แอดมินรีเซ็ตรหัส (ซึ่งยังเขียนลงคอลัมน์เดิม) จะยังเข้าระบบได้
      // ทางนี้จะถูกตัดออกตอนเปิด RLS เพราะ anon จะอ่านตารางไม่ได้อีกต่อไป
      if (!passValid) {
        passValid = (userData['password'].toString().trim() == password) ||
            (isMigrated && (password == '123456' || password == 'MIGRATED'));
      }

      if (!passValid) {
        _showError('รหัสผ่านไม่ถูกต้องครับ 🔐');
        return;
      }

      // 🔑 [ด่านตรวจที่ 3] เพิ่งใช้ "รหัสชั่วคราว" เข้ามา ต้องตั้งรหัสใหม่ก่อน
      //
      // ตอนแอดมินกดรีเซ็ต ระบบตั้งรหัสชั่วคราวไว้ทั้งใน Auth และคอลัมน์สำเนา
      // ครูจึงผ่านด่านรหัสผ่านมาได้ด้วยรหัสนั้น — บังคับตั้งรหัสใหม่ตรงนี้
      // แล้วพาเข้าระบบต่อเลย ไม่ต้องให้กรอกรหัสใหม่อีกรอบ
      if (forgotStatus == 'reset_by_admin') {
        final newPassword = await _promptNewPasswordAfterReset();
        if (newPassword == null) {
          // ครูกดยกเลิก — ออกจากระบบที่เพิ่งล็อกอินไว้ กันค้างสถานะครึ่ง ๆ กลาง ๆ
          await supabase.auth.signOut();
          return;
        }

        try {
          await _firebaseService.completePasswordReset(
              username, password, newPassword);
        } catch (e) {
          await supabase.auth.signOut();
          _showError(e.toString().replaceFirst('Exception: ', ''));
          return;
        }

        // รหัสใน Auth เพิ่งเปลี่ยน เซสชันเดิมใช้ต่อไม่ได้ ต้องเข้าใหม่ด้วยรหัสใหม่
        try {
          await supabase.auth.signInWithPassword(
            email: FirebaseService.authEmailForUsername(username),
            password: newPassword,
          );
        } catch (e) {
          debugPrint('⚠️  เข้าสู่ระบบด้วยรหัสใหม่ไม่สำเร็จ: $e');
        }

        userData['password'] = newPassword;
        if (_rememberMe) _passwordController.text = newPassword;
      }

      // ✅ ผ่านทุกด่าน = ล็อกอินสำเร็จ (ไม่ต้องพึ่ง FirebaseAuth อีกต่อไป)
      loginSuccess = true;
      // เก็บชื่อสิทธิ์ + id ลงใน userData ให้หน้าจออื่นใช้งานต่อได้เหมือนเดิม
      userData['role'] = effectiveRole;
      userData['permission'] = effectiveRole;
      userData['id'] = teacherDocId;

      // --- 🛡️ 5. เซฟเซสชันและเข้าสู่ระบบ ---
      if (loginSuccess) {
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

        // 🛡️ บันทึกประวัติการเข้าใช้งานลง Supabase (ใช้ id_user) — ไม่แตะ Firebase
        await _firebaseService.logLogin(teacherPk);

        // 🚀 ขั้นสุดยอด: เซฟข้อมูลทั้งก้อนไว้ในเครื่อง พร้อมระบบป้องกัน JSON Error ขั้นเทพ 🥇🏆🏎️
        //
        // เติมชื่อจริงของ ตำแหน่ง/กลุ่มสาระ/วิทยฐานะ ก่อนเก็บ เพราะแถวดิบจาก
        // Teachers เก็บเป็น FK ตัวเลข หน้าจอที่อ่านแคชนี้ (เช่นการ์ดผู้ยื่นใบลา)
        // จะได้ไม่แสดงเป็น "-" ตอนเปิดหน้าครั้งแรก
        final enrichedUser = await _firebaseService.enrichTeacher(userData);

        final safeJson = jsonEncode({
          ...enrichedUser,
          'id': teacherDocId,
          'role': effectiveRole,
          'permission': effectiveRole,
        }, toEncodable: (item) {
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
  /// หน้าต่าง "แจ้งลืมรหัสผ่าน" — กรอกแค่ชื่อผู้ใช้ช่องเดียว
  ///
  /// ขั้นตอนใหม่: แจ้งแอดมิน -> กลับมาหน้าล็อกอินพร้อมชื่อผู้ใช้ที่กรอกไว้
  /// -> พอได้รหัสชั่วคราวก็พิมพ์ในช่องรหัสผ่านหน้าล็อกอินได้เลย
  /// ระบบจะเด้งให้ตั้งรหัสใหม่เองแล้วพาเข้าระบบต่อทันที (ดูที่ _login)
  void _showForgotPasswordDialog() {
    final recoverUserCtrl =
        TextEditingController(text: _usernameController.text.trim());
    bool isProcessing = false;
    String? errorText;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.6),
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
                  Future<void> submit() async {
                    final username = recoverUserCtrl.text.trim();
                    if (username.isEmpty) {
                      setDialogState(
                          () => errorText = 'กรุณากรอกชื่อผู้ใช้งานครับ');
                      return;
                    }
                    setDialogState(() {
                      isProcessing = true;
                      errorText = null;
                    });
                    try {
                      await _firebaseService.requestPasswordReset(username);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!mounted) return;
                      // เติมชื่อผู้ใช้กลับไปที่หน้าล็อกอิน ครูจะได้ไม่ต้องพิมพ์ซ้ำ
                      setState(() {
                        _usernameController.text = username;
                        _passwordController.clear();
                      });
                      _showSuccessDialog(
                          'ส่งคำขอเรียบร้อยแล้ว!',
                          'แจ้งแอดมินให้ทราบแล้วครับ\nเมื่อได้รหัสชั่วคราวจากแอดมิน\nให้นำมากรอกในช่องรหัสผ่านที่หน้าเข้าสู่ระบบได้เลย');
                    } catch (e) {
                      setDialogState(() {
                        isProcessing = false;
                        errorText =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  }

                  return AlertDialog(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36)),
                    contentPadding: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    content: SizedBox(
                      width: 420,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDialogHeader('แจ้งลืมรหัสผ่าน'),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(36, 28, 36, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'กรอกชื่อผู้ใช้งานของคุณครู ระบบจะแจ้งแอดมิน\nให้ออกรหัสชั่วคราวให้ครับ',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.sarabun(
                                      fontSize: 14,
                                      color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 20),
                                _buildDialogFieldLabel(
                                    'ชื่อผู้ใช้งาน (Username)'),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: recoverUserCtrl,
                                  enabled: !isProcessing,
                                  autofocus: true,
                                  onSubmitted: (_) => submit(),
                                  style: GoogleFonts.sarabun(fontSize: 15),
                                  decoration: InputDecoration(
                                    hintText: 'ระบุชื่อผู้ใช้งาน',
                                    prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 20),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                if (errorText != null) ...[
                                  const SizedBox(height: 10),
                                  Text(errorText!,
                                      style: GoogleFonts.sarabun(
                                          fontSize: 12,
                                          color: Colors.red.shade700)),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isProcessing ? null : submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F172A),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ),
                                    child: isProcessing
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : Text('แจ้งแอดมิน',
                                            style: GoogleFonts.sarabun(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: TextButton(
                              onPressed: isProcessing
                                  ? null
                                  : () => Navigator.pop(ctx),
                              child: Text('ยกเลิกและกลับหน้าเดิม',
                                  style: GoogleFonts.sarabun(
                                      color: const Color(0xFF94A3B8),
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
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

  /// หน้าต่างบังคับตั้งรหัสใหม่ ทันทีหลังครูเข้าระบบด้วยรหัสชั่วคราว
  ///
  /// คืนรหัสใหม่ถ้าตั้งสำเร็จ หรือ null ถ้าครูกดยกเลิก
  Future<String?> _promptNewPasswordAfterReset() async {
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void submit() {
            final next = newCtrl.text.trim();
            final confirm = confirmCtrl.text.trim();
            if (next.length < 6) {
              setLocal(() => errorText = 'รหัสผ่านใหม่ต้องยาวอย่างน้อย 6 ตัว');
              return;
            }
            if (next != confirm) {
              setLocal(() => errorText = 'รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน');
              return;
            }
            Navigator.pop(ctx, next);
          }

          Widget field(String label, TextEditingController ctrl,
                  {bool autofocus = false}) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: ctrl,
                  obscureText: true,
                  autofocus: autofocus,
                  onSubmitted: (_) => submit(),
                  style: GoogleFonts.sarabun(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: GoogleFonts.sarabun(fontSize: 13),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFF0F172A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('ตั้งรหัสผ่านใหม่',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
              ),
            ]),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'คุณครูเข้าระบบด้วยรหัสชั่วคราว\nกรุณาตั้งรหัสผ่านใหม่เพื่อใช้งานครั้งต่อไปครับ',
                      style: GoogleFonts.sarabun(
                          fontSize: 13, color: Colors.blueGrey)),
                  const SizedBox(height: 18),
                  field('รหัสผ่านใหม่', newCtrl, autofocus: true),
                  field('ยืนยันรหัสผ่านใหม่', confirmCtrl),
                  if (errorText != null)
                    Text(errorText!,
                        style: GoogleFonts.sarabun(
                            fontSize: 12, color: Colors.red.shade700)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('ยกเลิก',
                    style: GoogleFonts.sarabun(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                onPressed: submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('บันทึกและเข้าสู่ระบบ',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

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
