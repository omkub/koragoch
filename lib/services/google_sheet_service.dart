import 'package:http/http.dart' as http;

class GoogleSheetService {
  // รหัสไฟล์ Google Sheets ของคุณครับ
  static const String spreadsheetId = '1rei51ixTtvXGhxHkrApum6M_lpfGxDGr-QFMqB0_4c4';

  static Future<List<List<dynamic>>> fetchSheet(String sheetName) async {
    // ใช้ export?format=csv เพื่อดึงข้อมูลดิบมาล้างและจัดระเบียบใหม่ครับ
    final url = 'https://docs.google.com/spreadsheets/d/$spreadsheetId/gviz/tq?tqx=out:csv&sheet=$sheetName';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<List<dynamic>> data = [];
        
        // แก้ไขจุดสำคัญ: ใช้ RegExp เพื่อรองรับการตัดบรรทัดทั้งแบบ \n, \r\n และ \r ครับ 
        // ป้องกันข้อมูลกองรวมกันเป็นบรรทัดเดียว
        final lines = response.body.split(RegExp(r'\r\n|\n|\r'));
        
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          
          List<String> parsedLine = _parseCsvLine(line);
          // ล้างค่าว่างส่วนเกินและเครื่องหมายคำพูดที่ติดมาครับ
          data.add(parsedLine.map((e) => e.trim().replaceAll(RegExp(r'^"|"$'), '')).toList());
        }
        return data;
      }
    } catch (e) {
      print('Fetch Error ($sheetName): $e');
    }
    return [];
  }

  // ระบบแกะข้อมูล CSV ที่ทนทานต่อเครื่องหมายคำพูดและคอมม่าในข้อความครับ
  static List<String> _parseCsvLine(String line) {
    List<String> result = [];
    bool inQuotes = false;
    StringBuffer currentField = StringBuffer();

    for (int i = 0; i < line.length; i++) {
        int charCode = line.codeUnitAt(i);
        String char = String.fromCharCode(charCode);

        if (char == '"') {
            inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
            result.add(currentField.toString());
            currentField.clear();
        } else {
            currentField.write(char);
        }
    }
    result.add(currentField.toString());
    return result;
  }
}
