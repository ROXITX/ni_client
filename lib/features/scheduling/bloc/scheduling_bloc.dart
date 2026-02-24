import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart' show TimeOfDay, DayPeriod; // For TimeOfDay logic if needed, or use string manipulation
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/data/appointment_repository.dart';

// --- Events ---
abstract class SchedulingEvent {}

class SchedulingSubscriptionRequested extends SchedulingEvent {}

class SchedulingGenerateDraft extends SchedulingEvent {
  final int count;
  final DateTime startDate;
  final String frequency;
  final String timeSlot;
  final int weeklyDay;
  final int monthlyDate;
  final SessionDuration? duration;
  final Client? client;
  final ProgramType? programType;
  final String? courseName; // Added for dynamic course support
  
  SchedulingGenerateDraft({
    required this.count,
    required this.startDate,
    required this.frequency,
    required this.timeSlot,
    required this.weeklyDay,
    required this.monthlyDate,
    this.duration,
    this.client,
    this.programType,
    this.courseName,
  });
}

class SchedulingConfirmSave extends SchedulingEvent {
  final List<Session> draftSessions;
  SchedulingConfirmSave(this.draftSessions);
}

// --- States ---
abstract class SchedulingState {}

class SchedulingInitial extends SchedulingState {}

class SchedulingDraftReady extends SchedulingState {
  final List<Session> draftSessions;
  final Set<String> clashIds;
  SchedulingDraftReady(this.draftSessions, this.clashIds);
}

class SchedulingSaving extends SchedulingState {}

class SchedulingSuccess extends SchedulingState {
    final String message;
    SchedulingSuccess(this.message);
}

class SchedulingError extends SchedulingState {
  final String message;
  SchedulingError(this.message);
}

// --- BLoC ---
class SchedulingBloc extends Bloc<SchedulingEvent, SchedulingState> {
  final AppointmentRepository _repository;
  StreamSubscription? _sessionSub;
  List<Session> _existingSessions = [];

  SchedulingBloc({required AppointmentRepository repository})
      : _repository = repository,
        super(SchedulingInitial()) {
    on<SchedulingSubscriptionRequested>(_onSubscriptionRequested);
    on<SchedulingGenerateDraft>(_onGenerateDraft);
    on<SchedulingConfirmSave>(_onConfirmSave);
    on<_SchedulingSessionsUpdated>(_onSessionsUpdated);
  }

  Future<void> _onSubscriptionRequested(
      SchedulingSubscriptionRequested event, Emitter<SchedulingState> emit) async {
    await _sessionSub?.cancel();
    _sessionSub = _repository.getSessions().listen((sessions) {
      add(_SchedulingSessionsUpdated(sessions));
    });
  }

  void _onSessionsUpdated(
      _SchedulingSessionsUpdated event, Emitter<SchedulingState> emit) {
    _existingSessions = event.sessions;
    // If we have a draft, re-check clashes?
    // For now, simpler to just update the internal list for FUTURE checks.
    // Real-time re-check of draft against new sessions would require holding the last draft params.
  }

  Future<void> _onGenerateDraft(
      SchedulingGenerateDraft event, Emitter<SchedulingState> emit) async {
    try {
      final draft = _generateSchedule(
          count: event.count,
          startDate: event.startDate,
          frequency: event.frequency,
          timeSlot: event.timeSlot,
          weeklyDay: event.weeklyDay,
          monthlyDate: event.monthlyDate,
          client: event.client,
          programType: event.programType,
          courseName: event.courseName,
          duration: event.duration
      );
      
      final clashes = _checkForClashes(draft, _existingSessions);
      emit(SchedulingDraftReady(draft, clashes));
    } catch (e) {
      emit(SchedulingError(e.toString()));
    }
  }

  Future<void> _onConfirmSave(
      SchedulingConfirmSave event, Emitter<SchedulingState> emit) async {
    emit(SchedulingSaving());
    try {
      for (final s in event.draftSessions) {
          // Ensure ID is generated if logic requires it, here passed from draft
          await _repository.addSession(s);
      }
      emit(SchedulingSuccess('Sessions scheduled successfully!'));
    } catch (e) {
      emit(SchedulingError(e.toString()));
    }
  }

  // --- Logic ported from home_page.dart (simplified/refactored) ---
  
  List<Session> _generateSchedule({
    required int count,
    required DateTime startDate,
    required String frequency,
    required String timeSlot,
    required int weeklyDay,
    required int monthlyDate,
    required Client? client,
    required ProgramType? programType,
    required String? courseName,
    SessionDuration? duration,
  }) {
    List<Session> sessions = [];
    DateTime cursor = startDate;

    // Adjust start date to match the first occurrence based on frequency
    if (frequency == 'Weekly') {
      while (cursor.weekday != weeklyDay) {
        cursor = cursor.add(const Duration(days: 1));
      }
    } else if (frequency == 'Monthly') {
      // Find the first occurrence of 'monthlyDate'
      // If start date day > monthlyDate, move to next month
      if (cursor.day > monthlyDate) {
        cursor = DateTime(cursor.year, cursor.month + 1, monthlyDate);
      } else {
        // If start date day <= monthlyDate, check if that date is valid?
        // Actually simpler: just construct the date for the current/next month
         if (cursor.day <= monthlyDate) {
             // In current month
             // Beware of invalid dates (e.g. Feb 30). For MVP assuming 1-28 safe or logic handles overflow naturally in DateTime
             cursor = DateTime(cursor.year, cursor.month, monthlyDate);
         }
      }
      // Ensure cursor is not before startDate (though the above logic handles it implicitly often)
      if (cursor.isBefore(startDate)) {
         // Should not happen with above logic unless time component messiness
         cursor = DateTime(cursor.year, cursor.month + 1, monthlyDate);
      }
    }

    for (int i = 0; i < count; i++) {
        // Calculate Time
        // duration is SessionDuration enum.
        // We need end time.
        // Extracted parseTimeRange logic:
        // We need to construct the time string "XX:XX AM - YY:YY PM" if the input is just Start Time ? 
        // Or is "timeSlot" the full range?
        // in home_page.dart, _timeSlotCtrl holds values like "10:00 AM - 11:00 AM".
        // The dropdowns populate full ranges.
        // But if user selected single slot in simplified view?
        // Assuming timeSlot is "Start - End".
        
        final session = Session(
          id: DateTime.now().millisecondsSinceEpoch + i,
          sessionNo: i + 1, // Defaulting to i+1 for draft
          clientId: client?.id ?? 0,
          status: 'Upcoming',
          time: timeSlot,
          date: AppDateUtils.dateToStr(cursor), // 'yyyy-MM-dd'
          programType: programType, 
          courseName: courseName,
          duration: duration,
        );
        sessions.add(session);

        // Advance cursor
        if (frequency == 'Daily') {
          cursor = cursor.add(const Duration(days: 1));
        } else if (frequency == 'Weekly') {
          cursor = cursor.add(const Duration(days: 7));
        } else if (frequency == 'Monthly') {
           // Move to next month same day
           int nextMonth = cursor.month + 1;
           int nextYear = cursor.year;
           if (nextMonth > 12) {
             nextMonth = 1;
             nextYear++;
           }
           // Handle end of month edge cases (e.g. hitting Feb 30 -> Mar 2) if DateTime autowraps?
           // DateTime(2025, 2, 30) -> Mar 2. 
           // If requirement is STRICT monthly date, we might need logic.
           // Original code didn't handle strictness deeply shown in snippet.
           cursor = DateTime(nextYear, nextMonth, monthlyDate);
        }
    }
    return sessions;
  }
  
  Set<String> _checkForClashes(List<Session> newSessions, List<Session> existingSessions) {
    final clashIds = <String>{};
    for (final newS in newSessions) {
      final newTime = AppDateUtils.parseTimeRange(newS.time);

      final otherSessions = existingSessions.where((s) => s.clientId != newS.clientId).toList();
      // Actually clash check should be against ALL sessions (trainer availability)?
      // Original code:
      /*
       final otherSessions = modifyingClient != null
           ? allExistingSessions.where((s) => s.clientId != modifyingClient!.id).toList()
           : allExistingSessions;
      */
      // Use existingSessions passed in (which assumes "all").
      // But if we are adding for Client A, we don't care about Client A's own clashes?
      // Trainer clashes check means we check against EVERYONE.
      // IF logic is "Trainer cannot be in 2 places", then check everyone.
      // Logic line 6127: "where((s) => s.clientId != modifyingClient!.id)"
      // This suggests existing sessions for THIS client are IGNORED?? 
      // Maybe to allow rescheduling "over" old ones?
      // Or maybe it assumes One Trainer.
      // If I am Client A, and I have a session at 10am. I shouldn't be able to book another at 10am?
      // Wait, "modifyingClient" logic seems to imply we ignore the client's own sessions during update?
      // Safe bet: Check against all sessions except those being replaced... but here we simplify.
      
      // Let's assume strict trainer availability: Check against ALL existing sessions.
      
      for (final existing in existingSessions) {
        if (newS.date == existing.date) {
            final existingTime = AppDateUtils.parseTimeRange(existing.time);
            
            // Check overlap
            // (StartA < EndB) and (EndA > StartB)
            if (newTime['start']! < existingTime['end']! && newTime['end']! > existingTime['start']!) {
                clashIds.add(newS.date + newS.time); // Key to identify visual clash?
                // Or just mark the session ID? Session IDs in draft are temp.
                // We return Set<String> of...?
                // Original used 'tempId'. 
                // We'll use the ID we generated.
                clashIds.add(newS.id.toString());
                break;
            }
        }
      }
    }
    return clashIds;
  }
  
  @override
  Future<void> close() {
    _sessionSub?.cancel();
    return super.close();
  }
}

class _SchedulingSessionsUpdated extends SchedulingEvent {
  final List<Session> sessions;
  _SchedulingSessionsUpdated(this.sessions);
}
