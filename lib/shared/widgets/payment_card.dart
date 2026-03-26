import 'package:flutter/material.dart';
import '../../../models/payment_entry.dart';
import '../../../models/client.dart';

class PaymentCard extends StatelessWidget {
  final PaymentEntry payment;
  final Client client;
  final Map<String, dynamic> details;
  final void Function(PaymentEntry, String)? onActionSelected;

  const PaymentCard({
    super.key,
    required this.payment,
    required this.client,
    required this.details,
    this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = details['color'] ?? Colors.grey;
    final IconData statusIcon = details['icon'] ?? Icons.payment;
    final List<String> actions = details['actions'] ?? [];

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
               width: 110,
               color: statusColor,
               padding: const EdgeInsets.all(12.0),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(statusIcon, color: Colors.white, size: 32),
                   const SizedBox(height: 8),
                   Text(
                     payment.status.displayName,
                     style: const TextStyle(
                       color: Colors.white,
                       fontWeight: FontWeight.bold,
                       fontSize: 13,
                     ),
                     textAlign: TextAlign.center,
                   ),
                 ],
               ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${client.firstName} ${client.lastName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        if (actions.isNotEmpty && onActionSelected != null)
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF6B7280)),
                              onSelected: (action) => onActionSelected!(payment, action),
                              itemBuilder: (BuildContext context) {
                                return actions.map((String action) {
                                  return PopupMenuItem<String>(
                                    value: action,
                                    child: Text(action),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due Date: ${payment.dueDate}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Amount: ₹${payment.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (payment.paidAmount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Paid So Far: ₹${payment.paidAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (payment.notes != null && payment.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Notes: ${payment.notes}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF9CA3AF),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
