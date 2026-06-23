import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'screens/responsive_layout.dart';

import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:thai_buddhist_date/thai_buddhist_date.dart' as tbd;

Future<void> clearSessionPrefs(SharedPreferences prefs) async {
  await prefs.remove('isLoggedIn');
  await prefs.remove('loginAt');
  await prefs.remove('currentUser');
  await prefs.remove('userRole');
  await prefs.remove('userFullDataJson');
}

Future<void> main() async {
  // 🔥 ขั้นตอนที่ปลอดภัยที่สุด: รอให้ระบบพื้นฐานโหลดเสร็จก่อนเริ่มแอปครับ 🥇🚀
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 🛡️ โหลด Firebase ให้เสร็จตรงนี้เลย เพื่อป้องกันหน้าขาวค้างในหน้าถัดไปครับ
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // 🛡️ เพิ่มการ "หน่วงเวลา" เล็กน้อยเพื่อให้ Pigeon Channel (JS Bridge) ตั้งตัวได้ทันบนความเร็วเน็ตจริงครับ 🥇🏆
  } catch (e) {
    debugPrint("Firebase Initialize Error: $e");
  }

  // แสดงหน้าแรกก่อน แล้วค่อยอุ่นเครื่องระบบวันที่ไทยเพื่อลดเวลารอหน้า Login
  runApp(const MyApp());

  tbd.ThaiDateService()
      .initializeLocale('th_TH')
      .catchError((e) => debugPrint("Thai Date Initialize Error: $e"));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // เริ่มต้นด้วยหน้า Login ทันทีให้ไวที่สุดครับ🛒🏁
  Widget _homeWidget = const LoginScreen();

  @override
  void initState() {
    super.initState();
    _handleBackgroundStartup();
  }

  // 🔥 จัดการเช็คการล็อกอินเบื้องหลังครับ 🛡️
  Future<void> _handleBackgroundStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final int? loginAt = prefs.getInt('loginAt');

      if (isLoggedIn && loginAt != null) {
        // ตรวจสอบอายุการล็อกอิน (ตัวอย่าง 2 ชั่วโมง)
        if ((DateTime.now().millisecondsSinceEpoch - loginAt) <
            (2 * 60 * 60 * 1000)) {
          // 🛡️ ป้องกัน Race Condition: รอให้ FirebaseAuth ดึง Session กลับมาจาก IndexedDB ก่อนเริ่มวิ่ง 🥇🏆
          // ป้องกันหน้าขาวในจังหวะ Refresh หน้าเว็บครับ
          final user = await FirebaseAuth.instance.authStateChanges().first;

          if (user != null) {
            if (mounted) setState(() => _homeWidget = const ResponsiveLayout());
          } else {
            // 🚨 ถ้ากุญแจหายไป (อาจเพราะโดนบล็อกการสร้างบัญชี) ให้ล้างแคชทิ้งและบังคับล็อกอินใหม่ครับ!
            await clearSessionPrefs(prefs);
            if (mounted) setState(() => _homeWidget = const LoginScreen());
          }
        } else {
          await clearSessionPrefs(prefs);
        }
      }
    } catch (e) {
      debugPrint("Startup Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบวันลา',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E293B)),
        useMaterial3: true,
        textTheme: GoogleFonts.sarabunTextTheme(),
      ),
      // 🇹🇭 เปิดโหมดภาษาไทยให้แอปครับ 🥇🏆
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'), // ไทย
        Locale('en', 'US'), // อังกฤษ
      ],
      locale: const Locale('th', 'TH'), // บังคับใช้ภาษาไทยเป็นค่าเริ่มต้นครับ
      // 🔥 บังคับใช้ฟิสิกส์การเลื่อนแบบหยุดกึก (Clamping) เพื่อไม่ให้ติด Bug ใน LINE Browser ครับ 🥇🏆
      scrollBehavior: const MyScrollBehavior(),
      // โชว์หน้า Login ทันที! (ไม่มีหน้าแดง ไม่มีค้างแน่นอนครับ)🏁🏆🥇🚀
      home: _homeWidget,
    );
  }
}

// 🚀 คลาสควบคุมพฤติกรรมการเลื่อน (Custom Scroll Behavior) 🕵️‍♂️🥇🏆
class MyScrollBehavior extends MaterialScrollBehavior {
  const MyScrollBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // ซ่อน Scrollbar ของ Browser หากต้องการ
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // ปิดเอฟเฟกต์การเด้ง (Glow/Bounce) ที่ขอบจอ
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // 🥇 บังคับใช้ Clamping เพื่อป้องกันระบบ "ลากเพื่อปิด" ของ LINE Browser ครับ 🏆
    return const ClampingScrollPhysics();
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
