import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/payment_plan.dart';
import '../../../../models/payment_entry.dart';
import '../bloc/payments_bloc.dart';
import '../../../../core/utils/date_utils.dart'; // Assuming exist, or use generic
import 'package:intl/intl.dart';
import '../screens/payment_edit_screen.dart';

class PaymentPlanCard extends StatelessWidget {
  final PaymentPlan plan;
  final List<PaymentEntry> entries;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const PaymentPlanCard({
    super.key,
    required this.plan,
    required this.entries,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate stats
    final totalDue = entries.fold(0.0, (sum, e) => sum + e.amount);
    final totalPaid = entries.fold(0.0, (sum, e) => sum + e.paidAmount);
    final nextDueEntry = entries
        .where((e) => e.status != PaymentStatus.paid && e.status != PaymentStatus.paid) // Simplified check
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    
    final nextDue = nextDueEntry.isNotEmpty ? nextDueEntry.first : null;

    final progress = totalDue > 0 ? totalPaid / totalDue : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name ?? '${plan.frequency.displayName} Plan',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                           'Entries: ${entries.length} • Started: ${DateFormat('MMM d, y').format(DateTime.parse(plan.startDate))}',
                           style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                        if (plan.notes != null && plan.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Notes: ${plan.notes}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: plan.active ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      plan.active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: plan.active ? const Color(0xFF166534) : const Color(0xFF4B5563),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Button removed
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                      onPressed: onDelete,
                      tooltip: 'Delete Plan',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Progress Bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFF3F4F6),
                color: const Color(0xFF2563EB),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                     'Paid: ₹${totalPaid.toStringAsFixed(0)} / ₹${totalDue.toStringAsFixed(0)}',
                     style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4B5563)),
                   ),
                   if (nextDue != null)
                     Text(
                       'Next Due: ${DateFormat('MMM d').format(DateTime.parse(nextDue.dueDate))}',
                       style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFDC2626)),
                     )
                   else
                     const Text(
                       'All Paid',
                       style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF16A34A)),
                     ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
