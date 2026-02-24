part of 'payments_bloc.dart';

abstract class PaymentsEvent {}

class PaymentsFetch extends PaymentsEvent {
  final int clientId;
  PaymentsFetch(this.clientId);
}

class PaymentsAddPlan extends PaymentsEvent {
  final PaymentPlan plan;
  final List<PaymentEntry> initialEntries;
  PaymentsAddPlan(this.plan, this.initialEntries);
}

class PaymentsUpdatePlan extends PaymentsEvent {
  final PaymentPlan plan;
  final List<PaymentEntry> newEntries;
  PaymentsUpdatePlan(this.plan, this.newEntries);
}

class PaymentsUpdateEntry extends PaymentsEvent {
  final PaymentEntry entry;
  PaymentsUpdateEntry(this.entry);
}

class PaymentsDeleteEntry extends PaymentsEvent {
  final String entryId;
  PaymentsDeleteEntry(this.entryId);
}

class PaymentsDeletePlan extends PaymentsEvent {
  final String planId;
  PaymentsDeletePlan(this.planId);
}

class PaymentsGenerateEntries extends PaymentsEvent {
  // Utility event if we need to manually trigger generation
  final PaymentPlan plan;
  PaymentsGenerateEntries(this.plan);
}

// Logic for partial payments / carry forward handled in UI or specialized event?
// "Remaining balance is added to next scheduled entry, OR moved to a user-selected date..."
// This implies complex logic.
class PaymentsSettleEntry extends PaymentsEvent {
  final PaymentEntry entry;
  final double paidAmount;
  final String paymentDate;
  final String actionForBalance; // 'addToNext', 'moveToDate', 'newEntry', 'none' (if full)
  final String? newDate; // if moveToDate or newEntry

  PaymentsSettleEntry({
    required this.entry,
    required this.paidAmount,
    required this.paymentDate,
    this.actionForBalance = 'none',
    this.newDate,
  });
}
