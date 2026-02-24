import 'package:intl/intl.dart' as intl;

class AppDateUtils {
  static String dateToStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String monthShort(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];

  static String weekdayShort(int w) => const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][w % 7];

  /// Parse session date from various formats in the database
  static DateTime parseSessionDate(String dateStr) {
    // First try parsing standard DateTime format (handles various ISO formats)
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      // If that fails, try parsing custom date formats
    }
    
    // Try parsing "MMM dd, yyyy" format (e.g. "Nov 24, 2025")
    try {
      return intl.DateFormat('MMM dd, yyyy').parse(dateStr);
    } catch (e) {
      // Try MMM d, yyyy (single digit day)
      try {
        return intl.DateFormat('MMM d, yyyy').parse(dateStr);
      } catch (_) {}
    }
    
    // Try parsing "dd-MM-yyyy" format by splitting on hyphens
    try {
      final dateParts = dateStr.split('-');
      if (dateParts.length == 3) {
        final day = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]); 
        final year = int.parse(dateParts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // If that fails, try yyyy-MM-dd format
    }
    
    // Try parsing "yyyy-MM-dd" format
    try {
      final dateParts = dateStr.split('-');
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      // If all else fails
    }
    
    throw FormatException('Unable to parse date: $dateStr');
  }

  /// Check if a session date is in the future (compared to today)
  static bool isSessionDateInFuture(String sessionDateStr) {
    try {
      final sessionDate = parseSessionDate(sessionDateStr);
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final sessionOnlyDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
      return sessionOnlyDate.isAfter(todayDate) || sessionOnlyDate.isAtSameMomentAs(todayDate);
    } catch (e) {
      return false;
    }
  }

  static Map<String, int> parseTimeRange(String timeRange) {
    // Normalize string: ensure space around hyphens, remove extra spaces
    String cleaned = timeRange.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Handle "10:00AM - 11:00AM" vs "10:00 AM - 11:00 AM" vs "10:00AM-11:00AM"
    if (!cleaned.contains(' - ') && cleaned.contains('-')) {
        cleaned = cleaned.replaceAll('-', ' - ');
    }
    
    final parts = cleaned.split(' - ');
    if (parts.length < 2) return {'start': 0, 'end': 0};

    int toMinutes(String s) {
      s = s.trim();
      final isPm = s.toUpperCase().contains('PM');
      final isAm = s.toUpperCase().contains('AM');
      
      // Remove AM/PM/Space to get just time
      String timePart = s.replaceAll(RegExp(r'[ A-Za-z]'), ''); 
      final hm = timePart.split(':');
      if (hm.length < 2) return 0;
      
      int h = int.parse(hm[0]);
      int m = int.parse(hm[1]);
      
      if (isPm && h < 12) h += 12;
      if (isAm && h == 12) h = 0;
      return h * 60 + m;
    }

    return {
      'start': toMinutes(parts[0]),
      'end': toMinutes(parts[1]),
    };
  }

  static DateTime? parseSessionDateTime(String dateStr, String timeStr) {
    try {
      final date = parseSessionDate(dateStr);
      final range = parseTimeRange(timeStr);
      // Ensure we start from midnight of that date
      final midnight = DateTime(date.year, date.month, date.day);
      return midnight.add(Duration(minutes: range['start']!));
    } catch (e) {
      return null;
    }
  }

  static String determineSessionStatus(String currentStatus, String dateStr, String timeStr) {
    if (currentStatus == 'Completed' || currentStatus == 'Cancelled') {
      return currentStatus;
    }

    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final nowInMinutes = now.hour * 60 + now.minute;

      final sessionDate = parseSessionDate(dateStr);
      final sessionOnlyDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

      if (sessionOnlyDate.isBefore(todayDate)) {
        return 'Pending';
      } else if (sessionOnlyDate.isAfter(todayDate)) {
        return 'Upcoming';
      } else {
        // Today
        final range = parseTimeRange(timeStr);
        final startMinutes = range['start'] ?? 0;
        return (nowInMinutes >= startMinutes) ? 'Pending' : 'Upcoming';
      }
    } catch (e) {
      return currentStatus;
    }
  }
}
