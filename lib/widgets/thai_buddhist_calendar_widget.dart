import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🕵️‍♂️ Premium Thai Buddhist Calendar Widget (Modern UI) 🥇🏆
/// ออกแบบมาให้เหมือนกับรูปภาพอ้างอิง แต่เปลี่ยนเป็นภาษาไทยและปี พ.ศ. ทั้งหมดครับ
class ThaiBuddhistCalendarWidget extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onDateSelected;

  const ThaiBuddhistCalendarWidget({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  });

  @override
  State<ThaiBuddhistCalendarWidget> createState() => _ThaiBuddhistCalendarWidgetState();
}

class _ThaiBuddhistCalendarWidgetState extends State<ThaiBuddhistCalendarWidget> {
  late DateTime _focusedDate;
  DateTime? _selectedDate;

  final List<String> _months = [
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
    'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'
  ];

  @override
  void initState() {
    super.initState();
    _focusedDate = widget.initialDate;
    _selectedDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency, // 🛡️ ป้องกันหน้าจอแดง "No Material widget found" ครับ 🥇🏆
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 📅 Header - Month & Year Dropdowns 🥇🏆
          Row(
            children: [
              Expanded(child: _buildMonthDropdown()),
              const SizedBox(width: 12),
              Expanded(child: _buildYearDropdown()),
            ],
          ),
          const SizedBox(height: 24),
          
          // 🗓️ Weekdays Header (M T W T F S S style) 🕵️‍♂️✨
          _buildWeekdaysHeader(),
          const SizedBox(height: 12),

          // 🔢 Days Grid
          _buildDaysGrid(),
          const SizedBox(height: 32),

          // 🔘 Footer Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: const Color(0xFFF1F5F9),
                  ),
                  child: Text("ย้อนกลับ", style: GoogleFonts.sarabun(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedDate != null) {
                      widget.onDateSelected(_selectedDate!);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: const Color(0xFF2563EB), // Premium Blue
                    elevation: 0,
                  ),
                  child: Text("ตกลง", style: GoogleFonts.sarabun(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildMonthDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _focusedDate.month,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          items: List.generate(12, (index) => DropdownMenuItem(
            value: index + 1,
            child: Text(_months[index], style: GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
          )),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _focusedDate = DateTime(_focusedDate.year, val, 1);
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildYearDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _focusedDate.year,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          items: List.generate(widget.lastDate.year - widget.firstDate.year + 1, (index) {
            int yearCE = widget.firstDate.year + index;
            return DropdownMenuItem(
              value: yearCE,
              child: Text("${yearCE + 543}", style: GoogleFonts.sarabun(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
            );
          }),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _focusedDate = DateTime(val, _focusedDate.month, 1);
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildWeekdaysHeader() {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) => Expanded(
        child: Center(
          child: Text(day, style: GoogleFonts.sarabun(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8))),
        ),
      )).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final int daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final int firstWeekday = DateTime(_focusedDate.year, _focusedDate.month, 1).weekday; // 1=Mon, 7=Sun
    
    // 🕵️‍♂️ ปรับให้เริ่มที่วันจันทร์ตามรูปครับ (1=Mon, 2=Tue... 7=Sun)
    final int emptyCells = firstWeekday - 1;

    List<Widget> dayWidgets = [];
    
    // Empty cells
    for (int i = 0; i < emptyCells; i++) {
        dayWidgets.add(const SizedBox());
    }

    // Days
    for (int day = 1; day <= daysInMonth; day++) {
      final DateTime currentDay = DateTime(_focusedDate.year, _focusedDate.month, day);
      final bool isSelected = _selectedDate != null && 
          _selectedDate?.day == day && 
          _selectedDate?.month == _focusedDate.month && 
          _selectedDate?.year == _focusedDate.year;
      
      final bool isToday = DateTime.now().day == day && 
          DateTime.now().month == _focusedDate.month && 
          DateTime.now().year == _focusedDate.year;

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = currentDay;
            });
          },
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFEF4444) : Colors.transparent, // Modern Red
                shape: BoxShape.circle,
                border: isToday && !isSelected ? Border.all(color: const Color(0xFF2563EB).withOpacity(0.5)) : null,
              ),
              child: Center(
                child: Text(
                  "$day",
                  style: GoogleFonts.sarabun(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ),
        )
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 8,
      crossAxisSpacing: 0,
      children: dayWidgets,
    );
  }
}
