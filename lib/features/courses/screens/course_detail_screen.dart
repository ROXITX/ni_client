import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../sessions/bloc/sessions_bloc.dart';
import '../../scheduling/screens/scheduling_screen.dart';
import '../../../../shared/services/notification_service.dart';
import '../../../core/utils/date_utils.dart'; // Ensure correct path
import '../../../../shared/widgets/session_card.dart';
import '../../dashboard/widgets/dashboard_dialogs.dart'; // Required for showPostponeDialog etc

class CourseDetailScreen extends StatefulWidget {
  final Client client;
  const CourseDetailScreen({super.key, required this.client});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  // Logic from home_page.dart:
  // _buildCourseManagementDetailView switches between Cards and Sessions
  
  int? selectedCourseManagementProgram; // Index of selected program (nullable)
  
  @override
  Widget build(BuildContext context) {
    Client c = widget.client;

    return BlocBuilder<SessionsBloc, SessionsState>(
      builder: (context, state) {
        List<Session> sessions = [];
        if (state is SessionsLoaded) sessions = state.sessions;
        
        // Match home_page.dart _buildCourseManagementDetailView
        
        if (selectedCourseManagementProgram != null) {
          // Validate index
          if (selectedCourseManagementProgram! < c.programs.length) {
             return _buildProgramSessionsView(c, sessions);
          } else {
             // Reset if invalid (e.g. after deletion)
             selectedCourseManagementProgram = null;
          }
        }
        
        return _buildProgramCardsView(c, sessions);
      },
    );
  }

  // Copied from home_page.dart _buildProgramCardsView
  Widget _buildProgramCardsView(Client client, List<Session> sessions) {
    return Scaffold(
      appBar: AppBar(title: const Text('Course Management')),
       backgroundColor: const Color(0xFFF9FAFB),
       body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Client header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        '${client.firstName.isNotEmpty ? client.firstName[0] : ''}${client.lastName.isNotEmpty ? client.lastName[0] : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${client.firstName} ${client.lastName}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          client.phone,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          client.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Programs list
            Expanded(
              child: client.programs.isEmpty
                  ? Center(child: Text("No programs registered"))
                  : ListView.builder(
                      itemCount: client.programs.length,
                      itemBuilder: (context, index) {
                        final program = client.programs[index];
                        final displayName = _getProgramDisplayName(program);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                selectedCourseManagementProgram = index;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                     width: 50, height: 50,
                                     decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                                        borderRadius: BorderRadius.circular(25),
                                     ),
                                     child: const Icon(Icons.school, color: Colors.white),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          Text(displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                          if (program['frequency'] != null || program['count'] != null)
                                            Text('${program['count'] ?? 'N/A'} sessions | ${program['frequency'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Copied from home_page.dart _buildProgramSessionsView
  Widget _buildProgramSessionsView(Client client, List<Session> sessions) {
    if (selectedCourseManagementProgram == null) return const SizedBox.shrink();
    
    final programIndex = selectedCourseManagementProgram!;
    final program = client.programs[programIndex];
    final programType = program['programType'];
    final displayName = _getProgramDisplayName(program);

    // Filter sessions
    final clientSessions = sessions.where((s) => s.clientId == client.id).toList();
    List<Session> programSessions = [];
    
    if (programType != null && programType.toString().isNotEmpty) {
       programSessions = clientSessions.where((s) => s.programType?.name == programType.toString()).toList();
       if (programSessions.isEmpty && client.programs.length == 1) {
           programSessions = clientSessions.where((s) => s.programType == null).toList();
       }
    } else {
       programSessions = clientSessions.where((s) => s.programType == null).toList();
    }
    
    // Sort
    programSessions.sort((a, b) => a.date.compareTo(b.date));

    // Split
    final upcoming = programSessions.where((s) => _getRealTimeSessionStatus(s) == 'Upcoming').toList();
    final past = programSessions.where((s) => ['Completed', 'Cancelled', 'Pending'].contains(_getRealTimeSessionStatus(s))).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(displayName),
          leading: IconButton(
             icon: const Icon(Icons.arrow_back),
             onPressed: () => setState(() => selectedCourseManagementProgram = null),
          ),
        ),
        body: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
          children: [
             // Modify / Cancel Buttons
             Row(
                children: [
                   Expanded(
                     child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Modify Program'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(
                             builder: (_) => SchedulingScreen(preSelectedClient: client, initialProgram: program)
                           ));
                        },
                     )
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel All'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                        onPressed: () => _confirmCancelProgram(client, programIndex, displayName),
                     )
                   ),
                ],
             ),
             const SizedBox(height: 16),
             Container(
               decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
               child: TabBar(
                 labelColor: Colors.black,
                 unselectedLabelColor: Colors.grey,
                 tabs: [
                    Tab(text: 'Upcoming (${upcoming.length})'),
                    Tab(text: 'Past (${past.length})'),
                 ],
               ),
             ),
             const SizedBox(height: 16),
             Expanded(
               child: TabBarView(
                 children: [
                   _buildSessionList(upcoming),
                   _buildSessionList(past),
                 ],
               ),
             ),
          ],
         ),
        ),
      ),
    );
  }

  Widget _buildSessionList(List<Session> list) {
    if (list.isEmpty) return const Center(child: Text("No sessions found"));
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
         final s = list[index];
         // Logic to prepare details for SessionCard (similar to MonthlySidebar)
         final status = _getRealTimeSessionStatus(s);
         final details = {
            'color': _getStatusColor(status),
            'icon': _getStatusIcon(status),
         };

         return SessionCard(
           session: s,
           client: widget.client,
           details: details,
           // IMPORTANT: We pass the action handler to enable Postpone (with clash detection) and status updates
           onActionSelected: (session, action) => _handleCourseSessionAction(session, action, list),
         );
      },
    );
  }
  
  // Handler for session actions (Postpone, Completed, etc.)
  Future<void> _handleCourseSessionAction(Session session, String action, List<Session> contextSessions) async {
       if (action == 'Upcoming' || action == 'Pending') {
           // Status rollback usually not exposed in menu, but handled if needed
           return;
       }
       
       if (!mounted) return;
       
       // Use ALL sessions from the BLoC state preferably, but 'contextSessions' (program specific) 
       // might be too narrow for clash detection. We should access the BLOC for full list for clash detection.
       List<Session> allSessionsForClashCallback = [];
       final state = context.read<SessionsBloc>().state;
       if (state is SessionsLoaded) {
           allSessionsForClashCallback = state.sessions;
       } else {
           allSessionsForClashCallback = contextSessions;
       }
       
       if (action == 'Completed' || action == 'Cancelled') {
           // Assuming showFeedbackDialog is imported from dashboard_dialogs.dart
           // We might need to import it if not already valid in this file scope.
           // It IS imported as per import analysis.
           // Note: The imports in this file include 'dashboard_dialogs.dart' implicitly or we might need to add it?
           // Checked file content earlier: it imports session_card.dart. 
           // We need to ensure dashboard_dialogs is accessible or we rely on session_card to export it? 
           // session_card imports it. But we need to call it here?
           // No, we are calling it here inside this method.
           // Wait, this file imports 'session_card.dart' but maybe not 'dashboard_dialogs.dart'.
           // I will check imports. If missing, I'll need to add it.
           // For now, let's assume I can add the import or it's available.
           
           // Actually, best practice: Let's use the same names as in MainScaffold
           showFeedbackDialog(context, session: session, mode: action, clients: [widget.client]);
       } else if (action == 'Postpone') {
           showPostponeDialog(context, session: session, allSessions: allSessionsForClashCallback, clients: [widget.client]);
       } else if (action == 'Edit/View Details') {
           showFeedbackDialog(context, session: session, mode: 'View', clients: [widget.client]);
       }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Upcoming': return Icons.calendar_today_outlined;
      case 'Pending': return Icons.hourglass_top_rounded;
      case 'Completed': return Icons.check_circle_outline;
      case 'Cancelled': return Icons.cancel_outlined;
      default: return Icons.event;
    }
  }

  Future<void> _confirmCancelProgram(Client client, int index, String name) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text('Cancel Program'),
           content: Text('Are you sure you want to cancel "$name"?\nThis will delete future sessions and remove the program.'),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')), 
           ],
        ),
      );

      if (confirmed == true) {
         await _cancelProgramLogic(client, index);
      }
  }

  Future<void> _cancelProgramLogic(Client client, int index) async {
     try {
       final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
       final program = client.programs[index];
       final pType = program['programType'];
       final enrollmentId = program['programEnrollmentId']; // Use ID if available
       
       // Delete sessions provided by Firestore
       final batch = FirebaseFirestore.instance.batch();
       
       // Query user's sessions
       final query = await FirebaseFirestore.instance.collection('users').doc(userId).collection('sessions')
          .where('clientId', isEqualTo: client.id)
          .get();
          
       for (var doc in query.docs) {
          final s = Session.fromJson(doc.data()); // Assuming FromMap exists or manual
          final sPType = s.programType?.name;
          final sEnrollmentId = s.programEnrollmentId;

          bool belongs = false;

          // 1. Strict ID Match (New Data)
          if (enrollmentId != null && sEnrollmentId != null) {
              if (sEnrollmentId == enrollmentId) belongs = true;
          } 
          // 2. Fallback Type Match (Legacy Data)
          else {
              belongs = (pType != null && sPType == pType) || (pType == null && sPType == null);
          }

          if (belongs && s.status != 'Completed' && s.status != 'Cancelled') {
              batch.delete(doc.reference);
              // Cancel notification
              // try { NotificationService().cancelSessionNotifications(s.id); } catch(_) {} // Legacy removed
          }
       }
       
       // Update Client
       final updatedPrograms = List<Map<String, dynamic>>.from(client.programs);
       updatedPrograms.removeAt(index);
       batch.update(FirebaseFirestore.instance.collection('users').doc(userId).collection('clients').doc(client.id.toString()), {
          'programs': updatedPrograms,
       });
       
       await batch.commit();

       // Force BLoC refresh? It listens to streams, so it should auto-update.
       // But we need to update the Client in ClientsBloc? 
       // ClientsBloc also listens to stream? Yes.
       
       setState(() {
          selectedCourseManagementProgram = null; 
       });
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Program cancelled.')));

     } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
     }
  }
  
  String _getProgramDisplayName(Map<String, dynamic> p) {
     String rawName = p['programType'] ?? 'Program';
     try {
       rawName = ProgramTypeExtension.fromString(rawName).displayName;
     } catch (_) {
        // Fallback for custom strings
        if (rawName.isNotEmpty) {
          final RegExp exp = RegExp(r'(?<=[a-z])[A-Z]');
          rawName = rawName.replaceAllMapped(exp, (Match m) => ' ${m.group(0)}');
          if (rawName.isNotEmpty) rawName = rawName[0].toUpperCase() + rawName.substring(1);
        }
     }
     return '$rawName - ${p['frequency'] ?? ''}';
  }

  String _getRealTimeSessionStatus(Session s) {
     return AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed': return const Color(0xFF16A34A); // Green-600
      case 'Cancelled': return const Color(0xFFDC2626); // Red-600
      case 'Upcoming': return const Color(0xFF2563EB); // Blue-600
      case 'Pending': return const Color(0xFFF97316); // Orange-500
      default: return Colors.grey;
    }
  }
}
