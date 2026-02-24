enum PaymentStatus {
  paid,
  partiallyPaid,
  unpaid,
  postponed,
  overdue, // Calculated status, but can be explicit if needed
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.postponed:
        return 'Postponed';
      case PaymentStatus.overdue:
        return 'Overdue';
    }
  }

  static PaymentStatus fromString(String value) {
    switch (value) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partiallyPaid':
        return PaymentStatus.partiallyPaid;
      case 'unpaid':
        return PaymentStatus.unpaid;
      case 'postponed':
        return PaymentStatus.postponed;
      case 'overdue':
        return PaymentStatus.overdue;
      default:
        return PaymentStatus.unpaid;
    }
  }
}

class PaymentEntry {
  String id;
  String planId; // Reference to the parent plan
  int clientId;
  String dueDate;
  double amount; // Total amount due for this entry
  double paidAmount; // Amount already paid
  PaymentStatus status;
  String? notes;
  String? paidDate; // Date when full payment was completed (or last partial payment)
  bool read; // For notifications

  PaymentEntry({
    required this.id,
    required this.planId,
    required this.clientId,
    required this.dueDate,
    required this.amount,
    this.paidAmount = 0.0,
    required this.status,
    this.notes,
    this.paidDate,
    this.read = false,
  });

  bool get isPaid => status == PaymentStatus.paid;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planId': planId,
      'clientId': clientId,
      'dueDate': dueDate,
      'amount': amount,
      'paidAmount': paidAmount,
      'status': status.name,
      'notes': notes,
      'paidDate': paidDate,
      'read': read,
    };
  }

  factory PaymentEntry.fromJson(Map<String, dynamic> json) {
    return PaymentEntry(
      id: json['id'] ?? '',
      planId: json['planId'] ?? '',
      clientId: json['clientId'],
      dueDate: json['dueDate'],
      amount: (json['amount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      status: PaymentStatusExtension.fromString(json['status'] ?? 'unpaid'),
      notes: json['notes'],
      paidDate: json['paidDate'],
      read: json['read'] ?? false,
    );
  }

  PaymentEntry copyWith({
    String? id,
    String? planId,
    int? clientId,
    String? dueDate,
    double? amount,
    double? paidAmount,
    PaymentStatus? status,
    String? notes,
    String? paidDate,
    bool? read,
  }) {
    return PaymentEntry(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      clientId: clientId ?? this.clientId,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      paidDate: paidDate ?? this.paidDate,
      read: read ?? this.read,
    );
  }
}
