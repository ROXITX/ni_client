import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../shared/services/notification_service.dart';
import '../../../core/utils/date_utils.dart'; // Ensure this exists and has parseTimeRange

// Helper to show Feedback/Edit/Cancel Dialog
Future<void> showFeedbackDialog(BuildContext context, {
  required Session session, 
  required String mode, // 'View', 'Edit', 'Completed', 'Cancelled'
  required List<Client> clients, 
}) async {
  
  // Local state variables for the dialog
  int tempRating = session.rating ?? 0;
  String tempComments = session.comments ?? '';
  String tempStatus = session.status;

  String title = 'Session Feedback';
  String submitText = 'Submit';
  bool isViewMode = mode == 'View';
  bool isEditMode = mode == 'Edit';

  if (mode == 'Cancelled') {
    title = 'Cancellation Reason';
  } else if (isViewMode) {
    title = 'Session Details';
    submitText = 'Edit';
  } else if (isEditMode) {
    title = 'Edit Details';
    submitText = 'Save Changes';
  }

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isEditMode)
                DropdownButtonFormField<String>(
                  value: tempStatus,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: ['Upcoming', 'Pending', 'Completed', 'Cancelled']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => tempStatus = v ?? tempStatus),
                ),
              if (mode == 'Completed' || (isEditMode && tempStatus == 'Completed') || (isViewMode && session.status == 'Completed'))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text('Rating', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: List.generate(5, (i) {
                        final idx = i + 1;
                        return IconButton(
                          iconSize: 24, padding: EdgeInsets.zero,
                          icon: Icon(idx <= tempRating ? Icons.star : Icons.star_border, color: const Color(0xFFF59E0B)),
                          onPressed: (isViewMode) ? null : () => setDialogState(() => tempRating = idx),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              
              const SizedBox(height: 8),
              // Comments Field
              TextField(
                controller: TextEditingController(text: tempComments)..selection = TextSelection.fromPosition(TextPosition(offset: tempComments.length)),
                readOnly: isViewMode,
                onChanged: (v) => tempComments = v,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Comments', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (isViewMode) {
                if (!context.mounted) return;
                Navigator.pop(ctx);
                showFeedbackDialog(context, session: session, mode: 'Edit', clients: clients);
                return;
              }

              Navigator.pop(ctx);
              if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saving changes...")));
              }

              final newStatus = isEditMode ? tempStatus : mode;
              
              try {
                // Direct Firestore Update (Hybrid: DocID or Legacy Field)
                final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
                final collectionRef = FirebaseFirestore.instance
                    .collection('users').doc(userId).collection('sessions');

                if (session.firestoreDocId != null) {
                     await collectionRef.doc(session.firestoreDocId).update({
                        'status': newStatus,
                        'comments': tempComments,
                        'rating': (newStatus == 'Completed') ? tempRating : null,
                     });
                } else {
                    // Legacy: Find by 'id' field
                    final querySnapshot = await collectionRef
                        .where('id', isEqualTo: session.id)
                        .limit(1)
                        .get();

                    if (querySnapshot.docs.isNotEmpty) {
                      await querySnapshot.docs.first.reference.update({
                        'status': newStatus,
                        'comments': tempComments,
                        'rating': (newStatus == 'Completed') ? tempRating : null,
                      });
                    } else {
                      debugPrint('Error: Session document not found for id ${session.id}');
                      if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Session not found.")));
                      }
                    }
                }
              } catch (e) {
                debugPrint('Error updating session: $e');
              }
              
              // Notification scheduling omitted for simplicity, but stream will update UI
            },
            child: Text(submitText),
          )
        ],
      ),
    ),
  );
}

// Helper to show Postpone Dialog
Future<void> showPostponeDialog(BuildContext context, {
  required Session session, 
  required List<Session> allSessions,
  required List<Client> clients,
}) async {
  
  DateTime? newDate = DateTime.tryParse(session.date);
  String? newSlot = session.time;
  
  // Logic to determine duration from time slot string (Incorporating User Logic)
  int durationMinutes = 60; // Default
  if (session.duration != null) {
      durationMinutes = (session.duration!.hours * 60).toInt();
  } else {
       try {
         final parsed = AppDateUtils.parseTimeRange(session.time);
         final start = parsed['start'] ?? 0;
         final end = parsed['end'] ?? 0;
         int diff = end - start;
         if (diff <= 0) diff += 24 * 60;
         
         // Heuristic from User Snippet
         if ((diff - 30).abs() <= 5) durationMinutes = 30;
         else if ((diff - 60).abs() <= 5) durationMinutes = 60;
         else if ((diff - 120).abs() <= 5) durationMinutes = 120;
         else if ((diff - 180).abs() <= 5) durationMinutes = 180;
         else if (diff >= 8 * 60) durationMinutes = 480; // Whole Day
         else durationMinutes = 60;
       } catch (_) {}
  }
  
  // Generate slots
  List<String> postponeSlots = _generateSlots(durationMinutes);
  if (newSlot != null && !postponeSlots.contains(newSlot)) {
      postponeSlots.insert(0, newSlot);
  }

  final now = DateTime.now();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Postpone Session'),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                'Reschedule "${session.courseName ?? session.programType?.displayName ?? 'Session'}"',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                onPressed: () async {
                  final today = DateTime(now.year, now.month, now.day);
                  final initial = (newDate != null && newDate!.isBefore(today)) ? today : (newDate ?? today);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: today, // User fix: Allow start of today
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => newDate = picked);
                  }
                },
                label: Text(newDate == null ? 'Pick date' : intl.DateFormat.yMMMd().format(newDate!)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: (newSlot != null && postponeSlots.contains(newSlot)) ? newSlot : null,
                items: postponeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setDialogState(() { newSlot = v; }),
                decoration: const InputDecoration(
                    labelText: 'Select New Time',
                    border: OutlineInputBorder()
                ),
              )
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            if (newDate != null && newSlot != null) {
               
               // --- CLASH DETECTION START ---
               final newDateStr = AppDateUtils.dateToStr(newDate!);
               
               // Check if any OTHER session (not this one) overlaps
               // We need a helper to check overlap. For now, simple strict equality check on time slot
               // or start time overlap if feasible. 
               // Legacy used strict slot checking or sophisticated overlap.
               // We'll use start-time based overlap checking using data_utils.
               
               bool hasClash = false;
               try {
                   final newRange = AppDateUtils.parseTimeRange(newSlot!);
                   final newStart = newRange['start']!;
                   final newEnd = newRange['end']!;
                   
                   for (final other in allSessions) {
                       if (other.id == session.id) continue; // Skip self
                       if (other.status == 'Cancelled' || other.status == 'Completed') continue; // Ignore finished
                       
                       // Normalize Date Comparison
                       try {
                           final otherDate = AppDateUtils.parseSessionDate(other.date);
                           if (otherDate.year != newDate!.year || otherDate.month != newDate!.month || otherDate.day != newDate!.day) {
                               continue;
                           }
                       } catch (_) {
                           // If date parsing fails, skip or check string equality fallback
                           if (other.date != newDateStr) continue;
                       }
                       
                       final otherRange = AppDateUtils.parseTimeRange(other.time);
                       final otherStart = otherRange['start']!;
                       final otherEnd = otherRange['end']!;
                       
                       // Overlap condition:
                       if (newStart < otherEnd && newEnd > otherStart) {
                           hasClash = true;
                           break;
                       }
                   }
               } catch (e) {
                   print('Clash detection error: $e');
               }

               if (hasClash) {
                   final proceed = await showDialog<bool>(
                     context: context,
                     builder: (ctx) => AlertDialog(
                       title: const Text('Scheduling Conflict'),
                       content: const Text('This new time clashes with another session. Would you like to schedule it anyway?'),
                       actions: [
                         TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Choose Different Time')),
                         ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm Anyway')),
                       ],
                     ),
                   );

                   if (proceed != true) {
                     return;
                   }
               }
               // --- CLASH DETECTION END ---

               Navigator.pop(ctx);
               
               try {
                   final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
                   final collectionRef = FirebaseFirestore.instance
                       .collection('users').doc(userId).collection('sessions');
                       
                   if (session.firestoreDocId != null) {
                        await collectionRef.doc(session.firestoreDocId).update({
                               'date': newDateStr,
                               'time': newSlot,
                               'status': 'Upcoming',
                               'read': false,
                               'notifiedTwoHour': false,
                               'notifiedFiveMin': false,
                        });
                        if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session postponed successfully.")));
                        }
                        
                        // Refetch and Schedule Notifications (User Logic Integration)
                        try {
                           final updatedSnap = await collectionRef.get();
                           final updatedSessions = updatedSnap.docs.map((d) {
                               final s = Session.fromJson(d.data());
                               s.firestoreDocId = d.id;
                               return s;
                           }).toList();
                           
                           await _scheduleAllNotifications(clients, updatedSessions, force: true);
                        } catch (e) {
                           debugPrint('Error rescheduling notifications: $e');
                        }
                   } else {
                       // Legacy Fallback for sessions without captured Doc ID
                       final querySnapshot = await collectionRef.where('id', isEqualTo: session.id).get();
                       if (querySnapshot.docs.isNotEmpty) {
                            final batch = FirebaseFirestore.instance.batch();
                            for (var doc in querySnapshot.docs) {
                               batch.update(doc.reference, {
                                   'date': newDateStr,
                                   'time': newSlot,
                                   'status': 'Upcoming',
                                   'read': false,
                                   'notifiedTwoHour': false,
                                   'notifiedFiveMin': false,
                               });
                            }
                            await batch.commit();
                            if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session postponed successfully.")));
                            }
                       } else {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Session not found.")));
                       }
                   }
               } catch (e) {
                   debugPrint('Error postponing session: $e');
               }
            }
          },
          child: const Text('Confirm'),
        )
      ],
    ),
  );
}

List<String> _generateSlots(int durationMinutes) {
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
    return slots;
}

Future<void> _scheduleAllNotifications(List<Client> clients, List<Session> sessions, {bool force = false}) async {
  final service = NotificationService();
  await service.init();
  final now = DateTime.now();

  // Legacy loop removed. Notifications are centralized in DashboardBloc.
  // for (final session in sessions) { ... }
}
