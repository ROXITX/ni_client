// Simple debugging script to test session status logic
// Run with: dart debug_sessions.dart

void main() {
  print('🔍 Debug Session Status Logic');
  print('Current time: ${DateTime.now()}');
  
  // Test date parsing
  testDateParsing();
  
  // Test time parsing  
  testTimeParsing();
  
  // Test session status logic
  testSessionStatusLogic();
}

void testDateParsing() {
  print('\n📅 Testing Date Parsing:');
  
  final testDates = [
    '2025-11-24',  // Expected format for session 812
    'Nov 24, 2025',
    '2025-12-01',  // Expected format for session 813 
    'Dec 01, 2025',
  ];
  
  for (final dateStr in testDates) {
    try {
      final parsed = _parseSessionDate(dateStr);
      print('✅ "$dateStr" -> $parsed');
    } catch (e) {
      print('❌ "$dateStr" -> Error: $e');
    }
  }
}

void testTimeParsing() {
  print('\n⏰ Testing Time Parsing:');
  
  final testTimes = [
    '09:00 AM - 10:00 AM',
    '2:00 PM - 3:00 PM', 
    '7:00 AM - 8:00 AM',
    '11:00 AM - 12:00 PM',
  ];
  
  for (final timeStr in testTimes) {
    try {
      final parsed = _parseTimeRange(timeStr);
      print('✅ "$timeStr" -> start: ${parsed['start']} minutes, end: ${parsed['end']} minutes');
    } catch (e) {
      print('❌ "$timeStr" -> Error: $e');
    }
  }
}

void testSessionStatusLogic() {
  print('\n🎯 Testing Session Status Logic:');
  
  final now = DateTime.now();
  print('Current time: $now');
  
  // Test sessions that should be "Upcoming" (future dates)
  final futureTests = [
    {'id': '812', 'date': '2025-11-24', 'time': '09:00 AM - 10:00 AM', 'status': 'Pending'},
    {'id': '813', 'date': '2025-12-01', 'time': '2:00 PM - 3:00 PM', 'status': 'Pending'},
  ];
  
  for (final session in futureTests) {
    try {
      final sessionDate = _parseSessionDate(session['date']!);
      final startMinutes = _parseTimeRange(session['time']!)['start'] ?? 0;
      final hours = startMinutes ~/ 60;
      final minutes = startMinutes % 60;
      
      final sessionDateTime = DateTime(sessionDate.year, sessionDate.month, sessionDate.day, hours, minutes);
      final isAfterNow = sessionDateTime.isAfter(now);
      final shouldBeUpcoming = isAfterNow && session['status'] == 'Pending';
      
      print('Session ${session['id']}:');
      print('  📅 Date: ${session['date']} -> $sessionDate');
      print('  ⏰ Time: ${session['time']} -> $sessionDateTime');  
      print('  📊 Current Status: ${session['status']}');
      print('  🔮 Is Future: $isAfterNow');
      print('  ✨ Should be Upcoming: $shouldBeUpcoming');
      print('');
    } catch (e) {
      print('❌ Session ${session['id']} error: $e');
    }
  }
}

// Copy of date parsing logic from home_page.dart
DateTime _parseSessionDate(String dateString) {
  try {
    // Try parsing ISO format first (YYYY-MM-DD)
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) {
      return DateTime.parse(dateString);
    }
    
    // Try parsing "MMM dd, yyyy" format
    if (RegExp(r'^[A-Za-z]{3} \d{1,2}, \d{4}$').hasMatch(dateString)) {
      final parts = dateString.split(' ');
      final month = _parseMonth(parts[0]);
      final day = int.parse(parts[1].replaceAll(',', ''));
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    }
    
    // Try other common formats
    final formats = [
      RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$'), // MM/dd/yyyy
      RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$'), // yyyy/MM/dd
    ];
    
    for (final format in formats) {
      final match = format.firstMatch(dateString);
      if (match != null) {
        if (format == formats[0]) {
          // MM/dd/yyyy
          return DateTime(int.parse(match.group(3)!), int.parse(match.group(1)!), int.parse(match.group(2)!));
        } else {
          // yyyy/MM/dd
          return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
        }
      }
    }
    
    throw FormatException('Unsupported date format: $dateString');
  } catch (e) {
    throw FormatException('Error parsing date "$dateString": $e');
  }
}

int _parseMonth(String monthStr) {
  const monthMap = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    'January': 1, 'February': 2, 'March': 3, 'April': 4, 'May': 5, 'June': 6,
    'July': 7, 'August': 8, 'September': 9, 'October': 10, 'November': 11, 'December': 12,
  };
  
  return monthMap[monthStr] ?? (throw FormatException('Unknown month: $monthStr'));
}

// Copy of time parsing logic from home_page.dart
Map<String, int> _parseTimeRange(String timeRange) {
  try {
    final parts = timeRange.split(' - ');
    if (parts.length != 2) {
      throw FormatException('Invalid time range format');
    }
    
    final startTime = _parseTime(parts[0].trim());
    final endTime = _parseTime(parts[1].trim());
    
    return {
      'start': startTime,
      'end': endTime,
    };
  } catch (e) {
    throw FormatException('Error parsing time range "$timeRange": $e');
  }
}

int _parseTime(String timeStr) {
  try {
    final regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = regex.firstMatch(timeStr);
    
    if (match == null) {
      throw FormatException('Invalid time format');
    }
    
    int hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    
    // Convert to 24-hour format
    if (period == 'PM' && hours != 12) {
      hours += 12;
    } else if (period == 'AM' && hours == 12) {
      hours = 0;
    }
    
    return hours * 60 + minutes; // Return total minutes from midnight
  } catch (e) {
    throw FormatException('Error parsing time "$timeStr": $e');
  }
}