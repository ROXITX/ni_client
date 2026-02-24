part of 'payments_bloc.dart';

abstract class PaymentsState {}

class PaymentsInitial extends PaymentsState {}

class PaymentsLoading extends PaymentsState {}

class PaymentsLoaded extends PaymentsState {
  final List<PaymentPlan> plans;
  final List<PaymentEntry> entries;
  
  // Computed properties
  double get totalDue => entries.where((e) => e.status != PaymentStatus.paid).fold(0, (sum, e) => sum + (e.amount - e.paidAmount));
  double get totalPaid => entries.fold(0, (sum, e) => sum + e.paidAmount);

  PaymentsLoaded(this.plans, this.entries);
}

class PaymentsError extends PaymentsState {
  final String message;
  PaymentsError(this.message);
}
