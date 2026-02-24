import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import '../../models/client.dart';
import '../../models/session.dart';
import '../../models/payment_entry.dart';
import '../../core/utils/date_utils.dart'; // Robust Date Parsing

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static bool _isInitialized = false;
  
  // Scheduling State (Ported from home_page.dart)
  DateTime? _lastScheduleTime;
  bool _isSchedulingNotifications = false;
  bool _rescheduleQueued = false;
  List<Client>? _queuedClientsForReschedule;
  List<Session>? _queuedSessionsForReschedule;
  List<PaymentEntry>? _queuedPaymentsForReschedule;

  // Android 13+ Permission Flag
  bool _androidExactAlarmsGranted = false;

  // --- Initializers ---

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      print('🔔 Initializing Notification Service (Modular Rebuilt)...');
      
      tz.initializeTimeZones();
      await _configureTimezone();

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true, 
        requestBadgePermission: true, 
        requestSoundPermission: true,
        defaultPresentAlert: true, // Show banner in foreground
        defaultPresentBadge: true, // Update badge in foreground
        defaultPresentSound: true, // Play sound in foreground
      );

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
             print('📱 Notification Tapped: ${details.payload}');
        },
      );

      if (Platform.isAndroid) {
         await _createNotificationChannels(); 
         await _requestAndroidPermissions();
      }

      _isInitialized = true;
      print('✅ Notification Service Initialized');
    } catch (e) {
      print('❌ Init Error: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
     final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
     
     if (androidImplementation == null) return;

     // 1. Session Reminders (High Priority)
     const sessionChannel = AndroidNotificationChannel(
       'session_channel_v5',
       'Session Reminders',
       description: 'Reminders for upcoming sessions (2h, 5m)',
       importance: Importance.max,
       playSound: true,
       enableVibration: true,
     );

     // 2. Daily Summary (Default Priority)
     const dailyChannel = AndroidNotificationChannel(
       'daily_channel_v5',
       'Daily Summary',
       description: 'Daily schedule summary at 7 AM',
       importance: Importance.defaultImportance,
       playSound: true,
     );

     // 3. Payment Reminders (High Priority)
     const paymentChannel = AndroidNotificationChannel(
       'payment_channel_v5',
       'Payment Reminders',
       description: 'Reminders for due/overdue payments at 9 AM',
       importance: Importance.high,
       playSound: true,
     );

     await androidImplementation.createNotificationChannel(sessionChannel);
     await androidImplementation.createNotificationChannel(dailyChannel);
     await androidImplementation.createNotificationChannel(paymentChannel);
  }

  Future<void> _requestAndroidPermissions() async {
      final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
          await androidImplementation.requestNotificationsPermission();
          try {
             _androidExactAlarmsGranted = await androidImplementation.requestExactAlarmsPermission() ?? false;
          } catch (_) {
             _androidExactAlarmsGranted = true;
          }
      }
  }

  // --- Public Helpers (Expected by logic) ---

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.areNotificationsEnabled() ?? false;
    } else if (Platform.isIOS) {
       final iosImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
       return await iosImplementation?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return true;
  }

  Future<void> reinitTimezone() async {
    await _configureTimezone();
  }

  // --- Main Scheduling Logic (Ported from home_page.dart) ---

  Future<void> scheduleAllNotifications(List<Client> clients, List<Session> sessions, List<PaymentEntry> payments, {bool force = false}) async {
    // 1. Concurrency Lock
    if (_isSchedulingNotifications) {
      _rescheduleQueued = true;
      _queuedClientsForReschedule = clients;
      _queuedSessionsForReschedule = sessions;
      _queuedPaymentsForReschedule = payments;
      debugPrint('⏳ Scheduling already in progress – deferring new request (sessions=${sessions.length}).');
      return;
    }
    
    // 2. Throttle removed (DashboardBloc handles debounce)
    _isSchedulingNotifications = true;
    _lastScheduleTime = DateTime.now();
    
    try {
      // 3. Clear all previous notifications (Wipe Clean Strategy)
      await flutterLocalNotificationsPlugin.cancelAll();
      
      // 4. Run Logic
      await _scheduleNotificationsBackground(clients, sessions, payments);
      
    } catch (e) {
      print('Notification scheduling error: $e');
    } finally {
      // 5. Handle Queued Re-run
      final queuedFlag = _rescheduleQueued;
      final qClients = _queuedClientsForReschedule;
      final qSessions = _queuedSessionsForReschedule;
      final qPayments = _queuedPaymentsForReschedule;
      
      _rescheduleQueued = false;
      _queuedClientsForReschedule = null;
      _queuedSessionsForReschedule = null;
      _queuedPaymentsForReschedule = null;
      _isSchedulingNotifications = false; // Release lock
      
      if (queuedFlag && qClients != null && qSessions != null && qPayments != null) {
        debugPrint('🔁 Running deferred notification scheduling (sessions=${qSessions.length}).');
        // Recursion with force=true to bypass throttle
        scheduleAllNotifications(qClients, qSessions, qPayments, force: true);
      }
    }
  }

  Future<void> _scheduleNotificationsBackground(List<Client> clients, List<Session> sessions, List<PaymentEntry> payments) async {
    try {
      print('🔔 Starting notification scheduling...');
      
      if (Platform.isAndroid) {
        final enabled = await areNotificationsEnabled();
        print('📣 Android notifications enabled: $enabled');
      }

      // Timezone Guard
      final dartNow = DateTime.now();
      final now = tz.TZDateTime.now(tz.local);
      final tzOffset = now.timeZoneOffset.inMinutes;
      final sysOffset = dartNow.timeZoneOffset.inMinutes;
      
      if (tzOffset == 0 && sysOffset != 0) {
        print('⚠️ TZ offset mismatch (tz=$tzOffset, sys=$sysOffset). Attempting inline timezone fix...');
        await reinitTimezone();
        final retryNow = tz.TZDateTime.now(tz.local);
        final retryOffset = retryNow.timeZoneOffset.inMinutes;
        if (retryOffset == 0 && sysOffset != 0) {
          print('❌ Timezone still mismatched after retry – skipping scheduling this pass');
          return;
        }
      }
      print('📅 Current time: ${tz.TZDateTime.now(tz.local)} (tzOffset=${tz.TZDateTime.now(tz.local).timeZoneOffset.inHours}h)');

      if (sessions.isEmpty && payments.isEmpty) {
        print('❌ No sessions or payments found for notification scheduling');
        return;
      }

      // --- Budget Logic (iOS Limit: 64) ---
      const int totalBudget = 64;
      const int reserveDailySummary = 1;
      int remaining = totalBudget - reserveDailySummary;
      
      // Define Rolling Window (Next 7 Days) for ALL items
      final windowEnd = now.add(const Duration(days: 7));
      print('📅 Scheduling Window: Next 7 Days (Until ${windowEnd.year}-${windowEnd.month}-${windowEnd.day})');

      // --- Step 1: Schedule Payments (High Priority) ---
      // OPTIMIZED: Group Overdues, Individual Future/Today
      int paymentsScheduled = 0;
      
      final List<PaymentEntry> overduePayments = [];
      final List<PaymentEntry> regularPayments = []; // Due Today or Future (in window)

      // 1.1 Classification
      for (final payment in payments) {
         if (payment.isPaid) continue;

         try {
             final due = AppDateUtils.parseSessionDate(payment.dueDate);
             final dueDay = DateTime(due.year, due.month, due.day);
             final today = DateTime(now.year, now.month, now.day);
             
             if (dueDay.isBefore(today)) {
                overduePayments.add(payment);
             } else {
                 final dueTz = tz.TZDateTime.from(due, tz.local);
                 // Only add if within window (e.g. next 7 days) to avoid clogging
                 if (dueTz.isBefore(windowEnd)) {
                    regularPayments.add(payment);
                 }
             }
         } catch (_) {}
      }

      // 1.2 Schedule Overdue (Grouped or Single)
      if (overduePayments.isNotEmpty) {
          if (overduePayments.length > 1) {
             if (remaining > 0) {
                 await _scheduleGroupedPaymentReminder(overduePayments.length);
                 paymentsScheduled++;
                 remaining--;
             }
          } else {
             // Schedule Single Specific Overdue
             if (remaining > 0) {
                 final payment = overduePayments.first;
                 final client = clients.firstWhere((c) => c.id == payment.clientId, orElse: () => Client.empty());
                 if (client.id != 0) {
                    final used = await _schedulePaymentReminderInternal(payment, client.firstName);
                    if (used > 0) {
                        paymentsScheduled++;
                        remaining -= used;
                    }
                 }
             }
          }
      }

      // 1.3 Schedule Regular (Due Today / Future) - Individually
      for (final payment in regularPayments) {
         if (remaining <= 0) break;
         
         final client = clients.firstWhere((c) => c.id == payment.clientId, orElse: () => Client.empty());
         if (client.id != 0) {
             // _schedulePaymentReminderInternal handles "due today" text correctly for today contexts,
             // and since we call it for future dates, it will schedule for that future date 9am
             // and the body will be baked in then? No, wait.
             // If I schedule for Wednesday now (Monday), the notification is constructed NOW.
             // The body string is fixed NOW.
             // If I say "due today" NOW, and it pops on Wednesday, it reads "due today".
             // Correct. The string "due today" is valid relative to the *fired* time if the user reads it then?
             // Actually, `_schedulePaymentReminderInternal` logic:
             // `dueDate.isBefore(today) ? OVERDUE : due today`
             // If I run this on Monday for a Wednesday due date:
             // dueDate (Wed) isBefore today (Mon) -> False. -> "due today".
             // So the text says "Payment ... is due today".
             // Notification fires on Wednesday.
             // User sees "Payment ... is due today". --> CORRECT.
             
             final used = await _schedulePaymentReminderInternal(payment, client.firstName);
             if (used > 0) {
                paymentsScheduled++;
                remaining -= used;
             }
         }
      }
      print('💰 Payments Scheduled (Grouped/Regular): $paymentsScheduled (Remaining Budget: $remaining)');

      // --- Step 2: Schedule Sessions (Rolling Window: Next 7 Days) ---

      final upcomingSessions = sessions.where((s) {
         final dt = _parseSessionDateTime(s.date, s.time);
         // Keep if parsed successfully AND is in future AND is before window end
         return dt != null && dt.isAfter(now) && dt.isBefore(windowEnd);
      }).toList();
      
      // Sort chronologically
      upcomingSessions.sort((a, b) {
        final dtA = _parseSessionDateTime(a.date, a.time) ?? now;
        final dtB = _parseSessionDateTime(b.date, b.time) ?? now;
        return dtA.compareTo(dtB);
      });
      
      print('🔎 Sessions in Window: ${upcomingSessions.length} (out of ${sessions.length} total)');

      int sessionsScheduled = 0;
      int notificationsScheduled = 0;
      int sessionsSkipped = 0;
      final List<Session> selected = [];

      for (final session in upcomingSessions) {
        if (remaining <= 0) { sessionsSkipped++; continue; }
        
        final sessionDateTime = _parseSessionDateTime(session.date, session.time);
        if (sessionDateTime == null) { 
            print('⚠️ Failed to parse date for session: ${session.date} ${session.time}');
            continue; 
        }
        
        final diff = sessionDateTime.difference(now);
        print('🔎 Considering session: ${session.date} ${session.time}. Diff: ${diff.inMinutes} mins');

        if (sessionDateTime.isBefore(now)) {
             print('   ❌ Skipped (Past date)');
             continue;
        }

        // Logic: 1 slot for 5-min, 1 slot for 2-hour (if applicable)
        int needed = 1; // 5-min default
        bool includeTwoHour = diff.inMinutes >= 120;
        if (includeTwoHour) needed += 1;
        
        if (needed > remaining) { 
             print('   ❌ Skipped (Budget full)');
             sessionsSkipped++; 
             continue; 
        }
        
        selected.add(session);
        remaining -= needed;
        sessionsScheduled++;
      }

      // --- Step 3: Execute Schedules ---
      
      // Daily Summary (Reserved Slot)
      await _scheduleDailySummary(now, upcomingSessions); // Logic from home_page

      // Sessions
      notificationsScheduled += await _schedulePackedSessionNotifications(clients, selected, now);

      final totalUsed = paymentsScheduled + notificationsScheduled + reserveDailySummary;
      print('🔔 Notifications summary: sessionsConsidered=${upcomingSessions.length} sessionsScheduled=$sessionsScheduled skipped=$sessionsSkipped totalNotifications=$totalUsed budget=$totalBudget');

    } catch (e) {
      print('❌ Background notification scheduling error: $e');
    }
  }

  // --- Internal Scheduling Helpers ---

  Future<int> _schedulePaymentReminderInternal(PaymentEntry payment, String clientName) async {
     // Logic from original notification_service.dart
     try {
       final dueDate = AppDateUtils.parseSessionDate(payment.dueDate);
       final now = DateTime.now();
       final today = DateTime(now.year, now.month, now.day);
       final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
       
       var targetDate = dueDay;
       if (targetDate.isBefore(today)) {
          targetDate = today;
       }

       var target9am = tz.TZDateTime(tz.local, targetDate.year, targetDate.month, targetDate.day, 9, 0);
       if (target9am.isBefore(tz.TZDateTime.now(tz.local))) {
           target9am = target9am.add(const Duration(days: 1));
       }

       // We schedule 3 days of reminders (High Priority)
       // Check if we have enough budget in the calling loop? 
       // The calling loop checks 'remaining' but we use 3 slots here. 
       // Simplification: We schedule as many as we can up to 3.
       
       // Force 1 slot max as requested
       final scheduleTime = target9am; // Only the first day
       await _scheduleExact(
           id: _safeId(payment.id.hashCode, 10), 
           title: 'Payment Reminder',
           body: 'Payment for $clientName is ${dueDate.isBefore(today) ? 'OVERDUE' : 'due today'}.',
           scheduledTime: scheduleTime,
           channelId: 'payment_channel_v5' // Ensure v5
       );
       return 1;
     } catch (_) {
       return 0;
     }
  }

  Future<void> _scheduleGroupedPaymentReminder(int count) async {
     try {
       // Schedule for 9 AM today (or tomorrow if passed)
       final now = tz.TZDateTime.now(tz.local);
       var target9am = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
       if (target9am.isBefore(now)) {
           target9am = target9am.add(const Duration(days: 1));
       }

       await _scheduleExact(
           id: 99999, // Distinct fixed ID for grouped summary
           title: 'Payment Overdues',
           body: 'Action Required: You have $count past due payments. Tap to view.',
           scheduledTime: target9am,
           channelId: 'payment_channel_v5'
       );
     } catch (e) {
       print('❌ Error scheduling grouped payment reminder: $e');
     }
  }

  Future<void> _scheduleDailySummary(tz.TZDateTime now, List<Session> upcomingSessions) async {
    try {
      var scheduled7AM = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
      if (now.isAfter(scheduled7AM)) {
        scheduled7AM = scheduled7AM.add(const Duration(days: 1));
      }
      
      // FIX: Count sessions for the *Scheduled Date*, not necessarily "now"
      // FIX: Count sessions for the *Scheduled Date*, not necessarily "now"
      final targetDate = DateTime(scheduled7AM.year, scheduled7AM.month, scheduled7AM.day);
      
      final targetSessionsCount = upcomingSessions.where((s) {
          try {
             final d = AppDateUtils.parseSessionDate(s.date);
             return d.year == targetDate.year && d.month == targetDate.month && d.day == targetDate.day;
          } catch (_) {
             return false;
          }
      }).length;
      
      await _scheduleExact(
         id: 2000,
         title: 'Daily Summary',
         body: 'You have $targetSessionsCount classes scheduled for today. Tap to view.',
         scheduledTime: scheduled7AM,
         channelId: 'daily_channel_v5'
      );
    } catch (e) {
      print('❌ Daily summary scheduling error: $e');
    }
  }
  
  // Public method for daily summary if needed elsewhere, but used internally here
  Future<void> scheduleDailySummary({required int sessionCount, required DateTime customTime}) async {
     // Legacy support interface
     await _scheduleExact(
         id: 2000,
         title: 'Daily Summary',
         body: 'You have $sessionCount classes today.',
         scheduledTime: tz.TZDateTime.from(customTime, tz.local),
         channelId: 'daily_channel_v5'
      );
  }

  Future<int> _schedulePackedSessionNotifications(List<Client> clients, List<Session> sessions, tz.TZDateTime now) async {
    int count = 0;
    for (final session in sessions) {
      try {
        final dt = _parseSessionDateTime(session.date, session.time);
        if (dt == null || dt.isBefore(now)) continue;
        
        final clientName = _getClientNameForSession(clients, session);
        final startTimeDisplay = session.time.split(' - ')[0].trim();
        final diff = dt.difference(now);
        
        if (diff.inMinutes >= 120) {
          await scheduleSessionReminder2Hour(
            sessionId: session.id,
            clientName: clientName,
            sessionTime: dt,
            startTimeDisplay: startTimeDisplay,
          );
          count++;
        }
        await scheduleSessionReminder5Min(
          sessionId: session.id,
          clientName: clientName,
          sessionTime: dt,
          startTimeDisplay: startTimeDisplay,
        );
        count++;
      } catch (e) {
        print('❌ Packed scheduling error for session ${session.id}: $e');
      }
    }
    return count;
  }

  // --- Exposed Granular Schedulers (used by Packed Logic) ---

  Future<void> scheduleSessionReminder2Hour({required int sessionId, required String clientName, required DateTime sessionTime, required String startTimeDisplay}) async {
      final tzTime = tz.TZDateTime.from(sessionTime, tz.local);
      final tMinus2h = tzTime.subtract(const Duration(hours: 2));
      
      await _scheduleExact(
            id: _safeId(sessionId, 2),
            title: 'Upcoming Session',
            body: 'Class with $clientName at $startTimeDisplay starts in 2 hrs.',
            scheduledTime: tMinus2h,
            channelId: 'session_channel_v5'
      );
  }

  Future<void> scheduleSessionReminder5Min({required int sessionId, required String clientName, required DateTime sessionTime, required String startTimeDisplay}) async {
      final tzTime = tz.TZDateTime.from(sessionTime, tz.local);
      final tMinus5m = tzTime.subtract(const Duration(minutes: 5));
      
      await _scheduleExact(
            id: _safeId(sessionId, 1),
            title: 'Session Starting Soon',
            body: 'Class with $clientName at $startTimeDisplay starts in 5 mins.',
            scheduledTime: tMinus5m,
            channelId: 'session_channel_v5'
      );
  }

  // --- Helpers ---

  Future<void> _scheduleExact({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required String channelId,
  }) async {
      print('   ✅ SCHEDULING: ID=$id | Time=$scheduledTime | Title="$title" | Body="$body"'); // DEBUG LOG
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
           android: AndroidNotificationDetails(
              channelId,
              'Notification Channel',
              importance: Importance.max,
              priority: Priority.high,
           ),
           iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: fln.AndroidScheduleMode.exactAllowWhileIdle, 
      );
  }

  int _safeId(int baseId, int suffix) {
     return (baseId.hashCode & 0x7FFFFFFF) % 100000 + (suffix * 100000); 
  }

  bool _isSessionDateInFuture(String dateStr) {
     try {
       DateTime? d;
       try {
         d = DateTime.parse(dateStr);
       } catch (_) {
          // Try DD-MM-YYYY
         final parts = dateStr.split('-');
         if (parts.length == 3) {
            d = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
         }
       }
       
       if (d == null) {
           // Last resort strict split (YYYY-MM-DD)
           final parts = dateStr.split('-');
           d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
       }
       
       final now = DateTime.now();
       final today = DateTime(now.year, now.month, now.day);
       return !d.isBefore(today);
     } catch (_) {
       return false;
     }
  }

  // --- Private Helpers ---

  tz.TZDateTime? _parseSessionDateTime(String sessionDate, String sessionTime) {
    try {
      final dateTime = AppDateUtils.parseSessionDateTime(sessionDate, sessionTime);
      if (dateTime == null) return null;
      return tz.TZDateTime.from(dateTime, tz.local);
    } catch (e) {
      print('❌ Error parsing session date: "$sessionDate" time: "$sessionTime" -> $e');
      return null;
    }
  }

  Map<String, int> _parseTimeRange(String timeRange) {
     try {
       // Normalize string similar to AppDateUtils
       String cleaned = timeRange.replaceAll(RegExp(r'\s+'), ' ').trim();
       if (!cleaned.contains(' - ') && cleaned.contains('-')) {
           cleaned = cleaned.replaceAll('-', ' - ');
       }
       
       final parts = cleaned.split(' - ');
       if (parts.length < 2) return {'start': 0}; // Fail graceful
       
       int toMinutes(String s) {
         s = s.trim();
         final isPm = s.toUpperCase().contains('PM');
         final isAm = s.toUpperCase().contains('AM');
         
         String timePart = s.replaceAll(RegExp(r'[ A-Za-z]'), ''); 
         final hm = timePart.split(':');
         if (hm.length < 2) return 0;
         
         int h = int.parse(hm[0]);
         int m = int.parse(hm[1]);
         
         if (isPm && h < 12) h += 12;
         if (isAm && h == 12) h = 0;
         return h * 60 + m;
       }

       return {'start': toMinutes(parts[0])}; 
     } catch (_) {
       return {'start': 0};
     }
  }
  
  // Backwards compatibility for other helpers if needed
  DateTime? _parseDateTime(String dateStr, String timeStr) {
      // Legacy helper kept just in case
      return null; 
  }

  String _getClientNameForSession(List<Client> clients, Session session) {
    try {
      final client = clients.firstWhere((c) => c.id == session.clientId);
      return '${client.firstName} ${client.lastName}';
    } catch (e) {
      return 'Unknown Client';
    }
  }
  
  String _dateToStr(DateTime d) {
     return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _configureTimezone() async {
    try {
      tz.initializeTimeZones();
      final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZoneInfo.toString();
      print('🌐 Device Timezone Name: $timeZoneName');
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (e) {
        print('⚠️ Error setting location "$timeZoneName": $e');
        // Fallback checks
        if (DateTime.now().timeZoneOffset.inMinutes == 330) {
           print('🇮🇳 Detected IST offset (330), forcing "Asia/Kolkata"');
           tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
        } else {
           rethrow;
        }
      }
    } catch (e) {
      print('❌ Timezone Configuration Failed: $e. Fallback to UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }
}
