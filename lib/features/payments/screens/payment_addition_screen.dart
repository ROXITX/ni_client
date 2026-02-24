import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // You might need to add uuid to pubspec, or just use Random/Time
import '../../../../models/payment_plan.dart';
import '../../../../models/payment_entry.dart';
import '../bloc/payments_bloc.dart';
import '../../../../models/client.dart';
import '../../../../core/theme/design_tokens.dart';

class PaymentAdditionScreen extends StatefulWidget {
  final Client client;
  const PaymentAdditionScreen({super.key, required this.client});

  @override
  State<PaymentAdditionScreen> createState() => _PaymentAdditionScreenState();
}

class _PaymentAdditionScreenState extends State<PaymentAdditionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  double? _amount;
  PaymentFrequency _frequency = PaymentFrequency.oneTime;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  int _installments = 1; // Only for finite recurring
  bool _isRecurringFinite = false; // "End after X installments" vs "End Date" ?
  // Spec says: "End Date (for recurring payments)" as optional.
  
  String? _name;
  String? _notes;


  
  // Logic helpers
  int _calculateInstallments() {
     if (_frequency == PaymentFrequency.oneTime) return 1;
     if (_endDate == null) return 1; // Should not happen with validation
     
     // Robust calculation 
     DateTime current = _startDate;
     int count = 0;
     while (!current.isAfter(_endDate!.add(const Duration(days: 0)))) { // Inclusive roughly
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
        title: const Text('Add Payment Plan'),
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
              Text(
                'New Payment for ${widget.client.firstName} ${widget.client.lastName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),
              
              // Name (Optional)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Payment Name / Reference (Optional)',
                  hintText: 'e.g. Tuition Fee 2024',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                onSaved: (v) => _name = v,
              ),
              const SizedBox(height: 16),
              
              // Amount (Total)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Total Amount', // CHANGED
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
                    // Auto-set reasonable default
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
                       // Adjust end date if needed (must be >= start)
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
              
              // End Date (Mandatory for Recurring)
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
                        helperText: 'Required to calculate cycles',
                      ),
                      child: Text(_endDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(_endDate!)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Installment Preview
                  if (_endDate != null)
                     Builder(builder: (ctx) {
                        final count = _calculateInstallments();
                        return Text(
                          'Will generate $count payments.',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                        );
                     }),
              ],
 
              const SizedBox(height: 16),
              // Notes
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Notes / Comments (Optional)',
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
                child: const Text('Create Payment Plan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _submit() {
    if (_formKey.currentState!.validate()) {
       // Validate End Date specific
       if (_frequency != PaymentFrequency.oneTime && _endDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an End Date for recurring payments.')));
          return;
       }
       
      _formKey.currentState!.save();
      
      final numInstallments = _calculateInstallments();
      final perCycleAmount = _amount! / numInstallments; // Auto-Calc
      
      // Generate Entries
      List<PaymentEntry> entries = [];
      DateTime current = _startDate;
      
      for (int i = 0; i < numInstallments; i++) {
         entries.add(PaymentEntry(
           id: '', 
           planId: '',
           clientId: widget.client.id,
           dueDate: DateFormat('yyyy-MM-dd').format(current),
           amount: double.parse(perCycleAmount.toStringAsFixed(2)), // Round to 2 decimals
           status: PaymentStatus.unpaid,
           notes: null, // Notes on plan
         ));
         
         // Advance
         if (_frequency == PaymentFrequency.weekly) {
           current = current.add(const Duration(days: 7));
         } else if (_frequency == PaymentFrequency.monthly) {
           current = DateTime(current.year, current.month + 1, current.day);
         } else if (_frequency == PaymentFrequency.quarterly) {
           current = DateTime(current.year, current.month + 3, current.day);
         }
      }
      
      // Fix rounding error on last entry? 
      // e.g. 100 / 3 = 33.33, 33.33, 33.33 -> 99.99. Missing 0.01.
      if (entries.isNotEmpty) {
         final currentTotal = entries.fold(0.0, (sum, e) => sum + e.amount);
         final diff = _amount! - currentTotal;
         if (diff.abs() > 0.001) {
             final last = entries.last;
             entries.last = last.copyWith(amount: double.parse((last.amount + diff).toStringAsFixed(2)));
         }
      }
      
      final plan = PaymentPlan(
        id: '', 
        clientId: widget.client.id,
        name: _name,
        frequency: _frequency,
        baseAmount: _amount!, // Storing TOTAL amount here now? Or Base (per cycle)?
        // Model doc says: "baseAmount". Usually implies per cycle. 
        // If we store Total, we should probably rename or be clear. 
        // User said "get the total amount". 
        // Let's store TOTAL in baseAmount for now if that represents the Plan's value. 
        // OR better: keep baseAmount as Per Cycle for compatibility? 
        // User wants to EDIT it. If I store Per Cycle, and load Edit screen, I show Per Cycle?
        // User wants "Edit ... alter everything ... get total amount".
        // It's cleaner to store TOTAL if the inputs are TOTAL.
        // Let's assume baseAmount = Total Amount of the plan.
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : DateFormat('yyyy-MM-dd').format(_startDate),
        createdAt: DateTime.now().toIso8601String(),
        notes: _notes, 
      );
      
      context.read<PaymentsBloc>().add(PaymentsAddPlan(plan, entries));
      
      Navigator.pop(context);
    }
  }
}
