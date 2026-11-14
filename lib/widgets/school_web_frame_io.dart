/// นอกเว็บไม่แสดง iframe — แสดงข้อความแจ้งแทน
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_tokens.dart';

class SchoolWebFrame extends StatelessWidget {
  final String url;

  const SchoolWebFrame({
    super.key,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          'เว็บโรงเรียนรองรับการเปิดใช้งานบนเบราว์เซอร์ ($url)',
          style: GoogleFonts.sarabun(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
