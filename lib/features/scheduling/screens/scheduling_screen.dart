import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore; // Alias to avoid conflict if any
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../../core/utils/date_utils.dart';
import '../bloc/scheduling_bloc.dart';
import '../../clients/bloc/clients_bloc.dart';
import '../../clients/widgets/client_list_widget.dart';
import 'package:ni_client/shared/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:math';

// Import for date formatting
import 'package:intl/intl.dart' as intl;

class SchedulingScreen extends StatefulWidget {
  final Client? preSelectedClient;
  final Map<String, dynamic>? initialProgram; // For modify flow
  
  const SchedulingScreen({
    super.key, 
    this.preSelectedClient,
    this.initialProgram,
  });

  @override
  State<SchedulingScreen> createState() => _SchedulingScreenState();
}

class _SchedulingScreenState extends State<SchedulingScreen> {
  final _schedulingFormKey = GlobalKey<FormState>();
  
  // Navigation State
  String currentView = 'scheduling'; // 'scheduling', 'confirmation'
  List<String> viewHistory = ['scheduling'];
  
  // Controllers
  final _schedulingCountCtrl = TextEditingController();
  final _schedulingMonthlyDateCtrl = TextEditingController();
  final _startDateText = TextEditingController();
  final _clientSearchCtrl = TextEditingController(); // For client autocomplete

  // Form State
  Client? _selectedClient; // State for selected client
  Client? modifyingClient; // Should be sync with _selectedClient or passed in
  ProgramType? originalProgramType; // Logic for modification mode
  
  // Scheduling Params
  int? schedulingCount;
  DateTime? schedulingStartDate;
  String schedulingFrequency = 'Daily';
  String schedulingTimeSlot = ''; // Actually this should be nullable in logic but string in dropdown
  int schedulingWeeklyDay = 1;
  int schedulingMonthlyDate = 1;
  ProgramType? schedulingProgramType;
  SessionDuration? schedulingDuration = SessionDuration.oneHour;
  
  List<String> timeSlots = [];
  bool _isSaving = false;
  
  // Draft Data
  List<Map<String, dynamic>> newSchedule = []; // Storing simplified map for local preview
  Set<String> clashTempIds = {}; 

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.preSelectedClient;
    modifyingClient = widget.preSelectedClient;
    // If preSelectedClient passed, set it
    if (widget.preSelectedClient != null) {
      _clientSearchCtrl.text = '${widget.preSelectedClient!.firstName} ${widget.preSelectedClient!.lastName}';
      _selectedClient = widget.preSelectedClient; // Assuming selectedClientForScheduling maps to _selectedClient
    }

    // If initialProgram passed (Modify Flow), populate fields
    if (widget.initialProgram != null) {
      final p = widget.initialProgram!;
      
      // Populate fields
      final count = p['count'];
      _schedulingCountCtrl.text = count?.toString() ?? '';
      schedulingCount = count;
      
      if (p['startDate'] != null) {
        _startDateText.text = p['startDate'];
        schedulingStartDate = DateTime.tryParse(p['startDate']);
      }
      
      schedulingFrequency = p['frequency'] ?? 'Daily';
      
      // Parse Time Slot (String -> TimeOfDay/Duration logic is tricky, 
      // but here we just need to set the value if it mimics legacy state variables)
      // Legacy: schedulingTimeSlot = (info['timeSlot'] as String?);
      // In this screen, we might need to verify if we need to select a chip or text.
      // We will assume 'timeSlot' is used in _generateTimeSlots or similar.
      // Wait, _timeSlotCtrl? No, the legacy used Chips depending on Duration.
      if (p['timeSlot'] != null) {
        schedulingTimeSlot = p['timeSlot'];
      }
      
      if (p['duration'] != null) {
         schedulingDuration = SessionDurationExtension.fromString(p['duration']);
         // Trigger slot generation
         // context.read<SchedulingBloc>().add(SchedulingDurationChanged(schedulingDuration)); // This would require a BlocProvider higher up
      }

      if (p['programType'] != null) {
        schedulingProgramType = ProgramTypeExtension.fromString(p['programType']);
        // Store original to track modification vs new
        originalProgramType = schedulingProgramType; // Check legacy logic: originalProgramType = ...
      }
      
      if (p['dayOfWeek'] != null && p['dayOfWeek'] is int) {
         schedulingWeeklyDay = p['dayOfWeek']; // Set week day
      }

      if (p['monthlyDate'] != null && p['monthlyDate'] is int) {
        schedulingMonthlyDate = p['monthlyDate'];
        _schedulingMonthlyDateCtrl.text = p['monthlyDate'].toString();
      }
      
      // Note: This initialization is partial. Truly restoring the exact UI state 
      // requires matching all "generate" logic. For now we set the key fields.
    }
    _generateTimeSlots(duration: schedulingDuration!);
  }

  void _generateTimeSlots({required SessionDuration duration}) {
     int durationMinutes = (duration.hours * 60).toInt();
    List<String> slots = [];
    DateTime startTime = DateTime(2022, 1, 1, 6, 0); // 6:00 AM
    DateTime endTime = DateTime(2022, 1, 1, 22, 0); // 10:00 PM

    while (startTime.isBefore(endTime)) {
      DateTime slotEnd = startTime.add(Duration(minutes: durationMinutes));
      if (slotEnd.isAfter(endTime)) break;

      String format(DateTime dt) {
        int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        String ampm = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
      }

      slots.add('${format(startTime)} - ${format(slotEnd)}');
      startTime = startTime.add(const Duration(minutes: 30));
    }
    setState(() {
      timeSlots = slots;
      if (!slots.contains(schedulingTimeSlot)) {
         schedulingTimeSlot = ''; // Reset if invalid
      }
    });
  }

  void _resetSchedulingForm() {
    _schedulingCountCtrl.clear();
    _schedulingMonthlyDateCtrl.clear();
    _startDateText.clear();
    schedulingCount = null;
    schedulingStartDate = null;
    schedulingFrequency = 'Daily';
    schedulingWeeklyDay = 1;
    schedulingMonthlyDate = 1;
    schedulingTimeSlot = '';
    // modifyingClient = null; // Don't reset client if in multi-schedule flow?
    // Maintain client selection often desired.
  }

  @override
  Widget build(BuildContext context) {
    if (currentView == 'confirmation') {
      // Need sessions for clash checking
       // In a real app we'd access the Bloc or Repository to get ALL sessions.
       // For now, we assume we might need to fetch them or pass them.
       // Let's use BlocBuilder to get them from SchedulingBloc which listens to sessions.
       return BlocBuilder<SchedulingBloc, SchedulingState>(
           // Actually we need ALL sessions. SchedulingBloc might only have its own state.
           // Let's use DashboardBloc or similar if available, OR reuse SchedulingBloc's existingSessions logic if exposed
           // Better: wrap the whole screen in a BlocBuilder that provides the context.
           // However, for this refactor, we'll assume we can get them.
           // Let's wrap in BlocBuilder<SchedulingBloc...> even if state is not 'loaded' purely for access?
           // No, SchedulingBloc manages events.
           // We will use a firestore stream or similar? 
           // Simplest: We won't block UI on load, we'll trust clashes are checked in _generateSchedule logic 
           // but `_checkForClashes` needs the list.
           // Let's use `context.read<SchedulingBloc>` ... wait, SchedulingBloc has `_existingSessions` but it's private.
           // The snippet uses `sessions` passed       // We'll use a firestore stream or similar? 
           // Simplest: We won't block UI on load, we'll trust clashes are checked in _generateSchedule logic 
           // but `_checkForClashes` needs the list.
           builder: (context, state) {
              final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
              return StreamBuilder<List<Session>>(
                stream: firestore.FirebaseFirestore.instance
                    .collection('users').doc(userId).collection('sessions')
                    .snapshots().map((snap) => 
                  snap.docs.map((d) => Session.fromJson(d.data())).toList()),
                builder: (context, snapshot) {
                   List<Session> sessions = snapshot.data ?? [];
                   // Filter if needed? No, clash check needs all.
                   return BlocBuilder<ClientsBloc, ClientsState>(
                      builder: (context, clientsState) {
                          List<Client> clients = (clientsState is ClientsLoaded) ? clientsState.clients : [];
                          return Scaffold(
                            body: SafeArea(
                              child: _buildConfirmationView(clients, sessions),
                            ),
                          );
                      }
                   );
                }
              );
           }
       );
    }
    
    // Default View: Scheduling Form
    // Same Stream/Bloc requirement for "Completed/Remaining" stats
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
    return StreamBuilder<List<Session>>(
       stream: firestore.FirebaseFirestore.instance
           .collection('users').doc(userId).collection('sessions')
           .snapshots().map((snap) => 
         snap.docs.map((d) => Session.fromJson(d.data())).toList()),
       builder: (context, snapshot) {
          final sessions = snapshot.data ?? [];
          
          if (_selectedClient == null) {
              return Scaffold(
                 appBar: AppBar(title: const Text('Schedule Sessions')),
                 body: ClientListWidget(
                   onClientSelected: (c) {
                      setState(() {
                          _selectedClient = c;
                          modifyingClient = c;
                      });
                   },
                 ),
              );
          }
           
          return Scaffold(
             appBar: AppBar(
                title: const Text('Schedule Sessions'),
                leading: IconButton(
                   icon: const Icon(Icons.arrow_back),
                   onPressed: () {
                      // If we are in "Modify/Preselected" mode, Back means Pop.
                      if (widget.preSelectedClient != null) {
                         Navigator.pop(context);
                         return;
                      }

                      if (_selectedClient != null) {
                         setState(() {
                            _selectedClient = null;
                            modifyingClient = null;
                         });
                      } else {
                         Navigator.pop(context);
                      }
                   },
                ),
             ),
             body: _buildSchedulingView(sessions),
          );
       }
    );
  }

  Widget _buildSchedulingView(List<Session> sessions) {
    // Keep controllers in sync with current state without setState to avoid keyboard drops
    final expectedCountText = schedulingCount != null ? '${schedulingCount!}' : '';
    if (_schedulingCountCtrl.text != expectedCountText) {
      _schedulingCountCtrl.text = expectedCountText;
      _schedulingCountCtrl.selection = TextSelection.collapsed(offset: _schedulingCountCtrl.text.length);
    }
    final expectedMonthlyText = (schedulingFrequency == 'Monthly' && schedulingMonthlyDate > 0)
        ? '$schedulingMonthlyDate'
        : '';
    if (_schedulingMonthlyDateCtrl.text != expectedMonthlyText) {
      _schedulingMonthlyDateCtrl.text = expectedMonthlyText;
      _schedulingMonthlyDateCtrl.selection = TextSelection.collapsed(offset: _schedulingMonthlyDateCtrl.text.length);
    }

    // The old data-loading block has been REMOVED from the top of this function.

    int completedCount = 0;
    int remainingCount = 0;
    if (modifyingClient != null && originalProgramType != null) {
      // Only count sessions for the specific program type being modified
      final programSessions = sessions.where((s) => 
        s.clientId == modifyingClient!.id && 
        s.programType?.name == originalProgramType?.name
      );
      completedCount = programSessions.where((s) => s.status == 'Completed' || s.status == 'Cancelled').length;
      remainingCount = programSessions.length - completedCount;
    } else if (modifyingClient != null) {
      // Fallback for cases where originalProgramType is null (new client or legacy data)
      final clientSessions = sessions.where((s) => s.clientId == modifyingClient!.id);
      completedCount = clientSessions.where((s) => s.status == 'Completed' || s.status == 'Cancelled').length;
      remainingCount = clientSessions.length - completedCount;
    }

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _schedulingFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        modifyingClient != null
                            ? 'Schedule for ${modifyingClient!.firstName} ${modifyingClient!.lastName}'
                            : 'Schedule Sessions',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                        textAlign: TextAlign.center,
                      ),
                      if (modifyingClient != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                              children: [
                                TextSpan(
                                  text: '$completedCount Completed',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                const TextSpan(text: '  |  '),
                                TextSpan(
                                  text: '$remainingCount Remaining',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Number of Sessions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _schedulingCountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1) return 'Required';
                    return null;
                  },
                  onChanged: (v) => schedulingCount = int.tryParse(v),
                ),
                const SizedBox(height: 16),
                const Text('Start Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _startDateText,
                  readOnly: true,
                  decoration: _inputDecoration(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  onTap: () async {
                    final now = DateTime.now();
                    DateTime initial = schedulingStartDate ?? now;
                    if (initial.isBefore(now)) initial = now;
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        schedulingStartDate = picked;
                        _startDateText.text = AppDateUtils.dateToStr(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Frequency', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: schedulingFrequency,
                  items: ['Daily', 'Weekly', 'Fortnightly', 'Monthly', 'Once only'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  // This now works correctly
                  onChanged: (v) {
                    setState(() {
                      schedulingFrequency = v ?? 'Daily';
                      schedulingWeeklyDay = 1;
                      schedulingMonthlyDate = 1;
                    });
                  },
                  decoration: _inputDecoration(),
                ),

                // These conditional blocks will now show/hide correctly
                if (schedulingFrequency == 'Weekly' || schedulingFrequency == 'Fortnightly') ...[
                  const SizedBox(height: 12),
                  const Text('Select Day of Week', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    value: schedulingWeeklyDay,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Monday')),
                      DropdownMenuItem(value: 2, child: Text('Tuesday')),
                      DropdownMenuItem(value: 3, child: Text('Wednesday')),
                      DropdownMenuItem(value: 4, child: Text('Thursday')),
                      DropdownMenuItem(value: 5, child: Text('Friday')),
                      DropdownMenuItem(value: 6, child: Text('Saturday')),
                      DropdownMenuItem(value: 7, child: Text('Sunday')),
                    ],
                    onChanged: (v) => setState(() => schedulingWeeklyDay = v ?? 1),
                    decoration: _inputDecoration(),
                  ),
                ],
                if (schedulingFrequency == 'Monthly') ...[
                  const SizedBox(height: 12),
                  const Text('Enter Date of Month (1-31)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _schedulingMonthlyDateCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration(),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 31) return 'Enter 1-31';
                      return null;
                    },
                    onChanged: (v) => schedulingMonthlyDate = int.tryParse(v) ?? 1,
                  ),
                ],

                const SizedBox(height: 16),
                // Modification now initiated externally from Program page; this form is for adding new programs.
                if (originalProgramType != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8),
                    child: Row(
                      children: [
                       const Icon(Icons.edit, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Modifying program: ' + (originalProgramType?.displayName ?? ''),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              // Cancel modification state and navigate back from scheduling page
                              originalProgramType = null;
                              schedulingProgramType = null;
                              schedulingCount = null;
                              schedulingTimeSlot = '';
                              schedulingDuration = null;
                              // Navigate back to previous view if current is scheduleCourse
                              if (currentView == 'scheduling' && viewHistory.length > 1) { // viewHistory check slightly different here as 'scheduleCourse' isn't used
                               viewHistory.removeLast();
                               currentView = viewHistory.last;
                              } else {
                                // Default back behavior 
                               Navigator.pop(context);
                              }
                            });
                          },
                          child: const Text('Cancel'),
                        )
                      ],
                    ),
                  ),
                ],
                const Text('Program Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                DropdownButtonFormField<ProgramType>(
                  value: schedulingProgramType,
                  items: ProgramType.values.map((type) => 
                    DropdownMenuItem(value: type, child: Text(type.displayName))).toList(),
                  onChanged: (v) => setState(() => schedulingProgramType = v),
                  validator: (v) => v == null ? 'Required' : null,
                  decoration: _inputDecoration(),
                ),

                const SizedBox(height: 16),
                const Text('Duration', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                DropdownButtonFormField<SessionDuration>(
                  value: schedulingDuration,
                  items: SessionDuration.values.map((duration) => 
                    DropdownMenuItem(value: duration, child: Text(duration.displayName))).toList(),
                  onChanged: (v) {
                    setState(() {
                      schedulingDuration = v;
                      schedulingTimeSlot = ''; // Reset time slot when duration changes
                      _generateTimeSlots(duration: v!); // Regenerate time slots based on new duration
                    });
                  },
                  validator: (v) => v == null ? 'Required' : null,
                  decoration: _inputDecoration(),
                ),

                const SizedBox(height: 16),
                const Text('Time Slot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: timeSlots.contains(schedulingTimeSlot) ? schedulingTimeSlot : null,
                  items: timeSlots.toSet().map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => schedulingTimeSlot = v ?? ''),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  decoration: _inputDecoration(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_schedulingFormKey.currentState!.validate()) {
                      final generated = _generateSchedule(
                        count: schedulingCount!,
                        startDate: schedulingStartDate!,
                        frequency: schedulingFrequency,
                        timeSlot: schedulingTimeSlot,
                        weeklyDay: schedulingWeeklyDay,
                        monthlyDate: schedulingMonthlyDate,
                      );
                      final clashes = _checkForClashes(generated, sessions);
                      setState(() {
                        newSchedule = generated;
                        clashTempIds = clashes;
                        viewHistory.add('confirmation');
                        currentView = 'confirmation';
                      });
                    }
                  },
                  child: const Text('Review Schedule'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationView(List<Client> clients, List<Session> sessions) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ... (The top part of the confirmation view is the same)
            
            // Header
             Row(
               children: [
                 IconButton(
                   icon: const Icon(Icons.arrow_back),
                   onPressed: () {
                     setState(() {
                        if (viewHistory.length > 1) {
                           viewHistory.removeLast();
                           currentView = viewHistory.last;
                        } else {
                           currentView = 'scheduling';
                        }
                     });
                   },
                 ),
                 const Text('Confirm Draft', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               ],
             ),

            Expanded(
              child: ListView.builder(
                itemCount: newSchedule.length,
                itemBuilder: (context, index) {
                  final item = newSchedule[index];
                  final bool isClashing = clashTempIds.contains(item['tempId']);
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isClashing ? const Color(0xFFFEE2E2) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isClashing ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB)),
                      boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.05))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 8),
                        Text('${item['date']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF111827))),
                        const Spacer(),
                        const Icon(Icons.access_time, size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text('${item['time']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  // Only show destructive confirmation when modifying an existing program
                  if (modifyingClient != null && originalProgramType != null) {
                    final bool? shouldProceed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Schedule Change'),
                        content: const Text('This will delete all non-completed sessions of this program and replace them. Are you sure?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Confirm & Replace'),
                          ),
                        ],
                      ),
                    );
                    if (shouldProceed != true) return;
                  }

                  setState(() => _isSaving = true);

                  try {
                    await _confirmSchedule(clients, sessions);
                    // This part only runs if the save is successful
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                        _resetSchedulingForm();
                        modifyingClient = null;
                        viewHistory = ['scheduling']; // Defaulting to simple reset here, logic might differ if not in dashboard
                        currentView = 'scheduling';
                        
                        // If pushed from somewhere else (not dashboard), pop.
                        if (widget.preSelectedClient != null || widget.initialProgram != null) {
                           Navigator.pop(context);
                        }
                      });
                    }
                  } catch (e) {
                    // This part runs if there was an error (like a duplicate email)
                    if (mounted) {
                      setState(() {
                        _isSaving = false;
                        // Explicitly ensure we stay on the confirmation page
                      });
                      final msg = e.toString().replaceAll('Exception: ', '');
                      // Suppress email-related snackbar if we're clearly in existing-client flow
                      final isExistingFlow = modifyingClient != null;
                      final isEmailRequiredMsg = msg.toLowerCase().contains('email address is required');
                      if (isExistingFlow && isEmailRequiredMsg) {
                        // Silently ignore: existing client should not need email re-entry
                      } else {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.error_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    msg,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4), // Shorter display
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            action: SnackBarAction(
                              label: 'Edit',
                              textColor: Colors.white,
                              onPressed: () {
                                setState(() {
                                  if (viewHistory.length > 1) {
                                    viewHistory.removeLast();
                                    currentView = viewHistory.last;
                                  } else {
                                    currentView = 'scheduling';
                                  }
                                });
                              },
                            ),
                          ),
                        );
                      }
                    }
                  }
                },
                child: _isSaving
                    ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Confirm Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Logic Helpers
  
  List<Map<String, dynamic>> _generateSchedule({
    required int count,
    required DateTime startDate,
    required String frequency,
    required String timeSlot,
    required int weeklyDay,
    required int monthlyDate,
  }) {
    List<Map<String, dynamic>> sessions = [];
    DateTime cursor = startDate;

    if (frequency == 'Weekly' || frequency == 'Fortnightly') {
       while (cursor.weekday != weeklyDay) {
          cursor = cursor.add(const Duration(days: 1));
       }
    } else if (frequency == 'Monthly') {
       if (cursor.day > monthlyDate) {
          cursor = DateTime(cursor.year, cursor.month + 1, monthlyDate);
       } else {
          try {
             cursor = DateTime(cursor.year, cursor.month, monthlyDate);
          } catch (_) {
             // Handle invalid dates?
          }
       }
       // Ensure not in past if strict? Snippet didn't force it.
    }

    for (int i = 0; i < count; i++) {
        final Map<String, dynamic> s = {
            'tempId': '${cursor.millisecondsSinceEpoch}_$i',
            'clientId': modifyingClient!.id,
            'status': 'Upcoming',
            'time': timeSlot,
            'date': AppDateUtils.dateToStr(cursor),
            'programType': schedulingProgramType?.name,
            'duration': schedulingDuration?.index, // Save index or name? Model uses enum/index often
        };
        sessions.add(s);
        
        if (frequency == 'Daily') {
           cursor = cursor.add(const Duration(days: 1));
        } else if (frequency == 'Weekly') {
           cursor = cursor.add(const Duration(days: 7));
        } else if (frequency == 'Fortnightly') {
           cursor = cursor.add(const Duration(days: 14));
        } else if (frequency == 'Monthly') {
           int nextM = cursor.month + 1;
           int nextY = cursor.year;
           if (nextM > 12) { nextM = 1; nextY++; }
           cursor = DateTime(nextY, nextM, monthlyDate);
        } else if (frequency == 'Once only') {
           break; // Only 1
        }
    }
    return sessions;
  }
  
  Set<String> _checkForClashes(List<Map<String, dynamic>> newS, List<Session> existing) {
     Set<String> clashes = {};
     for (var n in newS) {
        // Logic: if any existing session matches date & time overlap
        final nTime = AppDateUtils.parseTimeRange(n['time']);
        for (var e in existing) {
            // IGNORE SELF-CLASH: If modifying, ignore Upcoming sessions for this client/program
            // Use originalProgramType if set, otherwise fallback to schedulingProgramType (though original is safer for modification)
            final targetProgramType = originalProgramType?.name ?? schedulingProgramType?.name;
            
            if (modifyingClient != null && 
                e.clientId == modifyingClient!.id && 
                e.programType?.name == targetProgramType && 
                e.status == 'Upcoming') {
                continue;
            }

           if (e.date == n['date']) {
               final eTime = AppDateUtils.parseTimeRange(e.time);
               if (nTime['start']! < eTime['end']! && nTime['end']! > eTime['start']!) {
                  clashes.add(n['tempId']);
                  break;
               }
           }
        }
     }
     return clashes;
  }
  
  Future<void> _confirmSchedule(List<Client> clients, List<Session> sessions) async {
     final batch = firestore.FirebaseFirestore.instance.batch();
     final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
     
     // 1. Prepare Program Info
     final programInfo = {
       'programType': schedulingProgramType?.name,
       'count': schedulingCount,
       'startDate': AppDateUtils.dateToStr(schedulingStartDate!),
       'frequency': schedulingFrequency,
       'timeSlot': schedulingTimeSlot,
       'duration': schedulingDuration?.name,
       'dayOfWeek': schedulingWeeklyDay, // FIXED: Matches legacy 'dayOfWeek'
       'dateOfMonth': schedulingMonthlyDate, // FIXED: Matches legacy 'dateOfMonth'
       'createdAt': DateTime.now().toUtc().toIso8601String(),
       'active': true,
       'version': 1,
     };

     String enrollmentId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

     // 2. Update Client with Program (Add or Update)
     // 2. Update Client with Program
     if (modifyingClient != null) {
        // ... (existing update logic kept clean, assuming it is correct above this block)
        // Check if program exists
        final existingIndex = modifyingClient!.programs.indexWhere(
            (p) => p['programType'] == schedulingProgramType?.name);
        
        // Inject ID into programInfo
        if (existingIndex >= 0) {
           // Preserve existing ID if available
           enrollmentId = modifyingClient!.programs[existingIndex]['programEnrollmentId'] ?? enrollmentId;
        }
        programInfo['programEnrollmentId'] = enrollmentId;

        if (existingIndex >= 0) {
           modifyingClient!.updateProgram(existingIndex, programInfo);
        } else {
           modifyingClient!.addProgram(programInfo);
        }
        
        final clientRef = firestore.FirebaseFirestore.instance
           .collection('users').doc(userId).collection('clients').doc(modifyingClient!.id.toString());
        
        batch.set(clientRef, {
           'programs': modifyingClient!.programs
        }, firestore.SetOptions(merge: true));
     }

     final sessionsCollection = firestore.FirebaseFirestore.instance
         .collection('users').doc(userId).collection('sessions');

     // 3. Delete Old Upcoming Sessions (Direct DB Query for Robustness)
     // Use originalProgramType if available (Modifying), else current type (Replacing draft/same type)
     final targetLogicProgramType = originalProgramType ?? schedulingProgramType;
     
     if (modifyingClient != null && targetLogicProgramType != null) {
        print('DEBUG: Starting Deletion Phase. Target Program: ${targetLogicProgramType.name}');
        
        final sessionsQuery = await sessionsCollection
            .where('clientId', isEqualTo: modifyingClient!.id)
            .where('programType', isEqualTo: targetLogicProgramType.name)
            .where('status', isEqualTo: 'Upcoming')
            .get();
        
        print('DEBUG: Found ${sessionsQuery.docs.length} upcoming sessions to delete in DB.');
        
        for (final doc in sessionsQuery.docs) {
           print('DEBUG: Deleting session ${doc.id} (${doc.data()['date']})');
           batch.delete(doc.reference);
        }
     }

     // 4. Save New Sessions & Schedule Notifications
     int baseNo = 0; // Reset or calculate if needed? 
     // If we want to continue numbering, we need the count of completed sessions.
     // We can query that too or trust the passed list for *completed* stats which usually don't change rapidly.
     if (modifyingClient != null && targetLogicProgramType != null) {
        final completedSessions = sessions.where((s) => 
            s.clientId == modifyingClient!.id && 
            s.programType?.name == targetLogicProgramType.name &&
            (s.status == 'Completed' || s.status == 'Cancelled')
        );
        baseNo = completedSessions.length;
     }

     final notificationService = NotificationService();
     // Ensure timezone is initialized (safe to call multiple times)
     tz.initializeTimeZones();
     await notificationService.init();

     for (int i = 0; i < newSchedule.length; i++) {
        final sMap = newSchedule[i];
        final docRef = sessionsCollection.doc();
        final int newSessionId = DateTime.now().millisecondsSinceEpoch + i;
        
        batch.set(docRef, {
           'id': newSessionId,
           'clientId': sMap['clientId'],
           'date': sMap['date'],
           'time': sMap['time'],
           'status': sMap['status'],
           'programType': sMap['programType'], 
           'duration': sMap['duration'] != null ? 
              SessionDuration.values[sMap['duration']].name : null,
           'sessionNo': baseNo + i + 1,
           'read': false, 
           'notifiedTwoHour': false,
           'notifiedFiveMin': false,
           'notifiedTwoHour': false,
           'notifiedFiveMin': false,
           'programEnrollmentId': enrollmentId, // Link session to program
        });

        // Schedule Notification
         // Notifications now handled via Repository -> Bloc stream.
      }

      print('DEBUG: Committing batch...');
      try {
        await batch.commit();
        print('DEBUG: Batch commit SUCCESS');
      } catch (e) {
        print('DEBUG: Batch commit FAILED: $e');
        rethrow; // Propagate error to update UI state
      }
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFd1d5db)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
