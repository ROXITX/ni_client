import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/payment_entry.dart';
import '../bloc/payments_bloc.dart';

class PaymentDialogHelpers {
  static void showPartialPaymentDialog(BuildContext context, PaymentEntry entry, bool isLastEntry) {
    final maxAmount = entry.amount - entry.paidAmount;
    final amountCtrl = TextEditingController(text: maxAmount.toStringAsFixed(0));
    
    String action = isLastEntry ? 'moveToDate' : 'addToNext'; // Default
    DateTime? customDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Partial Payment Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(
                      labelText: 'Amount Paying Now', 
                      prefixText: '₹',
                      border: const OutlineInputBorder(),
                      helperText: 'Max: ₹${maxAmount.toStringAsFixed(0)}',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 24),
                  const Text('Remaining Balance Action:', style: TextStyle(fontWeight: FontWeight.bold)),
                  
                  if (!isLastEntry)
                    RadioListTile<String>(
                      title: const Text('Add to Next Scheduled Payment'),
                      value: 'addToNext',
                      groupValue: action,
                      onChanged: (v) => setState(() => action = v!),
                    ),
                    
                  RadioListTile<String>(
                     title: const Text('Move to Custom Date'),
                    value: 'moveToDate',
                    groupValue: action,
                    onChanged: (v) => setState(() {
                       action = v!;
                       customDate ??= DateTime.now().add(const Duration(days: 7));
                    }),
                  ),
                  
                  if (action == 'moveToDate')
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: customDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => customDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'New Due Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(DateFormat('yyyy-MM-dd').format(customDate ?? DateTime.now())),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final payAmount = double.tryParse(amountCtrl.text);
                  if (payAmount == null || payAmount <= 0 || payAmount > maxAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Amount')));
                    return;
                  }
                  
                  if (action == 'moveToDate' && customDate == null) {
                     customDate = DateTime.now().add(const Duration(days: 7));
                  }

                  Navigator.pop(ctx);
                  context.read<PaymentsBloc>().add(
                    PaymentsSettleEntry(
                      entry: entry, 
                      paidAmount: payAmount, 
                      paymentDate: DateTime.now().toIso8601String(),
                      actionForBalance: action,
                      newDate: action == 'moveToDate' ? DateFormat('yyyy-MM-dd').format(customDate!) : null,
                    )
                  );
                },
                child: const Text('Confirm Payment'),
              ),
            ],
          );
        }
      )
    );
  }

  static void handlePay(BuildContext context, PaymentEntry entry, bool isLastEntry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Text('Is this a full payment of ₹${(entry.amount - entry.paidAmount).toStringAsFixed(0)}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showPartialPaymentDialog(context, entry, isLastEntry);
            },
            child: const Text('Partial Payment'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<PaymentsBloc>().add(
                PaymentsSettleEntry(
                  entry: entry, 
                  paidAmount: (entry.amount - entry.paidAmount), 
                  paymentDate: DateTime.now().toIso8601String()
                )
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Full Payment', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  static void handleRevert(BuildContext context, PaymentEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revert Payment Status'),
        content: const Text('This will reset the entry to "Unpaid" and clear the paid amount. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final updated = PaymentEntry(
                 id: entry.id,
                 planId: entry.planId,
                 clientId: entry.clientId,
                 dueDate: entry.dueDate,
                 amount: entry.amount,
                 paidAmount: 0.0,
                 status: PaymentStatus.unpaid,
                 notes: entry.notes,
                 paidDate: null,
                 read: entry.read,
              );
              context.read<PaymentsBloc>().add(PaymentsUpdateEntry(updated));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Revert', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  static void handlePostpone(BuildContext context, PaymentEntry entry, bool isLastEntry) {
    String action = isLastEntry ? 'moveToDate' : 'addToNext'; // Default
    DateTime? customDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Postpone Payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     'Current Due: ${DateFormat('MMM d, yyyy').format(DateTime.parse(entry.dueDate))}',
                     style: TextStyle(color: Colors.grey[600], fontSize: 13),
                   ),
                   const SizedBox(height: 16),
                   const Text('Action:', style: TextStyle(fontWeight: FontWeight.bold)),
                   
                   if (!isLastEntry)
                    RadioListTile<String>(
                      title: const Text('Add to Next Scheduled Payment'),
                      subtitle: const Text('Merge amount with the next entry'),
                      value: 'addToNext',
                      groupValue: action,
                      onChanged: (v) => setState(() => action = v!),
                    ),
                    
                  RadioListTile<String>(
                    title: const Text('Move to Custom Date'),
                    subtitle: const Text('Select a new due date'),
                    value: 'moveToDate',
                    groupValue: action,
                    onChanged: (v) => setState(() {
                       action = v!;
                       customDate ??= DateTime.tryParse(entry.dueDate)?.add(const Duration(days: 7)) ?? DateTime.now().add(const Duration(days: 7));
                    }),
                  ),
                  
                  if (action == 'moveToDate')
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: customDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => customDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'New Due Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_month),
                        ),
                        child: Text(DateFormat('yyyy-MM-dd').format(customDate ?? DateTime.now())),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                   if (action == 'moveToDate' && customDate == null) {
                     customDate = DateTime.now().add(const Duration(days: 7));
                   }
                   
                   Navigator.pop(ctx);
                   context.read<PaymentsBloc>().add(
                     PaymentsSettleEntry(
                       entry: entry, 
                       paidAmount: 0.0, 
                       paymentDate: DateTime.now().toIso8601String(),
                       actionForBalance: action,
                       newDate: action == 'moveToDate' ? DateFormat('yyyy-MM-dd').format(customDate!) : null,
                     )
                   );
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        }
      )
    );
  }
}
