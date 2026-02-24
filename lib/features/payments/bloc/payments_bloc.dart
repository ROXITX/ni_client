import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/payment_plan.dart';
import '../../../../models/payment_entry.dart';
import '../data/payment_repository.dart';
import 'package:intl/intl.dart';

part 'payments_event.dart';
part 'payments_state.dart';

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final PaymentRepository _repository;
  StreamSubscription? _plansSub;
  StreamSubscription? _entriesSub;
  
  List<PaymentPlan> _currentPlans = [];
  List<PaymentEntry> _currentEntries = [];

  PaymentsBloc({required PaymentRepository repository})
      : _repository = repository,
        super(PaymentsInitial()) {
    on<PaymentsFetch>(_onFetch);
    on<PaymentsAddPlan>(_onAddPlan);
    on<PaymentsUpdatePlan>(_onUpdatePlan);
    on<PaymentsDeletePlan>(_onDeletePlan);
    on<PaymentsUpdateEntry>(_onUpdateEntry);
    on<PaymentsDeleteEntry>(_onDeleteEntry);
    on<PaymentsSettleEntry>(_onSettleEntry);
    on<_PaymentsUpdated>(_onUpdates);
  }
  
  Future<void> _onFetch(PaymentsFetch event, Emitter<PaymentsState> emit) async {
    emit(PaymentsLoading());
    await _plansSub?.cancel();
    await _entriesSub?.cancel();
    
    _plansSub = _repository.getPaymentPlans(event.clientId).listen((plans) {
       add(_PaymentsUpdated(plans: plans));
    });
    
    _entriesSub = _repository.getPaymentEntries(event.clientId).listen((entries) {
       add(_PaymentsUpdated(entries: entries));
    });
  }
  
  void _onUpdates(_PaymentsUpdated event, Emitter<PaymentsState> emit) {
    if (event.plans != null) _currentPlans = event.plans!;
    if (event.entries != null) _currentEntries = event.entries!;
    
    emit(PaymentsLoaded(_currentPlans, _currentEntries));
  }

  Future<void> _onAddPlan(PaymentsAddPlan event, Emitter<PaymentsState> emit) async {
    try {
      final planId = await _repository.addPaymentPlan(event.plan);
      // Assign the real Plan ID to entries
      final entriesWithId = event.initialEntries.map((e) => e.copyWith(planId: planId)).toList();
      await _repository.addPaymentEntriesBatch(entriesWithId);
    } catch (e) {
      emit(PaymentsError(e.toString()));
       // Re-emit loaded state if possible? Or rely on stream.
       // It's safer to let the error stand or implement a transient error state.
    }
  }

  Future<void> _onUpdatePlan(PaymentsUpdatePlan event, Emitter<PaymentsState> emit) async {
    try {
      await _repository.replacePaymentPlan(event.plan, event.newEntries);
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onDeletePlan(PaymentsDeletePlan event, Emitter<PaymentsState> emit) async {
    try {
      await _repository.deletePaymentPlan(event.planId);
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onUpdateEntry(PaymentsUpdateEntry event, Emitter<PaymentsState> emit) async {
    try {
      await _repository.updatePaymentEntry(event.entry);
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }
  
  Future<void> _onDeleteEntry(PaymentsDeleteEntry event, Emitter<PaymentsState> emit) async {
    try {
      await _repository.deletePaymentEntry(event.entryId);
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }

  Future<void> _onSettleEntry(PaymentsSettleEntry event, Emitter<PaymentsState> emit) async {
    try {
      final entry = event.entry;
      final paid = event.paidAmount;
      final totalPaid = entry.paidAmount + paid;
      final remaining = entry.amount - totalPaid;
      
      PaymentStatus newStatus;
      if (remaining <= 0.01) { // Floating point tolerance
        newStatus = PaymentStatus.paid;
      } else {
        newStatus = PaymentStatus.partiallyPaid;
      }
      
      final updatedEntry = entry.copyWith(
        paidAmount: totalPaid,
        status: newStatus,
        paidDate: newStatus == PaymentStatus.paid ? event.paymentDate : null,
      );
      
      await _repository.updatePaymentEntry(updatedEntry);
      
      if (remaining > 0.01) {
        String? targetDate;
        String notes = 'Balance carried forward from ${entry.dueDate}'; // Default note

        if (event.actionForBalance == 'addToNext') {
             // Find next entry in this plan
             final planEntries = _currentEntries.where((e) => e.planId == entry.planId).toList()
               ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
             
             final currentIndex = planEntries.indexWhere((e) => e.id == entry.id);
             if (currentIndex != -1 && currentIndex < planEntries.length - 1) {
               targetDate = planEntries[currentIndex + 1].dueDate;
               notes = 'Balance added to next payment date ($targetDate)';
             }
        } else if (event.actionForBalance == 'moveToDate' || event.actionForBalance == 'newEntry') {
             targetDate = event.newDate;
        }

        if (targetDate != null) {
             // Check for existing active entry on same date/plan to merge
             final mergeTargetIndex = _currentEntries.indexWhere((e) => 
                e.planId == entry.planId && 
                e.dueDate == targetDate && 
                e.status != PaymentStatus.paid
             );

             if (mergeTargetIndex != -1) {
                // MERGE into existing
                final targetEntry = _currentEntries[mergeTargetIndex];
                final mergedNotes = (targetEntry.notes?.isNotEmpty == true) 
                    ? '${targetEntry.notes}\n$notes' 
                    : notes;
                
                final updatedTarget = targetEntry.copyWith(
                   amount: targetEntry.amount + remaining,
                   notes: mergedNotes,
                   // If it was fully paid (impossible due to check) or partial, it remains open.
                );
                await _repository.updatePaymentEntry(updatedTarget);
             } else {
                // Create NEW entry for the balance
                 final newEntry = PaymentEntry(
                   id: '', // Repo generates
                   planId: entry.planId,
                   clientId: entry.clientId,
                   dueDate: targetDate,
                   amount: remaining,
                   status: PaymentStatus.postponed, 
                   notes: notes,
                 );
                 await _repository.addPaymentEntry(newEntry);
             }
             
             // Mark original entry as Fully Paid (Split) since balance moved OR Delete if 0 payment
             if (paid <= 0.01) {
                 await _repository.deletePaymentEntry(entry.id);
             } else {
                 final splitOriginal = updatedEntry.copyWith(
                   amount: updatedEntry.paidAmount,
                   status: PaymentStatus.paid
                 );
                 await _repository.updatePaymentEntry(splitOriginal);
             }
        }
      }
    } catch (e) {
      emit(PaymentsError(e.toString()));
    }
  }
  
  @override
  Future<void> close() {
    _plansSub?.cancel();
    _entriesSub?.cancel();
    return super.close();
  }
}

class _PaymentsUpdated extends PaymentsEvent {
  final List<PaymentPlan>? plans;
  final List<PaymentEntry>? entries;
  _PaymentsUpdated({this.plans, this.entries});
}
