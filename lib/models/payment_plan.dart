enum PaymentFrequency {
  oneTime,
  weekly,
  monthly,
  quarterly,
}

extension PaymentFrequencyExtension on PaymentFrequency {
  String get displayName {
    switch (this) {
      case PaymentFrequency.oneTime:
        return 'One-Time';
      case PaymentFrequency.weekly:
        return 'Weekly';
      case PaymentFrequency.monthly:
        return 'Monthly';
      case PaymentFrequency.quarterly:
        return 'Quarterly';
    }
  }

  static PaymentFrequency fromString(String value) {
    switch (value) {
      case 'oneTime':
        return PaymentFrequency.oneTime;
      case 'weekly':
        return PaymentFrequency.weekly;
      case 'monthly':
        return PaymentFrequency.monthly;
      case 'quarterly':
        return PaymentFrequency.quarterly;
      default:
        return PaymentFrequency.oneTime;
    }
  }
}

class PaymentPlan {
  String id;
  int clientId;
  String? name; // Optional reference name
  PaymentFrequency frequency;
  double baseAmount;
  String startDate;
  String? endDate;
  bool active;
  String createdAt;
  String? notes; // Added notes field
  
  // Optional: Custom overrides or specific metadata can go here

  PaymentPlan({
    required this.id,
    required this.clientId,
    this.name,
    required this.frequency,
    required this.baseAmount,
    required this.startDate,
    this.endDate,
    this.active = true,
    required this.createdAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'name': name,
      'frequency': frequency.name,
      'baseAmount': baseAmount,
      'startDate': startDate,
      'endDate': endDate,
      'active': active,
      'createdAt': createdAt,
      'notes': notes,
    };
  }

  factory PaymentPlan.fromJson(Map<String, dynamic> json) {
    return PaymentPlan(
      id: json['id'] ?? '',
      clientId: json['clientId'],
      name: json['name'],
      frequency: PaymentFrequencyExtension.fromString(json['frequency'] ?? 'oneTime'),
      baseAmount: (json['baseAmount'] as num).toDouble(),
      startDate: json['startDate'],
      endDate: json['endDate'],
      active: json['active'] ?? true,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      notes: json['notes'],
    );
  }
  
  PaymentPlan copyWith({
    String? id,
    int? clientId,
    String? name,
    PaymentFrequency? frequency,
    double? baseAmount,
    String? startDate,
    String? endDate,
    bool? active,
    String? createdAt,
    String? notes,
  }) {
    return PaymentPlan(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      baseAmount: baseAmount ?? this.baseAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}
