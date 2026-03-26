import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../../../models/payment_entry.dart';
import '../../../shared/data/appointment_repository.dart';
import '../../payments/data/payment_repository.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/services/notification_service.dart';

// --- Events ---
abstract class DashboardEvent {}

class DashboardSubscriptionRequested extends DashboardEvent {}

class DashboardRefreshRequested extends DashboardEvent {
  final bool isTimerTriggered;
  DashboardRefreshRequested({this.isTimerTriggered = false});
}

class DashboardMarkNotificationsRead extends DashboardEvent {
  final List<int>? sessionIds; // If null, mark all. If set, mark specific.
  final List<String>? paymentIds; // NEW
  DashboardMarkNotificationsRead({this.sessionIds, this.paymentIds});
}


// class DashboardMarkNotificationsRead extends DashboardEvent { ... } // Removed for reset

// --- States ---
abstract class DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final List<Client> clients;
  final List<Session> sessions;
  final List<Session> todaysSessions;
  final Map<String, List<Session>> sessionsByStatus;
  final int completions;
  final int totalToday;
  final List<Map<String, dynamic>> notifications; // Changed from List<String> to Map
  final List<PaymentEntry> todaysPayments; // NEW
  final Map<String, List<PaymentEntry>> paymentsByStatus; // NEW
  final List<PaymentEntry> allPendingPayments;

  DashboardLoaded({
    required this.clients,
    required this.sessions,
    required this.todaysSessions,
    required this.sessionsByStatus,
    required this.completions,
    required this.totalToday,
    required this.notifications,
    required this.todaysPayments, // NEW
    required this.paymentsByStatus, // NEW
    required this.allPendingPayments,
  });
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final AppointmentRepository _repository;
  final PaymentRepository _paymentRepository; // NEW
  final NotificationService _notificationService;
  StreamSubscription? _clientSub;
  StreamSubscription? _sessionSub;
  StreamSubscription? _paymentSub; // NEW
  Timer? _statusUpdateTimer; 

  List<Client> _clients = [];
  List<Session> _sessions = [];
  List<PaymentEntry> _pendingPayments = []; // NEW

  DashboardBloc({
    required AppointmentRepository repository,
    required PaymentRepository paymentRepository, // NEW
    required NotificationService notificationService,
  })  : _repository = repository,
        _paymentRepository = paymentRepository,
        _notificationService = notificationService,
        super(DashboardLoading()) {
    on<DashboardSubscriptionRequested>(_onSubscriptionRequested);
    on<DashboardRefreshRequested>(_onRefreshRequested);
    on<DashboardMarkNotificationsRead>(_onMarkNotificationsRead);
  }

  Future<void> _onSubscriptionRequested(
      DashboardSubscriptionRequested event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());

    await _clientSub?.cancel();
    await _sessionSub?.cancel();
    await _paymentSub?.cancel();

    _clientSub = _repository.getClients().listen((clients) {
      _clients = clients;
      add(DashboardRefreshRequested());
    });

    _sessionSub = _repository.getSessions().listen((sessions) {
      _sessions = sessions;
      add(DashboardRefreshRequested());
      _checkForStatusUpdates(); 
    });
    
    // Listen to payments
    _paymentSub = _paymentRepository.getAllPendingPaymentEntries().listen((payments) {
       _pendingPayments = payments;
       add(DashboardRefreshRequested());
    });
    
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      add(DashboardRefreshRequested(isTimerTriggered: true)); // Force UI update for time-sensitive notifications
      _checkForStatusUpdates();
    });
  }

  void _onRefreshRequested(
      DashboardRefreshRequested event, Emitter<DashboardState> emit) {
    try {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final todayStr = AppDateUtils.dateToStr(now);

      // Filter Today's Sessions robustly
      final todaysSessions = _sessions.where((s) {
          try {
             final d = AppDateUtils.parseSessionDate(s.date);
             return d.year == todayDate.year && d.month == todayDate.month && d.day == todayDate.day;
          } catch (_) {
             return false;
          }
      }).toList();
      
      final totalToday = todaysSessions.length;
      final completions = todaysSessions
          .where((s) => s.status == 'Completed' || s.status == 'Cancelled')
          .length;

      // Group Sessions
      final Map<String, List<Session>> sessionsByStatus = {};
      for (var s in todaysSessions) {
        final effectiveStatus = AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
        sessionsByStatus.putIfAbsent(effectiveStatus, () => []).add(s);
      }

      // Compute Notifications (Sessions + Payments)
      final notifications = _computeNotifications(_clients, _sessions, _pendingPayments);
      
      // Schedule Future Notifications (Sessions + Payments)
      // "Queued to the notification handler" (Requirements #4)
      if (!event.isTimerTriggered) {
         _scheduleNotifications(_clients, _sessions, _pendingPayments);
      }

      // Process Payments
      final todaysPayments = <PaymentEntry>[];
      final Map<String, List<PaymentEntry>> paymentsByStatus = {
         'Overdue': [],
         'Due Today': [],
         'Paid': [],
      };
      
      for (final p in _pendingPayments) {
         final dueDate = DateTime.tryParse(p.dueDate) ?? now;
         final isToday = dueDate.year == todayDate.year && dueDate.month == todayDate.month && dueDate.day == todayDate.day;
         final isOverdue = dueDate.isBefore(todayDate);
         
         if (p.status == PaymentStatus.paid) {
            paymentsByStatus['Paid']!.add(p);
            if (isToday) todaysPayments.add(p);
         } else if (isOverdue) {
            paymentsByStatus['Overdue']!.add(p);
            todaysPayments.add(p);
         } else if (isToday) {
            paymentsByStatus['Due Today']!.add(p);
            todaysPayments.add(p);
         }
      }

      emit(DashboardLoaded(
        clients: _clients,
        sessions: _sessions,
        todaysSessions: todaysSessions,
        sessionsByStatus: sessionsByStatus,
        completions: completions,
        totalToday: totalToday,
        notifications: notifications,
        todaysPayments: todaysPayments,
        paymentsByStatus: paymentsByStatus,
        allPendingPayments: _pendingPayments,
      ));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  // Track which sessions/payments currently have active scheduled notifications to avoid churn


  // Debounce Timer for notification scheduling
  Timer? _notificationDebounceTimer;

  Future<void> _scheduleNotifications(List<Client> clients, List<Session> sessions, List<PaymentEntry> payments) async {
       _notificationDebounceTimer?.cancel();
       _notificationDebounceTimer = Timer(const Duration(seconds: 2), () async {
            await _notificationService.scheduleAllNotifications(clients, sessions, payments);
       });
  }

  Future<void> _onMarkNotificationsRead(
      DashboardMarkNotificationsRead event, Emitter<DashboardState> emit) async {
    try {
        final now = DateTime.now();
        final todayStr = AppDateUtils.dateToStr(now);
        final sessionsToUpdate = <Session>[];
        final paymentsToUpdate = <PaymentEntry>[];

        final todaySessions = _sessions.where((s) => s.date == todayStr && (s.status == 'Upcoming' || s.status == 'Pending' || s.status == 'Pending Action')).toList();

        // 1. Sessions
        for (final s in todaySessions) {
          if (s.read) continue;
          
          // If specific IDs requested, trust them and mark as read immediately
          if (event.sessionIds != null) {
              if (event.sessionIds!.contains(s.id)) {
                  s.read = true;
                  sessionsToUpdate.add(s);
              }
              continue; // Skip validation for explicitly requested IDs
          }

          // Implicit/Auto Check: Only mark if inside validity window
          final startMin = AppDateUtils.parseTimeRange(s.time)['start'] ?? 0;
          final nowMin = now.hour * 60 + now.minute;
          final diff = startMin - nowMin;
          
          if (diff >= -15 && diff <= 120) {
              s.read = true;
              sessionsToUpdate.add(s);
          }
        }
        
        // 2. Payments (Explicit Only for now)
        if (event.paymentIds != null) {
           for (final p in _pendingPayments) {
               if (event.paymentIds!.contains(p.id) && !p.read) {
                   p.read = true;
                   paymentsToUpdate.add(p);
               }
           }
        }
        
        if (sessionsToUpdate.isNotEmpty) {
           await _repository.updateSessionsBatch(sessionsToUpdate);
        }
        
        if (paymentsToUpdate.isNotEmpty) {
           await _paymentRepository.updatePaymentEntriesBatch(paymentsToUpdate);
        }

        if (sessionsToUpdate.isNotEmpty || paymentsToUpdate.isNotEmpty) {
           add(DashboardRefreshRequested());
        }
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  List<Map<String, dynamic>> _computeNotifications(List<Client> clients, List<Session> sessions, List<PaymentEntry> payments) {
    final now = DateTime.now();
    final todayStr = AppDateUtils.dateToStr(now); // yyyy-MM-dd
    final items = <Map<String, dynamic>>[];

    // 1. Session Notifications
    // FIX: Don't compare strings directly as formats may differ (YYYY-MM-DD vs DD-MM-YYYY).
    // Use parseSessionDate to normalize.
    final todayDate = DateTime(now.year, now.month, now.day);
    
    final todaySessions = sessions.where((s) {
       if (s.status != 'Upcoming' && s.status != 'Pending' && s.status != 'Pending Action') return false;
       try {
         final d = AppDateUtils.parseSessionDate(s.date);
         return d.year == todayDate.year && d.month == todayDate.month && d.day == todayDate.day;
       } catch (_) {
         return false;
       }
    }).toList();

    for (final s in todaySessions) {
      final startMin = AppDateUtils.parseTimeRange(s.time)['start'] ?? 0;
      final nowMin = now.hour * 60 + now.minute;
      final diff = startMin - nowMin;

      if (diff >= -15 && diff <= 120) {
        if (clients.any((c) => c.id == s.clientId)) {
             final c = clients.firstWhere((c) => c.id == s.clientId);
             String msg;
             if (diff >= 0 && diff <= 5) {
                msg = 'Session with ${c.firstName} starts at ${AppDateUtils.parseTimeRange(s.time)['start'] != null ? s.time : "soon"}.';
            } else if (diff > 5 && diff <= 120) {
                msg = 'Session with ${c.firstName} starts at ${s.time}.';
            } else {
                msg = 'Session with ${c.firstName} is pending.';
            }
            items.add({'id': s.id, 'message': msg, 'read': s.read, 'type': 'session'});
        }
      }
    }
    
    // 2. Payment Notifications (In-App)
    // Check for payments due TODAY or OVERDUE
    for (final p in payments) {
        // Parse yyyy-MM-dd
        final dueDate = DateTime.parse(p.dueDate);
        final todayDate = DateTime(now.year, now.month, now.day);
        
        // Simple comparison: Is it due today?
        final isToday = dueDate.year == todayDate.year && dueDate.month == todayDate.month && dueDate.day == todayDate.day;
        
        // Or strictly overdue? 
        final isOverdue = dueDate.isBefore(todayDate);

        if (isToday || isOverdue) {
           final c = clients.firstWhere((c) => c.id == p.clientId, orElse: () => Client.empty());
           if (c.id == 0) continue;
           
           String msg;
           if (isToday) {
              msg = 'Payment of ₹${p.amount.toStringAsFixed(0)} for ${c.firstName} is due TODAY.';
           } else {
              msg = 'Payment of ₹${p.amount.toStringAsFixed(0)} for ${c.firstName} is OVERDUE (Due ${p.dueDate}).';
           }
           
           // We don't track 'read' state for payments in DB yet, so assume unread or ephemeral?
           // Or key it? 'read': false for now.
           items.add({'id': p.id, 'message': msg, 'read': p.read, 'type': 'payment', 'clientId': p.clientId});
        }
    }
    
    return items;
  }
  
  Future<void> _checkForStatusUpdates() async {
    final now = DateTime.now();
    final todayStr = AppDateUtils.dateToStr(now);
    final nowInMinutes = now.hour * 60 + now.minute;

    final sessionsToUpdate = <Session>[];

    for (final session in _sessions) {
      if (session.status == 'Completed' || session.status == 'Cancelled') continue;

      String correctStatus = AppDateUtils.determineSessionStatus(session.status, session.date, session.time);
      
      final legacyStatus = _legacyDetermineStatus(session, now, todayStr, nowInMinutes);

      if (legacyStatus == 'Pending' && correctStatus == 'Upcoming') {
          correctStatus = 'Pending';
      }

      if (session.status != correctStatus) {
         if (correctStatus == 'Upcoming') {
             if (session.status != 'Upcoming') {
                 session.read = false;
             }
         }
         session.status = correctStatus;
         sessionsToUpdate.add(session);
      }
    }

    if (sessionsToUpdate.isNotEmpty) {
      await _repository.updateSessionsBatch(sessionsToUpdate);
    }
  }

  String _legacyDetermineStatus(Session session, DateTime now, String todayStr, int nowInMinutes) {
    try {
      final sessionDateParts = session.date.split('-');
      if (sessionDateParts.length != 3) return session.status; 

      final sessionYear = int.parse(sessionDateParts[0]);
      final sessionMonth = int.parse(sessionDateParts[1]);
      final sessionDay = int.parse(sessionDateParts[2]);
      final sessionDate = DateTime(sessionYear, sessionMonth, sessionDay);
      final todayDate = DateTime(now.year, now.month, now.day);

      if (sessionDate.isBefore(todayDate)) {
        return 'Pending';
      } else if (sessionDate.isAfter(todayDate)) {
        return 'Upcoming';
      } else {
        final sessionStartMinutes = _legacyParseTimeRange(session.time)['start'] ?? 0;
        return (nowInMinutes >= sessionStartMinutes) ? 'Pending' : 'Upcoming';
      }
    } catch (e) {
      return session.status; 
    }
  }

  Map<String, int> _legacyParseTimeRange(String timeRange) {
    try {
      final parts = timeRange.split(' - ');
      int toMinutes(String s) {
        final segments = s.split(' ');
        final hm = segments[0].split(':');
        int h = int.parse(hm[0]);
        int m = int.parse(hm[1]);
        final meridiem = segments[1];
        if (meridiem == 'PM' && h < 12) h += 12;
        if (meridiem == 'AM' && h == 12) h = 0;
        return h * 60 + m;
      }
      return {
        'start': toMinutes(parts[0]),
        'end': toMinutes(parts[1]),
      };
    } catch (_) {
      return {'start': 0, 'end': 0};
    }
  }

  @override
  Future<void> close() {
    _clientSub?.cancel();
    _sessionSub?.cancel();
    _statusUpdateTimer?.cancel();
    return super.close();
  }
}
