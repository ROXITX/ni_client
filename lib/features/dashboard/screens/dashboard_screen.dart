import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/dashboard_bloc.dart';
import '../widgets/dashboard_speedometer_painter.dart';
import '../widgets/collapsible_session_group.dart';
import '../widgets/collapsible_payment_group.dart'; // NEW
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ni_client/models/client.dart';
import 'package:ni_client/models/session.dart';
import 'package:ni_client/models/payment_entry.dart'; // NEW

import '../widgets/dashboard_dialogs.dart';
import '../../payments/utils/payment_dialog_helpers.dart'; // NEW

class DashboardScreen extends StatefulWidget {
  final String username;

  const DashboardScreen({super.key, required this.username});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _expandedTab = 'sessions';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getDisplayName(String email) {
    if (email.isEmpty || !email.contains('@')) {
      return email.isEmpty ? 'User' : email;
    }
    return email.split('@')[0];
  }

  @override
  Widget build(BuildContext context) {
    // context.read<DashboardBloc>().add(DashboardSubscriptionRequested()); // Handled by MainScaffold

    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is DashboardError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        if (state is DashboardLoaded) {
          final total = state.totalToday;
          final completed = state.completions;
          final byStatus = state.sessionsByStatus;
          final statusOrder = ['Upcoming', 'Pending', 'Completed', 'Cancelled'];
          final displayName = _getDisplayName(widget.username);

          return Container(
            color: const Color(0xFFF9FAFB),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Hi, ${displayName.toUpperCase()}!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                if (total > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 6,
                              color: Colors.black.withOpacity(0.08))
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Today's Progress",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4B5563))),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 192,
                            height: 96,
                            child: CustomPaint(
                              painter: DashboardSpeedometerPainter(
                                ratio: (total == 0 ? 0.0 : completed / total)
                                    .clamp(0.0, 1.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$completed',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827))),
                              const Text(' / ',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B7280))),
                              Text('$total',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827))),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                if (total == 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(24),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                         BoxShadow(blurRadius: 6, color: Colors.black.withOpacity(0.08))
                      ],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.local_florist, size: 64, color: Colors.pinkAccent),
                        SizedBox(height: 8),
                        Text("No Classes Today!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                        SizedBox(height: 4),
                        Text("Enjoy your free time.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280))),
                      ]
                    )
                  ),
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _expandedTab = _expandedTab == 'sessions' ? '' : 'sessions'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              const Text("Today's Sessions",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827))),
                              const Spacer(),
                              Icon(_expandedTab == 'sessions' ? Icons.expand_less : Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                      if (_expandedTab == 'sessions') ...[
                        if (total == 0)
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(24),
                            child: const Column(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: Color(0xFF9CA3AF)),
                                SizedBox(height: 8),
                                Text('All Clear!',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827))),
                                SizedBox(height: 4),
                                Text(
                                    'No sessions scheduled for today. Time for a coffee break!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        else ...[
                          for (var status in statusOrder)
                            if (byStatus[status]?.isNotEmpty ?? false)
                              CollapsibleSessionGroup(
                                status: status,
                                sessions: byStatus[status]!,
                                clients: state.clients,
                                statusDetails: const {
                                   'Upcoming': {'color': Color(0xFF3B82F6), 'icon': Icons.calendar_today_outlined, 'actions': ['Cancel', 'Mark Completed']},
                                   'Pending': {'color': Color(0xFFF59E0B), 'icon': Icons.hourglass_top_rounded, 'actions': ['Cancel', 'Mark Completed']},
                                   'Completed': {'color': Color(0xFF22C55E), 'icon': Icons.check_circle_outline, 'actions': ['View Details']},
                                   'Cancelled': {'color': Color(0xFFEF4444), 'icon': Icons.cancel_outlined, 'actions': ['View Reason']},
                                },
                                getRealTimeStatus: (s) => s.status,
                                onActionSelected: (session, action) => _handleDashboardAction(context, session, action, state.clients, state.sessions),
                              ),
                        ],
                      ]
                    ]
                  )
                ),
                Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _expandedTab = _expandedTab == 'payments' ? '' : 'payments'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              const Text("Today's Payments",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827))),
                              const Spacer(),
                              Icon(_expandedTab == 'payments' ? Icons.expand_less : Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                      if (_expandedTab == 'payments') ...[
                        if (state.todaysPayments.isEmpty)
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(24),
                            child: const Column(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: Color(0xFF9CA3AF)),
                                SizedBox(height: 8),
                                Text('All Settled!',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827))),
                                SizedBox(height: 4),
                                Text(
                                    'No pending payments due today.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF6B7280))),
                              ],
                            ),
                          )
                        else ...[
                          for (var status in ['Overdue', 'Due Today', 'Paid'])
                            if (state.paymentsByStatus[status]?.isNotEmpty ?? false)
                              CollapsiblePaymentGroup(
                                status: status,
                                payments: state.paymentsByStatus[status]!,
                                clients: state.clients,
                                statusDetails: const {
                                   'Overdue': {'color': Color(0xFFEF4444), 'icon': Icons.warning_amber_rounded, 'actions': ['Mark Paid', 'Postpone']},
                                   'Due Today': {'color': Color(0xFFF59E0B), 'icon': Icons.payment_outlined, 'actions': ['Mark Paid', 'Postpone']},
                                   'Paid': {'color': Color(0xFF22C55E), 'icon': Icons.check_circle_outline, 'actions': ['Revert']},
                                },
                                onActionSelected: (payment, action) => _handlePaymentAction(context, payment, action, state.allPendingPayments),
                              ),
                        ],
                      ]
                    ]
                  )
                ),
              ],
            ),
          );
        }

        return Container();
      },
    );
  }

  Future<void> _handleDashboardAction(BuildContext context, Session session, String action, List<Client> clients, List<Session> allSessions) async {
       if (action == 'Upcoming' || action == 'Pending') {
           final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
           final querySnapshot = await FirebaseFirestore.instance
               .collection('users').doc(userId).collection('sessions')
               .where('id', isEqualTo: session.id)
               .limit(1)
               .get();

           if (querySnapshot.docs.isNotEmpty) {
             await querySnapshot.docs.first.reference.update({'status': action});
           } else {
              debugPrint('Error: Session not found for id ${session.id}');
           }
           return;
       }
       
       if (!context.mounted) return;
       
       if (action == 'Completed' || action == 'Cancelled') {
           showFeedbackDialog(context, session: session, mode: action, clients: clients);
       } else if (action == 'Postpone') {
           showPostponeDialog(context, session: session, allSessions: allSessions, clients: clients);
       } else if (action == 'Edit/View Details') {
           showFeedbackDialog(context, session: session, mode: 'View', clients: clients);
       }
  }

  Future<void> _handlePaymentAction(BuildContext context, PaymentEntry payment, String action, List<PaymentEntry> allPending) async {
       final paymentDue = DateTime.tryParse(payment.dueDate) ?? DateTime.now();
       bool isLast = !allPending.any((p) {
           if (p.planId != payment.planId) return false;
           if (p.id == payment.id) return false;
           final d = DateTime.tryParse(p.dueDate);
           if (d == null) return false;
           return d.isAfter(paymentDue); 
       });

       if (action == 'Mark Paid') {
           PaymentDialogHelpers.handlePay(context, payment, isLast);
       } else if (action == 'Revert') {
           PaymentDialogHelpers.handleRevert(context, payment);
       } else if (action == 'Postpone') {
           PaymentDialogHelpers.handlePostpone(context, payment, isLast);
       }
  }
}
