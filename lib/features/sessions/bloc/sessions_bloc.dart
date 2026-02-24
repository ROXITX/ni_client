import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/session.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/data/appointment_repository.dart';
import '../../../shared/services/notification_service.dart';

// --- Events ---
abstract class SessionsEvent {}

class SessionsSubscriptionRequested extends SessionsEvent {}

class SessionsUpdateSession extends SessionsEvent {
  final Session session;
  SessionsUpdateSession(this.session);
}

// --- States ---
abstract class SessionsState {}

class SessionsLoading extends SessionsState {}

class SessionsLoaded extends SessionsState {
  final List<Session> sessions;
  SessionsLoaded(this.sessions);
}

class SessionsError extends SessionsState {
  final String message;
  SessionsError(this.message);
}



// --- BLoC ---
class SessionsBloc extends Bloc<SessionsEvent, SessionsState> {
  final AppointmentRepository _repository;
  final NotificationService _notificationService;
  StreamSubscription? _sessionSub;

  SessionsBloc({
    required AppointmentRepository repository,
    required NotificationService notificationService,
  })  : _repository = repository,
        _notificationService = notificationService,
        super(SessionsLoading()) {
    on<SessionsSubscriptionRequested>(_onSubscriptionRequested);
    on<SessionsUpdateSession>(_onUpdateSession);
    on<_SessionsUpdatedList>(_onSessionsUpdatedList);
  }

  Future<void> _onSubscriptionRequested(
      SessionsSubscriptionRequested event, Emitter<SessionsState> emit) async {
    emit(SessionsLoading());
    await _sessionSub?.cancel();
    _sessionSub = _repository.getSessions().listen((sessions) {
      add(_SessionsUpdatedList(sessions));
    });
  }

  Future<void> _onSessionsUpdatedList(
      _SessionsUpdatedList event, Emitter<SessionsState> emit) async {
    emit(SessionsLoaded(event.sessions));
  }

  Future<void> _onUpdateSession(
      SessionsUpdateSession event, Emitter<SessionsState> emit) async {
    try {
      await _repository.updateSession(event.session);
      
      // If session is cancelled or completed, remove notifications immediately
      if (event.session.status == 'Cancelled' || event.session.status == 'Completed') {
         // Fire and forget cancellation - handled by repository update & refresh
         // _notificationService.cancelSessionNotifications(event.session.id);
      }
    } catch (e) {
      emit(SessionsError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _sessionSub?.cancel();
    return super.close();
  }

  // --- Real-time Status Logic ---
  
  String getRealTimeSessionStatus(Session session) {
    final now = DateTime.now();
    final todayStr = AppDateUtils.dateToStr(now);
    final nowInMinutes = now.hour * 60 + now.minute;
    
    // Skip completed/cancelled sessions - they don't change
    if (session.status == 'Completed' || session.status == 'Cancelled') {
      return session.status;
    }
    
    return _determineCorrectStatus(session, now, todayStr, nowInMinutes);
  }

  String _determineCorrectStatus(Session session, DateTime now, String todayStr, int nowInMinutes) {
    try {
      // Parse session date using AppDateUtils
      final sessionDate = AppDateUtils.parseSessionDate(session.date);
      final todayDate = DateTime(now.year, now.month, now.day);
      final sessionOnlyDate = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
      
      // Compare dates
      if (sessionOnlyDate.isBefore(todayDate)) {
        // Past date - should be Pending
        return 'Pending';
      } else if (sessionOnlyDate.isAfter(todayDate)) {
        // Future date - should be Upcoming
        return 'Upcoming';
      } else {
        // Today - check time
        final sessionStartMinutes = _parseTimeRange(session.time)['start'] ?? 0;
        // Switch to Pending the moment the session start minute is reached (>=)
        return (nowInMinutes >= sessionStartMinutes) ? 'Pending' : 'Upcoming';
      }
    } catch (e) {
      return session.status; // Keep current status if parsing fails
    }
  }

  Map<String, int> _parseTimeRange(String timeRange) {
      final parts = timeRange.split(' - ');
      if (parts.length < 2) return {'start': 0, 'end': 0};
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
    }
}

class _SessionsUpdatedList extends SessionsEvent {
  final List<Session> sessions;
  _SessionsUpdatedList(this.sessions);
}
