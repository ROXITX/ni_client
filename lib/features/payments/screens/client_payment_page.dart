import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../models/client.dart';
import '../../../../models/payment_entry.dart';
import '../../../../models/payment_plan.dart';
import '../bloc/payments_bloc.dart';
import '../widgets/payment_plan_card.dart';
import 'payment_addition_screen.dart';
import '../../../../core/theme/design_tokens.dart';
// import 'payment_detail_view.dart'; // To implement next

class ClientPaymentPage extends StatefulWidget {
  final Client client;

  const ClientPaymentPage({super.key, required this.client});

  @override
  State<ClientPaymentPage> createState() => _ClientPaymentPageState();
}

class _ClientPaymentPageState extends State<ClientPaymentPage> {
  @override
  void initState() {
    super.initState();
    // Verify Bloc is provided. Typically provided by global or parent.
    // Assuming context has read<PaymentsBloc> via global injection in main.
    context.read<PaymentsBloc>().add(PaymentsFetch(widget.client.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payments: ${widget.client.firstName} ${widget.client.lastName}'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: BlocBuilder<PaymentsBloc, PaymentsState>(
        builder: (context, state) {
          if (state is PaymentsLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is PaymentsError) {
            return Center(child: Text('Error: ${state.message}'));
          } else if (state is PaymentsLoaded) {
            if (state.plans.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment_outlined, size: 64, color: Color(0xFF9CA3AF)),
                    const SizedBox(height: 16),
                    const Text('No Payment Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B7280))),
                    const SizedBox(height: 8),
                    const Text('Create a payment plan to get started.', style: TextStyle(color: Color(0xFF9CA3AF))),
                  ],
                ),
              );
            }
            
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [



                // Summary Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.primary, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                         _buildSummaryItem('Total Due', state.totalDue, Colors.red[700]!),
                         Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                         _buildSummaryItem('Total Paid', state.totalPaid, Colors.green[700]!),
                       ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Add Button removed

                
                // Plans List
                const Text('Assigned Payments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF374151))),
                const SizedBox(height: 8),
                
                ...state.plans.map((plan) {
                  final entries = state.entries.where((e) => e.planId == plan.id).toList();
                  return PaymentPlanCard(
                    plan: plan,
                    entries: entries,
                    onTap: () {
                      _showPlanDetails(context, plan, entries);
                    },
                    onDelete: null,
                  );
                }),
              ],
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PaymentAdditionScreen(client: widget.client)),
    );
  }

  void _showPlanDetails(BuildContext context, PaymentPlan plan, List<PaymentEntry> entries) {
     // Navigate to detail view
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => PaymentDetailScreen(plan: plan, client: widget.client)),
     );
  }

  void _handleDeletePlan(BuildContext context, PaymentPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Plan'),
        content: Text('Are you sure you want to delete "${plan.name}" and all its entries? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
               context.read<PaymentsBloc>().add(PaymentsDeletePlan(plan.id));
               Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      )
    );
  }
}

// Simple Detail Screen
class PaymentDetailScreen extends StatelessWidget {
  final PaymentPlan plan;
  final Client client;

  const PaymentDetailScreen({
    super.key,
    required this.plan,
    required this.client,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PaymentsBloc, PaymentsState>(
      builder: (context, state) {
        if (state is! PaymentsLoaded) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Check if plan still exists (might have been deleted)
        final latestPlan = state.plans.cast<PaymentPlan?>().firstWhere(
            (p) => p?.id == plan.id, 
            orElse: () => null
        );
        
        if (latestPlan == null) {
           return const Scaffold(body: Center(child: Text('Plan no longer exists')));
        }

        final entries = state.entries
            .where((e) => e.planId == plan.id)
            .toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

        return Scaffold(
          appBar: AppBar(
            title: Text(latestPlan.name ?? 'Payment Details'),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          backgroundColor: const Color(0xFFF9FAFB),
          body: entries.isEmpty
            ? const Center(child: Text('No entries found for this plan.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16.0),
                itemCount: entries.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final isLast = index == entries.length - 1;
                  return _buildEntryCard(context, entry, isLastEntry: isLast, key: ValueKey(entry.id));
                },
              ),
        );
      },
    );
  }

  Widget _buildEntryCard(BuildContext context, PaymentEntry entry, {Key? key, required bool isLastEntry}) {
    Color statusColor;
    IconData statusIcon;

    switch (entry.status) {
      case PaymentStatus.paid:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.partiallyPaid:
        statusColor = Colors.orange;
        statusIcon = Icons.timelapse;
        break;
      case PaymentStatus.postponed:
        statusColor = Colors.purple;
        statusIcon = Icons.event_repeat;
        break;
      case PaymentStatus.overdue:
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case PaymentStatus.unpaid:
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.circle_outlined;
    }
    
    // Check if overdue manually if status is unpaid/partial
    bool isActuallyOverdue = false;
    if (entry.status == PaymentStatus.unpaid || entry.status == PaymentStatus.partiallyPaid) {
       final due = DateTime.tryParse(entry.dueDate);
       if (due != null && due.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
          isActuallyOverdue = true;
          statusColor = Colors.red;
          statusIcon = Icons.priority_high; 
       }
    }

    return Card(
      key: key,
      elevation: 0, // Flat nicer look or low elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey.withOpacity(0.2))
      ),
      color: Colors.white,
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Row(
                     children: [
                       Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                       const SizedBox(width: 8),
                       Text(
                         DateFormat('MMM d, yyyy').format(DateTime.parse(entry.dueDate)),
                         style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                       ),
                       if (isActuallyOverdue)
                         Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                            child: Text('Overdue', style: TextStyle(color: Colors.red[700], fontSize: 10, fontWeight: FontWeight.bold)),
                         ),
                     ],
                   ),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                       color: statusColor.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Icon(statusIcon, size: 14, color: statusColor),
                         const SizedBox(width: 4),
                         Text(
                           entry.status.displayName,
                           style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 12),
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount Due', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        Text('₹${entry.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (entry.paidAmount > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Paid So Far', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                          Text('₹${entry.paidAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800])),
                        ],
                      ),
                 ],
               ),
               if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                 const Divider(height: 24),
                 Text(
                   'Notes: ${entry.notes}',
                   style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF4B5563)),
                 ),
               ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEntryAction(BuildContext context, PaymentEntry entry, bool isLastEntry) {
     showModalBottomSheet(
       context: context, 
       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
       builder: (ctx) {
       return SafeArea(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
              if (entry.status == PaymentStatus.paid || entry.status == PaymentStatus.partiallyPaid)
                ListTile(
                  leading: const Icon(Icons.undo, color: Colors.orange),
                  title: const Text('Revert to Unpaid'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleRevert(context, entry);
                  },
                ),
              if (entry.status != PaymentStatus.paid)
                 ListTile(
                   leading: const Icon(Icons.check_circle, color: Colors.green),
                   title: const Text('Mark as Paid'),
                   onTap: () {
                     Navigator.pop(ctx);
                     _handlePay(context, entry, isLastEntry);
                   },
                 ),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.purple),
                title: const Text('Postpone (Change Date)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePostpone(context, entry, isLastEntry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Details'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleEdit(context, entry);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Entry'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleDelete(context, entry);
                },
              ),
            ],
          ),
        );
      });
  }

  void _handleRevert(BuildContext context, PaymentEntry entry) {
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
              // Manually construct the update because copyWith might not support setting fields to null easily
              // or requires specific logic in Bloc to respect nulls. 
              // Sending an update with explicitly reset fields.
              final updated = PaymentEntry(
                 id: entry.id,
                 planId: entry.planId,
                 clientId: entry.clientId,
                 dueDate: entry.dueDate,
                 amount: entry.amount,
                 paidAmount: 0.0, // Reset paid amount
                 status: PaymentStatus.unpaid, // Reset status
                 notes: entry.notes,
                 paidDate: null, // Reset paid date
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
  
  void _handlePay(BuildContext context, PaymentEntry entry, bool isLastEntry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Text('Is this a full payment of ₹${(entry.amount - entry.paidAmount).toStringAsFixed(0)}?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPartialPaymentDialog(context, entry, isLastEntry);
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

  void _showPartialPaymentDialog(BuildContext context, PaymentEntry entry, bool isLastEntry) {
    final maxAmount = entry.amount - entry.paidAmount;
    final amountCtrl = TextEditingController(text: maxAmount.toString());
    
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
                       if (customDate == null) {
                         customDate = DateTime.now().add(const Duration(days: 7));
                       }
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

  void _handlePostpone(BuildContext context, PaymentEntry entry, bool isLastEntry) {
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
                       if (customDate == null) {
                         // Default to 1 week from now if not set
                         customDate = DateTime.tryParse(entry.dueDate)?.add(const Duration(days: 7)) ?? DateTime.now().add(const Duration(days: 7));
                       }
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
                   // Use PaymentsSettleEntry with 0 payment to trigger "move balance" logic
                   context.read<PaymentsBloc>().add(
                     PaymentsSettleEntry(
                       entry: entry, 
                       paidAmount: 0.0, 
                       paymentDate: DateTime.now().toIso8601String(), // Irrelevant for 0 payment
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

  void _handleEdit(BuildContext context, PaymentEntry entry) {
    final amountCtrl = TextEditingController(text: entry.amount.toString());
    final notesCtrl = TextEditingController(text: entry.notes ?? '');
    DateTime selectedDate = DateTime.parse(entry.dueDate); // Assuming format yyyy-MM-dd
    final bool isPaid = entry.status == PaymentStatus.paid; // Check if paid
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Entry Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    decoration: InputDecoration(
                       labelText: 'Amount', 
                       prefixText: '₹', 
                       border: const OutlineInputBorder(),
                       // Add locked helper text
                       helperText: isPaid ? 'Cannot edit amount for paid entries' : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    enabled: !isPaid, // Disable if paid
                    style: isPaid ? const TextStyle(color: Colors.grey) : null, // Grey out if disabled
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_month),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final newAmount = double.tryParse(amountCtrl.text);
                  if (newAmount != null) {
                    final updated = entry.copyWith(
                      amount: newAmount,
                      dueDate: DateFormat('yyyy-MM-dd').format(selectedDate),
                      notes: notesCtrl.text.isNotEmpty ? notesCtrl.text : null,
                    );
                    context.read<PaymentsBloc>().add(PaymentsUpdateEntry(updated));
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        }
      )
    );
  }

  void _handleDelete(BuildContext context, PaymentEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this payment entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
               context.read<PaymentsBloc>().add(PaymentsDeleteEntry(entry.id));
               Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      )
    );
  }
}
