import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../models/payment_plan.dart';
import '../../../../models/payment_entry.dart';
import '../bloc/payments_bloc.dart';
import '../../../../core/theme/design_tokens.dart';

class PaymentEditScreen extends StatefulWidget {
  final PaymentPlan plan;
  const PaymentEditScreen({super.key, required this.plan});

  @override
  State<PaymentEditScreen> createState() => _PaymentEditScreenState();
}

class _PaymentEditScreenState extends State<PaymentEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late double _amount;
  late PaymentFrequency _frequency;
  late DateTime _startDate;
  DateTime? _endDate;
  
  String? _name;
  String? _notes;

  @override
  void initState() {
    super.initState();
    _name = widget.plan.name;
    _notes = widget.plan.notes;
    // Assuming baseAmount is now holding the Total Amount as per new logic.
    // If updating old plans which stored Per Cycle, this might look weird initially,
    // but user is "altering everything", so they can fix it.
    _amount = widget.plan.baseAmount; 
    _frequency = widget.plan.frequency;
    
    try {
      _startDate = DateFormat('yyyy-MM-dd').parse(widget.plan.startDate);
    } catch (_) {
      _startDate = DateTime.now();
    }
    
    if (widget.plan.endDate != null) {
      try {
        _endDate = DateFormat('yyyy-MM-dd').parse(widget.plan.endDate!);
      } catch (_) {}
    } else {
      // Default end date if missing for recurring
      if (_frequency != PaymentFrequency.oneTime) {
         _endDate = _startDate.add(const Duration(days: 30));
      }
    }
  }

  int _calculateInstallments() {
     if (_frequency == PaymentFrequency.oneTime) return 1;
     if (_endDate == null) return 1; 
     
     DateTime current = _startDate;
     int count = 0;
     while (!current.isAfter(_endDate!.add(const Duration(days: 0)))) { 
       count++;
       if (_frequency == PaymentFrequency.weekly) {
          current = current.add(const Duration(days: 7));
       } else if (_frequency == PaymentFrequency.monthly) {
          current = DateTime(current.year, current.month + 1, current.day);
       } else if (_frequency == PaymentFrequency.quarterly) {
          current = DateTime(current.year, current.month + 3, current.day);
       }
     }
     return count > 0 ? count : 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Payment Plan'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing this plan will regenerate all future payment entries based on the new settings.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Name
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: 'Payment Name / Reference',
                  hintText: 'e.g. Tuition Fee 2024',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                onSaved: (v) => _name = v,
              ),
              const SizedBox(height: 16),
              
              // Amount (Total)
              TextFormField(
                initialValue: _amount.toString(),
                decoration: const InputDecoration(
                  labelText: 'Total Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter total amount';
                  if (double.tryParse(value) == null) return 'Invalid amount';
                  return null;
                },
                onSaved: (v) => _amount = double.parse(v!),
              ),
              const SizedBox(height: 16),
              
              // Frequency
              DropdownButtonFormField<PaymentFrequency>(
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                value: _frequency,
                items: PaymentFrequency.values.map((f) => DropdownMenuItem(
                  value: f,
                  child: Text(f.displayName),
                )).toList(),
                onChanged: (v) => setState(() {
                  _frequency = v!;
                  if (_frequency == PaymentFrequency.oneTime) {
                    _endDate = null;
                  } else if (_endDate == null) {
                    _endDate = _startDate.add(const Duration(days: 30));
                  }
                }),
              ),
              const SizedBox(height: 16),
              
              // Start Date
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                       _startDate = picked;
                       if (_endDate != null && _endDate!.isBefore(_startDate)) {
                          _endDate = _startDate.add(const Duration(days: 1));
                       }
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  child: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                ),
              ),
              const SizedBox(height: 16),
              
              // End Date
              if (_frequency != PaymentFrequency.oneTime) ...[
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
                        firstDate: _startDate, 
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                        prefixIcon: Icon(Icons.event_busy),
                        helperText: 'Required for recurring',
                      ),
                      child: Text(_endDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(_endDate!)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_endDate != null)
                     Builder(builder: (ctx) {
                        final count = _calculateInstallments();
                        return Text(
                          'Will regenerate $count payments.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                        );
                     }),
              ],
 
              const SizedBox(height: 16),
              // Notes
              TextFormField(
                initialValue: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes / Comments',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
                maxLines: 3,
                onSaved: (v) => _notes = v,
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update Payment Plan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _submit() {
    if (_formKey.currentState!.validate()) {
       if (_frequency != PaymentFrequency.oneTime && _endDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an End Date.')));
          return;
       }
       
      _formKey.currentState!.save();
      
      final numInstallments = _calculateInstallments();
      final perCycleAmount = _amount / numInstallments;
      
      List<PaymentEntry> entries = [];
      DateTime current = _startDate;
      
      for (int i = 0; i < numInstallments; i++) {
         entries.add(PaymentEntry(
           id: '', 
           planId: widget.plan.id, // KEEP SAME PLAN ID
           clientId: widget.plan.clientId,
           dueDate: DateFormat('yyyy-MM-dd').format(current),
           amount: double.parse(perCycleAmount.toStringAsFixed(2)),
           status: PaymentStatus.unpaid,
           notes: null,
         ));
         
         if (_frequency == PaymentFrequency.weekly) {
           current = current.add(const Duration(days: 7));
         } else if (_frequency == PaymentFrequency.monthly) {
           current = DateTime(current.year, current.month + 1, current.day);
         } else if (_frequency == PaymentFrequency.quarterly) {
           current = DateTime(current.year, current.month + 3, current.day);
         }
      }
      
      if (entries.isNotEmpty) {
         final currentTotal = entries.fold(0.0, (sum, e) => sum + e.amount);
         final diff = _amount - currentTotal;
         if (diff.abs() > 0.001) {
             final last = entries.last;
             entries.last = last.copyWith(amount: double.parse((last.amount + diff).toStringAsFixed(2)));
         }
      }
      
      final updatedPlan = widget.plan.copyWith(
        name: _name,
        frequency: _frequency,
        baseAmount: _amount,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : DateFormat('yyyy-MM-dd').format(_startDate),
        notes: _notes,
      );
      
      context.read<PaymentsBloc>().add(PaymentsUpdatePlan(updatedPlan, entries));
      
      Navigator.pop(context);
    }
  }
}
