import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../../core/utils/date_utils.dart';
import '../../sessions/bloc/sessions_bloc.dart';
import '../bloc/clients_bloc.dart';
import '../../clients/widgets/program_dialog.dart';
import '../../../shared/widgets/session_card.dart';
import '../../dashboard/widgets/dashboard_dialogs.dart';
import 'client_edit_screen.dart';
import '../../scheduling/screens/scheduling_screen.dart'; // For ProgramTypeExtension

class ClientDetailScreen extends StatefulWidget {
  final Client client;
  final String initialTab;
  final int? initialProgramIndex;

  const ClientDetailScreen({super.key, required this.client, this.initialTab = 'bio', this.initialProgramIndex});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  late String _clientDetailTab;
  int? _selectedProgramIndex;
  
  @override
  void initState() {
    super.initState();
    _clientDetailTab = widget.initialTab;
    _selectedProgramIndex = widget.initialProgramIndex;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionsBloc, SessionsState>(
      builder: (context, sessionState) {
        final allSessions = sessionState is SessionsLoaded ? sessionState.sessions : <Session>[];
        // Ensure we listen to the updated client if it changes
        return BlocBuilder<ClientsBloc, ClientsState>(
          builder: (context, clientsState) {
            Client c = widget.client;
            if (clientsState is ClientsLoaded) {
               c = clientsState.clients.firstWhere((cl) => cl.id == widget.client.id, orElse: () => widget.client);
            }

            // Sorting logic for sessions (Legacy Logic)
            final allClientSessions = allSessions.where((s) => s.clientId == c.id).toList();
            int sessionSorter(Session a, Session b) {
               int cmp = a.date.compareTo(b.date);
               if (cmp != 0) return cmp;
               final tA = AppDateUtils.parseTimeRange(a.time)['start'] ?? 0;
               final tB = AppDateUtils.parseTimeRange(b.time)['start'] ?? 0;
               return tA.compareTo(tB);
            }
            final activeSessions = allClientSessions.where((s) => s.status == 'Upcoming' || s.status == 'Pending').toList()..sort(sessionSorter);
            final finishedSessions = allClientSessions.where((s) => s.status == 'Completed' || s.status == 'Cancelled').toList()..sort(sessionSorter);
            final clientSessions = [...activeSessions, ...finishedSessions];

            return Scaffold(
              appBar: AppBar(
                title: const Text('Client Details'),
              ),
              body: Container(
                color: const Color(0xFFF9FAFB),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header section with Title and Buttons (Legacy Logic)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 80.0),
                            child: Text(
                              '${c.firstName} ${c.lastName}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit bio',
                                  icon: const Icon(Icons.edit, color: Color(0xFF6B7280)),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ClientEditScreen(
                                        client: c,
                                        allClients: clientsState is ClientsLoaded ? clientsState.clients : [c],
                                      ),
                                    ));
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete client',
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                  // --- CORRECTED DELETE LOGIC ---
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Client'),
                                        content: const Text('Are you sure you want to permanently delete this client and all of their sessions? This action cannot be undone.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      // Call Bloc which now uses the updated Repo batch logic
                                      if (mounted) {
                                         context.read<ClientsBloc>().add(ClientsDeleteClient(c.id));
                                         Navigator.pop(context); // Go back to list
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Tabs
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              label: const Text('Bio Data'),
                              selected: _clientDetailTab == 'bio',
                              onSelected: (_) => setState(() => _clientDetailTab = 'bio'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Programs'),
                              selected: _clientDetailTab == 'programs',
                              onSelected: (_) => setState(() => _clientDetailTab = 'programs'),
                            ),
                            const SizedBox(width: 8),
                            if (_selectedProgramIndex != null && _selectedProgramIndex! < c.programs.length) ...[
                              ChoiceChip(
                                label: Text('Schedule (${c.programs[_selectedProgramIndex!]['course'] ?? 'Program'})'),
                                selected: _clientDetailTab == 'schedule',
                                onSelected: (_) => setState(() => _clientDetailTab = 'schedule'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Content
                      if (_clientDetailTab == 'bio')
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Contact Info Card
                                Card(
                                  elevation: 2.0,
                                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                        child: Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.email_outlined, color: Color(0xFF6B7280)),
                                        title: Text(c.email, style: const TextStyle(fontWeight: FontWeight.w500)),
                                        subtitle: const Text('Email'),
                                      ),
                                      const Divider(height: 1, indent: 16, endIndent: 16),
                                      ListTile(
                                        leading: const Icon(Icons.phone_outlined, color: Color(0xFF6B7280)),
                                        title: Text(c.phone, style: const TextStyle(fontWeight: FontWeight.w500)),
                                        subtitle: const Text('Phone'),
                                      ),
                                    ],
                                  ),
                                ),
                                // Personal Details Card
                                Card(
                                  elevation: 2.0,
                                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                        child: Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.person_outline, color: Color(0xFF6B7280)),
                                        title: Text(c.gender, style: const TextStyle(fontWeight: FontWeight.w500)),
                                        subtitle: const Text('Gender'),
                                      ),
                                      const Divider(height: 1, indent: 16, endIndent: 16),
                                      ListTile(
                                        leading: const Icon(Icons.cake_outlined, color: Color(0xFF6B7280)),
                                        title: Text(c.dob, style: const TextStyle(fontWeight: FontWeight.w500)),
                                        subtitle: const Text('Date of Birth'),
                                      ),
                                      const Divider(height: 1, indent: 16, endIndent: 16),
                                      if (c.occupation.isNotEmpty)
                                        ListTile(
                                          leading: const Icon(Icons.work_outline, color: Color(0xFF6B7280)),
                                          title: Text(c.occupation, style: const TextStyle(fontWeight: FontWeight.w500)),
                                          subtitle: const Text('Occupation'),
                                        ),
                                    ],
                                  ),
                                ),
                                // Description Card
                                if (c.description.isNotEmpty)
                                  Card(
                                    elevation: 2.0,
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                                          const SizedBox(height: 8),
                                          Text(
                                            c.description,
                                            style: const TextStyle(color: Color(0xFF4B5563), height: 1.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else if (_clientDetailTab == 'programs')
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (c.programs.isEmpty)
                                  Card(
                                    elevation: 2.0,
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                    child: const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.school_outlined, size: 48, color: Color(0xFF6B7280)),
                                            SizedBox(height: 12),
                                            Text('No Programs Registered', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                                            SizedBox(height: 4),
                                            Text('This client has not been registered for any programs yet.', style: TextStyle(color: Color(0xFF9CA3AF))),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  for (int index = 0; index < c.programs.length; index++)
                                    Card(
                                      elevation: 2.0,
                                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12.0),
                                        onTap: () {
                                          setState(() {
                                            _selectedProgramIndex = index;
                                            _clientDetailTab = 'schedule';
                                          });
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Program ${index + 1}: ${_getProgramDisplayName(c.programs[index])}',
                                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                                                    onSelected: (action) => _handleProgramAction(context, c, index, action),
                                                    itemBuilder: (context) => [
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.edit, color: Color(0xFF6B7280), size: 20),
                                                            SizedBox(width: 8),
                                                            Text('Edit Program'),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
                                                            SizedBox(width: 8),
                                                            Text('Delete Program'),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (c.programs[index]['course'] != null)
                                              ListTile(
                                                leading: const Icon(Icons.book_outlined, color: Color(0xFF6B7280)),
                                                title: Text(c.programs[index]['course'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                                subtitle: const Text('Course'),
                                              ),
                                            if (c.programs[index]['days'] != null && c.programs[index]['days'].toString().isNotEmpty)
                                              ListTile(
                                                leading: const Icon(Icons.calendar_today_outlined, color: Color(0xFF6B7280)),
                                                title: Text(c.programs[index]['days'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                                subtitle: const Text('Days'),
                                              ),
                                            if (c.programs[index]['time'] != null && c.programs[index]['time'].toString().isNotEmpty)
                                              ListTile(
                                                leading: const Icon(Icons.access_time_outlined, color: Color(0xFF6B7280)),
                                                title: Text(c.programs[index]['time'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                                subtitle: const Text('Time'),
                                              ),
                                            if (c.programs[index]['startDate'] != null && c.programs[index]['startDate'].toString().isNotEmpty)
                                              ListTile(
                                                leading: const Icon(Icons.play_arrow_outlined, color: Color(0xFF6B7280)),
                                                title: Text(c.programs[index]['startDate'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                                subtitle: const Text('Start Date'),
                                              ),
                                            if (c.programs[index]['endDate'] != null && c.programs[index]['endDate'].toString().isNotEmpty)
                                              ListTile(
                                                leading: const Icon(Icons.stop_outlined, color: Color(0xFF6B7280)),
                                                title: Text(c.programs[index]['endDate'], style: const TextStyle(fontWeight: FontWeight.w500)),
                                                subtitle: const Text('End Date'),
                                              ),
                                            const SizedBox(height: 8),
                                          ],
                                        ),
                                      ),
                                    )
                              ],
                            ),
                          ),
                        )
                      else if (_clientDetailTab == 'schedule')
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_selectedProgramIndex == null)
                                const Expanded(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.info_outline, size: 48, color: Color(0xFF6B7280)),
                                        SizedBox(height: 12),
                                        Text('Select a program first', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                                        SizedBox(height: 4),
                                        Text('Go to Programs tab and tap on a program to view its schedule.', style: TextStyle(color: Color(0xFF9CA3AF))),
                                      ],
                                    ),
                                  ),
                                )
                              else ...[
                                // Program info header
                                Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _getProgramDisplayName(c.programs[_selectedProgramIndex!]),
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                              ),
                                              if (c.programs[_selectedProgramIndex!]['days'] != null)
                                                Text('Days: ${c.programs[_selectedProgramIndex!]['days']}', style: const TextStyle(color: Color(0xFF6B7280))),
                                              if (c.programs[_selectedProgramIndex!]['time'] != null)
                                                Text('Time: ${c.programs[_selectedProgramIndex!]['time']}', style: const TextStyle(color: Color(0xFF6B7280))),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () => setState(() {
                                            _selectedProgramIndex = null;
                                            _clientDetailTab = 'programs';
                                          }),
                                          tooltip: 'Back to programs',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Sessions for this program
                                Expanded(
                                  child: () {
                                    // Filter sessions that belong to this program
                                    // Filter sessions that belong to this program
                                    final selectedProgram = c.programs[_selectedProgramIndex!];
                                    final selectedProgramType = selectedProgram['programType'];
                                    final selectedEnrollmentId = selectedProgram['programEnrollmentId'];
                                    
                                    final programSessions = clientSessions.where((s) {
                                      // 1. Strict Match if both have IDs (New data)
                                      if (selectedEnrollmentId != null && s.programEnrollmentId != null) {
                                         return s.programEnrollmentId == selectedEnrollmentId;
                                      }

                                      // 2. FALLBACK: Type Matching (Legacy data or mixed)
                                      // If the session has NO ID, it belongs to ALL programs of that type (ambiguous)
                                      // If the program has NO ID, it claims ALL sessions of that type (ambiguous)
                                      final sessionProgramType = s.programType?.name;
                                      return (selectedProgramType != null && sessionProgramType == selectedProgramType) ||
                                             (selectedProgramType == null && sessionProgramType == null);
                                    }).toList();
                                    
                                    return programSessions.isEmpty
                                        ? const Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.calendar_today_outlined, size: 48, color: Color(0xFF6B7280)),
                                                SizedBox(height: 12),
                                                Text('No sessions for this program', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
                                              ],
                                            ),
                                          )
                                        : ListView(
                                            children: [
                                              for (final s in programSessions)
                                                SessionCard(
                                                  session: s,
                                                  client: c,
                                                  details: _getSessionDetails(context, s),
                                                  isDetailed: true,
                                                  onActionSelected: (session, action) => _handleDetailSessionAction(context, session, action, allSessions, c),
                                                )
                                            ],
                                          );
                                  }(),
                                ),
                              ],
                            ],
                          ),
                        )
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _getSessionDetails(BuildContext context, Session s) {
      final status = context.read<SessionsBloc>().getRealTimeSessionStatus(s);
      final statusDetails = {
           'Upcoming': {'color': const Color(0xFF2563EB), 'icon': Icons.calendar_today, 'actions': ['Cancel', 'Mark Completed']},
           'Pending': {'color': const Color(0xFFF97316), 'icon': Icons.hourglass_empty, 'actions': ['Cancel', 'Mark Completed']},
           'Completed': {'color': const Color(0xFF16A34A), 'icon': Icons.check_circle, 'actions': ['View Details']},
           'Cancelled': {'color': const Color(0xFFDC2626), 'icon': Icons.cancel, 'actions': ['View Reason']},
           'Pending Action': {'color': const Color(0xFF9333EA), 'icon': Icons.notifications_active, 'actions': ['Resolve']},
      };
      return statusDetails[status] ?? statusDetails['Upcoming']!;
  }

  void _handleProgramAction(BuildContext context, Client c, int index, String action) {
      if (action == 'delete') {
          final updatedPrograms = List<Map<String, dynamic>>.from(c.programs);
          updatedPrograms.removeAt(index);
          
          final updatedClient = Client(
             id: c.id, firstName: c.firstName, lastName: c.lastName, dob: c.dob, gender: c.gender, email: c.email, phone: c.phone, occupation: c.occupation, description: c.description,
             programs: updatedPrograms
          );
          context.read<ClientsBloc>().add(ClientsUpdateClient(updatedClient));
          
          if (_selectedProgramIndex == index) {
             setState(() { _selectedProgramIndex = null; _clientDetailTab = 'programs'; });
          }
      } else if (action == 'edit') {
         _showProgramDialog(context, c, index: index);
      }
  }

  String _getProgramDisplayName(Map<String, dynamic> p) {
     if (p['course'] != null && p['course'].toString().isNotEmpty) {
       return p['course'];
     }
     
     String rawName = p['programType'] ?? 'Unknown Program';
     try {
       rawName = ProgramTypeExtension.fromString(rawName).displayName;
     } catch (_) {
       if (rawName.isNotEmpty && rawName != 'Unknown Program') {
          final RegExp exp = RegExp(r'(?<=[a-z])[A-Z]');
          rawName = rawName.replaceAllMapped(exp, (Match m) => ' ${m.group(0)}');
          rawName = rawName[0].toUpperCase() + rawName.substring(1);
       }
     }
     return rawName;
  }

  Future<void> _showProgramDialog(BuildContext context, Client c, {int? index}) async {
     final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => ProgramDialog(initialProgram: index != null ? c.programs[index] : null),
     );
     
     if (result != null) {
        final updatedPrograms = List<Map<String, dynamic>>.from(c.programs);
        if (index != null) {
           updatedPrograms[index] = result;
        } else {
           updatedPrograms.add(result);
        }
        
        final updatedClient = Client(
             id: c.id, firstName: c.firstName, lastName: c.lastName, dob: c.dob, gender: c.gender, email: c.email, phone: c.phone, occupation: c.occupation, description: c.description,
             programs: updatedPrograms
        );
        context.read<ClientsBloc>().add(ClientsUpdateClient(updatedClient));
     }
  }

  Future<void> _handleDetailSessionAction(BuildContext context, Session session, String action, List<Session> allSessions, Client client) async {
       if (action == 'Completed' || action == 'Cancelled') {
           showFeedbackDialog(context, session: session, mode: action, clients: [client]);
       } else if (action == 'Postpone') {
           showPostponeDialog(context, session: session, allSessions: allSessions, clients: [client]);
       } else if (action == 'Edit/View Details') {
           showFeedbackDialog(context, session: session, mode: 'View', clients: [client]);
       }
  }
}
