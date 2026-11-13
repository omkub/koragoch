import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 🚀 ล็อกอินผ่าน Supabase แล้วครับ
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'responsive_layout.dart';
import '../services/firebase_service.dart'; // 🛡️ นำเข้า FirebaseService ครับ 🥇🏆
import '../utils/school_info.dart';
import '../utils/staff_status.dart';
import '../widgets/install_app_button.dart';
import '../widgets/school_logo.dart';
import '../theme/app_tokens.dart';

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

  /// โลโก้โรงเรียนที่จำไว้จากการล็อกอินครั้งก่อน (null = ไอคอนกลาง)
  String? _savedLogo;

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
    // เครื่องที่จำการเข้าระบบไว้ ขึ้นโลโก้โรงเรียนของบัญชีนั้นเลย
    // (ไม่ได้จำ = หน้าล็อกอินกลาง ไม่มีโลโก้ ไม่รู้ว่าเป็นโรงเรียนไหน)
    final logo = await SchoolInfo.savedLogo();

    if (mounted) {
      setState(() {
        _rememberMe = true;
        _savedLogo = logo;
      });
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

      if (username.isEmpty || password.isEmpty) {
        _showError('กรอกชื่อผู้ใช้และรหัสผ่าน');
        return;
      }

      // 🛡️ [ด่านตรวจที่ 1] ตรวจรหัสผ่านด้วย Supabase Auth
      //
      // ต้องทำเป็นขั้นแรกสุดเสมอ เพราะหลังเปิด RLS แล้วผู้ที่ยังไม่ล็อกอิน
      // (anon) อ่านตาราง Teachers ไม่ได้อีกต่อไป — ของเดิมที่ไปอ่านตารางก่อน
      // เพื่อหา username จึงใช้ไม่ได้แล้ว
      //
      // ทางถอยเดิมที่เทียบกับคอลัมน์ password ตรง ๆ ถูกตัดออกแล้ว
      // Supabase Auth (bcrypt) คือทางเดียวที่ใช้ตรวจรหัสผ่าน
      try {
        await supabase.auth.signInWithPassword(
          email: FirebaseService.authEmailForUsername(username),
          password: password,
        );
      } on AuthException catch (e) {
        debugPrint('ℹ️  Supabase Auth ปฏิเสธ: ${e.message}');
        _showError('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง\n'
            'ถ้าเพิ่งกดแจ้งลืมรหัสผ่าน กรุณารอรหัสชั่วคราวจากแอดมินก่อนนะครับ');
        return;
      }

      // 🛡️ [ด่านตรวจที่ 1.5] บุคลากรที่ลาออก/เกษียณ/ย้ายแล้ว เข้าระบบไม่ได้
      //
      // ฐานข้อมูลซ่อนแถวของคนพ้นสภาพอยู่แล้ว (supabase/staff_status.sql)
      // ถ้าไม่ถามตรงนี้ จะขึ้นว่า "ยังไม่ได้ผูกกับข้อมูลบุคลากร" ซึ่งชวนสับสน
      // ยังไม่ได้รัน SQL = ไม่มีฟังก์ชันนี้ = ข้ามไป (ทำงานแบบเดิม)
      final employmentStatus = await FirebaseService.myEmploymentStatus();
      if (employmentStatus != null &&
          employmentStatus != StaffStatus.active) {
        await supabase.auth.signOut();
        _showError('บัญชีนี้พ้นสภาพแล้ว '
            '(${StaffStatus.label(employmentStatus)}) จึงเข้าระบบไม่ได้\n'
            'ถ้าไม่ถูกต้อง กรุณาแจ้งผู้ดูแลระบบของโรงเรียน');
        return;
      }

      // 🛡️ [ด่านตรวจที่ 2] ดึงข้อมูลของตัวเองจากตาราง Teachers
      //
      // ตอนนี้มี session แล้ว จึงอ่านผ่าน RLS ได้ และค้นด้วย auth_uid
      // ซึ่งผูกกับบัญชีที่เพิ่งล็อกอิน ปลอมเป็นคนอื่นไม่ได้
      final authUid = supabase.auth.currentUser?.id;
      final rows = await supabase
          .from('Teachers')
          .select()
          .eq('auth_uid', authUid as Object)
          .limit(1);
      if (rows.isEmpty) {
        await supabase.auth.signOut();
        _showError('บัญชีนี้ยังไม่ได้ผูกกับข้อมูลบุคลากร\n'
            'กรุณาแจ้งผู้ดูแลระบบให้ตรวจสอบให้อีกครั้ง');
        return;
      }
      userData = Map<String, dynamic>.from(rows.first as Map);
      // Supabase ใช้ id_user (เลขรัน) เป็น PK ส่วน doc id เดิมของ Firebase อยู่ที่ firebase_uid
      final teacherPk = userData['id_user'];
      final teacherDocId =
          (userData['firebase_uid'] ?? teacherPk ?? '').toString();

      // 🚀 หาชื่อสิทธิ์จาก id_role -> roles.Accessrights
      final effectiveRole = await _resolveRoleFromSupabase(supabase, userData);

      final forgotStatus = (userData['forgotPasswordStatus'] ?? '').toString();

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

      // ชื่อโรงเรียนมาจากตาราง Schools — อ่านได้ต่อเมื่อล็อกอินแล้ว (RLS)
      // โหลดตรงนี้เพื่อให้ใบลาที่เปิดหลังจากนี้ได้ชื่อจริง ไม่ใช่ค่าสำรอง
      // force: คนก่อนหน้าบนเครื่องนี้อาจอยู่คนละโรงเรียน ห้ามใช้ค่าเก่าค้าง
      await SchoolInfo.load(force: true);
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
        backgroundColor: AppColors.text));
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
                          () => errorText = 'กรอกชื่อผู้ใช้งาน');
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
                          'ส่งคำขอแล้ว',
                          'แจ้งผู้ดูแลระบบแล้ว\nเมื่อได้รหัสชั่วคราวจากแอดมิน\nให้นำมากรอกในช่องรหัสผ่านที่หน้าเข้าสู่ระบบได้เลย');
                    } catch (e) {
                      setDialogState(() {
                        isProcessing = false;
                        errorText =
                            e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  }

                  return AlertDialog(
                    backgroundColor: AppColors.card,
                    surfaceTintColor: AppColors.card,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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
                                      color: AppColors.textMuted),
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
                                  style: GoogleFonts.sarabun(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'ระบุชื่อผู้ใช้งาน',
                                    prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 20),
                                    filled: true,
                                    fillColor: AppColors.page,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                if (errorText != null) ...[
                                  const SizedBox(height: 10),
                                  Text(errorText!,
                                      style: GoogleFonts.sarabun(
                                          fontSize: 12,
                                          color: AppColors.negative)),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isProcessing ? null : submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.text,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
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
                                                fontWeight: FontWeight.w600)),
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
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w600)),
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.lock_reset_rounded, color: AppColors.text),
              const SizedBox(width: 10),
              Expanded(
                child: Text('ตั้งรหัสผ่านใหม่',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
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
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 18),
                  field('รหัสผ่านใหม่', newCtrl, autofocus: true),
                  field('ยืนยันรหัสผ่านใหม่', confirmCtrl),
                  if (errorText != null)
                    Text(errorText!,
                        style: GoogleFonts.sarabun(
                            fontSize: 12, color: AppColors.negative)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text('ยกเลิก',
                    style: GoogleFonts.sarabun(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.text,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('บันทึกและเข้าสู่ระบบ',
                    style: GoogleFonts.sarabun(fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_reset_rounded,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: AppText.title)),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.panel)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                size: 28, color: AppColors.positive),
            const SizedBox(height: 16),
            Text(title, style: AppText.title),
            const SizedBox(height: 8),
            Text(msg, style: AppText.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('ตกลง'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogFieldLabel(String t) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(t,
          style: AppText.style(13,
              weight: FontWeight.w500, color: AppColors.textSecondary)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 900;

    return Scaffold(
      backgroundColor: isMobile ? AppColors.card : AppColors.page,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isMobile ? screenWidth : 960,
            height: isMobile ? null : 600,
            constraints: isMobile
                ? BoxConstraints(minHeight: MediaQuery.of(context).size.height)
                : null,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: isMobile
                  ? BorderRadius.zero
                  : BorderRadius.circular(AppRadius.panel),
              border: isMobile ? null : Border.all(color: AppColors.line),
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

  /// แผงซ้าย: พื้นหมึกน้ำเงินกรมท่า + ตราโรงเรียน + ชื่อระบบ
  Widget _buildLeftPanel(bool isMobile) {
    final schoolName = SchoolInfo.fullName.trim();
    return Container(
      height: isMobile ? 240 : double.infinity,
      width: double.infinity,
      color: AppColors.accent,
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      child: Column(
        mainAxisAlignment:
            isMobile ? MainAxisAlignment.end : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isMobile ? 64 : 88,
            height: isMobile ? 64 : 88,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: SchoolLogo(
              dataUrl: _savedLogo,
              size: isMobile ? 48 : 72,
              iconColor: AppColors.textMuted,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Text(
            'ระบบวันลา',
            style: AppText.style(isMobile ? 28 : 32,
                weight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            schoolName.isEmpty
                ? 'ยื่นใบลา ขอไปราชการ และพิมพ์แบบฟอร์มของครูและบุคลากร'
                : 'ใบลาและไปราชการของครูและบุคลากร\n$schoolName',
            style: AppText.style(14,
                color: Colors.white.withValues(alpha: 0.78), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 56,
        vertical: isMobile ? 32 : 40,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('เข้าสู่ระบบ', style: AppText.style(isMobile ? 22 : 28, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('ใช้ชื่อผู้ใช้และรหัสผ่านที่ได้จากผู้ดูแลระบบของโรงเรียน',
              style: AppText.secondary),
          const SizedBox(height: 32),
          _buildFieldLabel('ชื่อผู้ใช้งาน'),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              hintText: 'ชื่อผู้ใช้',
              prefixIcon: Icon(Icons.person_outline,
                  size: 18, color: AppColors.textMuted),
            ),
            style: AppText.body,
          ),
          const SizedBox(height: 16),
          _buildFieldLabel('รหัสผ่าน'),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _login(),
            decoration: const InputDecoration(
              hintText: '••••••••',
              prefixIcon: Icon(Icons.lock_outline,
                  size: 18, color: AppColors.textMuted),
            ),
            style: AppText.body,
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
                      activeColor: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('จำการเข้าสู่ระบบ', style: AppText.secondary),
                ],
              ),
              TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text('ลืมรหัสผ่าน',
                    style: AppText.style(13,
                        weight: FontWeight.w500, color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('เข้าสู่ระบบ',
                      style: AppText.style(14,
                          weight: FontWeight.w500, color: Colors.white)),
            ),
          ),
          // ติดตั้งลงเครื่อง (ซ่อนเองถ้าเปิดจากแอปที่ติดตั้งแล้ว)
          const SizedBox(height: 12),
          const InstallAppButton(),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String t) {
    return Text(t,
        style: AppText.style(13,
            weight: FontWeight.w500, color: AppColors.textSecondary));
  }
}
