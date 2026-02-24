import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/client.dart';
import '../../models/session.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/minute_updater.dart';
import '../../features/dashboard/widgets/dashboard_dialogs.dart';

class SessionCard extends StatelessWidget {
  final Session session;
  final Client client;
  final Map<String, dynamic> details;
  final bool isDetailed;
  final void Function(Session, String)? onActionSelected;
  final VoidCallback? onMenuOpen;
  final VoidCallback? onMenuClose;
  final String? displayStatus; // Override status text

  const SessionCard({
    required this.session,
    required this.client,
    required this.details,
    this.isDetailed = true,
    this.onActionSelected,
    this.onMenuOpen,
    this.onMenuClose,
    this.displayStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Listen to the global minute updater to refresh status in real-time
    return AnimatedBuilder(
      animation: MinuteUpdater(),
      builder: (context, child) {
        // Calculate the effective status for display
        final effectiveStatus = displayStatus ?? AppDateUtils.determineSessionStatus(
          session.status, 
          session.date, 
          session.time
        );
        
        return isDetailed 
            ? _buildDetailedCard(context, effectiveStatus) 
            : _buildSimpleCard(context, effectiveStatus);
      },
    );
  }

  Widget _buildDetailedCard(BuildContext context, String currentStatus) {
    // We need to fetch details based on the CALCULATED status, not the stored one
    // But since 'details' is passed in from parent (which might be stale), 
    // we should ideally re-fetch color/icon if we can, or rely on parent update via callback?
    // The parent (MonthlySidebar) actually recalculates 'details' before passing.
    // However, for Dashboard (legacy), it passes details based on stored status.
    // So we might need to locally determine color/icon if status changed.
    
    // Quick local map for status details if we override status
    final statusColor = _getStatusColor(currentStatus);
    final statusIcon = _getStatusIcon(currentStatus);

    return Card(
      elevation: 3.0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    currentStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
                    Text(
                      '${client.firstName} ${client.lastName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session No: ${session.sessionNo}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const SizedBox(height: 4),
                    if (session.courseName != null || session.programType != null)
                      Text(
                        'Program: ${session.courseName ?? session.programType!.displayName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    if (session.courseName != null || session.programType != null) const SizedBox(height: 4),
                    if (session.duration != null)
                      Text(
                        'Duration: ${session.duration!.displayName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    if (session.duration != null) const SizedBox(height: 4),
                    Text(
                      '${session.time} IST',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      intl.DateFormat(
                        'MMM d, yyyy',
                      ).format(DateTime.parse(session.date)),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF3B82F6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
              onOpened: () {
                onMenuOpen?.call();
              },
              onCanceled: () {
                onMenuClose?.call();
              },
              onSelected: (value) async {
                debugPrint('DEBUG: SessionCard popup menu selected: $value for session: ${session.id}, status: ${session.status}');
                
                // If a callback is provided, use it.
                if (onActionSelected != null) {
                  onActionSelected!(session, value);
                } else {
                  // Fallback: Handle actions internally using dashboard_dialogs
                  if (value == 'Postpone') {
                     showPostponeDialog(context, session: session, allSessions: [], clients: [client]);
                  } else if (value == 'Completed') {
                     showFeedbackDialog(context, session: session, mode: 'Completed', clients: [client]);
                  } else if (value == 'Cancelled') {
                     showFeedbackDialog(context, session: session, mode: 'Cancelled', clients: [client]);
                  } else if (value == 'Edit/View Details') {
                     showFeedbackDialog(context, session: session, mode: 'View', clients: [client]);
                  }
                }
                
                onMenuClose?.call();
              },
              itemBuilder: (context) {
                final bool isFinished =
                    session.status == 'Completed' ||
                    session.status == 'Cancelled';
                
                print('DEBUG: Building popup menu for session: ${session.id}, status: ${session.status}, isFinished: $isFinished');

                if (isFinished) {
                  // If the session is finished, only show this one option.
                  return [
                    const PopupMenuItem(
                      value: 'Edit/View Details',
                      child: Text('Edit/View Details'),
                    ),
                  ];
                } else {
                  // Otherwise, show the normal options.
                  return const [
                    PopupMenuItem(
                      value: 'Completed',
                      child: Text('Completed'),
                    ),
                    PopupMenuItem(
                      value: 'Cancelled',
                      child: Text('Cancelled'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'Postpone',
                      child: Text('Postpone'),
                    ),
                  ];
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard(BuildContext context, String currentStatus) {
    final Color statusColor = _getStatusColor(currentStatus);
    
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${client.firstName} ${client.lastName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const SizedBox(height: 2),
                  // Display Program Name: Prioritize courseName, fallback to programType
                  if (session.courseName != null || session.programType != null)
                      Text(
                        (session.courseName ?? session.programType!.displayName) + 
                        (session.duration != null ? ' • ${session.duration!.displayName}' : ''),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    
                  if ((session.courseName != null || session.programType != null) && session.duration != null) 
                     const SizedBox(height: 2), // Spacing handled above in concatenation mostly, but this checks line breaks logic.
                     // The original code had separate Text widgets or concatenation? 
                     // Original was: Text('${session.programType!.displayName} • ${session.duration!.displayName}'...)
                     // We should mimic that structure.
                  
                  if (session.courseName == null && session.programType == null && session.duration != null)
                     Text(
                        session.duration!.displayName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                     ),
                  Text(
                    '${session.time} IST',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentStatus,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Upcoming':
        return const Color(0xFF3B82F6);
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'Completed':
        return const Color(0xFF22C55E);
      case 'Cancelled':
        return const Color(0xFFEF4444);
      default:
        return details['color'] as Color? ?? Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Upcoming':
        return Icons.calendar_today_outlined;
      case 'Pending':
        return Icons.hourglass_top_rounded;
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return details['icon'] as IconData? ?? Icons.help_outline;
    }
  }
}
