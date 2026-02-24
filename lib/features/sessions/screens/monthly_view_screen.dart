import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../../core/utils/date_utils.dart';
import '../../clients/bloc/clients_bloc.dart';
import '../bloc/sessions_bloc.dart';
import '../../../shared/widgets/session_card.dart';

class MonthlyViewScreen extends StatefulWidget {
  const MonthlyViewScreen({super.key});

  @override
  State<MonthlyViewScreen> createState() => _MonthlyViewScreenState();
}

class _MonthlyViewScreenState extends State<MonthlyViewScreen> {
  DateTime _monthlyCursor = DateTime.now();
  late DateTime _monthlySelected; // Default to first of month or today

  @override
  void initState() {
    super.initState();
    _monthlySelected = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, clientsState) {
         final clients = (clientsState is ClientsLoaded) ? clientsState.clients : <Client>[];
         return BlocBuilder<SessionsBloc, SessionsState>(
            builder: (context, sessionsState) {
               final sessions = (sessionsState is SessionsLoaded) ? sessionsState.sessions : <Session>[];
               
               // Grid Logic
               DateTime firstOfMonth = DateTime(_monthlyCursor.year, _monthlyCursor.month, 1);
               int firstWeekday = firstOfMonth.weekday % 7; // Sun=0
               int daysInMonth = DateTime(_monthlyCursor.year, _monthlyCursor.month + 1, 0).day;
               
               List<DateTime?> grid = [];
               for (int i = 0; i < firstWeekday; i++) grid.add(null);
               for (int d = 1; d <= daysInMonth; d++) grid.add(DateTime(_monthlyCursor.year, _monthlyCursor.month, d));
               while (grid.length % 7 != 0) grid.add(null);

               List<Session> getDaySessions(DateTime d) {
                   final ds = AppDateUtils.dateToStr(d);
                   return sessions.where((s) => s.date == ds).toList()
                      ..sort((a,b) {
                         final tA = AppDateUtils.parseTimeRange(a.time);
                         final tB = AppDateUtils.parseTimeRange(b.time);
                         return (tA['start'] ?? 0).compareTo(tB['start'] ?? 0);
                      });
               }

               return Container(
                 color: const Color(0xFFF9FAFB),
                 child: Padding(
                    padding: const EdgeInsets.all(16.0),
                     child: CustomScrollView(
                        slivers: [
                           SliverToBoxAdapter(
                              child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.stretch,
                                 children: [
                          // Header
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                                IconButton(
                                   icon: const Icon(Icons.chevron_left, color: Colors.grey),
                                   onPressed: () => setState(() {
                                      _monthlyCursor = DateTime(_monthlyCursor.year, _monthlyCursor.month - 1, 1);
                                      // Reset selected to first of new month? Or keep distinct?
                                      _monthlySelected = _monthlyCursor; // Default to first
                                   }),
                                ),
                                Text(DateFormat('MMMM yyyy').format(_monthlyCursor), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                IconButton(
                                   icon: const Icon(Icons.chevron_right, color: Colors.grey),
                                   onPressed: () => setState(() {
                                      _monthlyCursor = DateTime(_monthlyCursor.year, _monthlyCursor.month + 1, 1);
                                      _monthlySelected = _monthlyCursor;
                                   }),
                                ),
                             ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Days Header
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: const [
                                Text('Sun', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Mon', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Tue', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Wed', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Thu', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Fri', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Sat', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                             ].map((w) => Expanded(child: Center(child: w))).toList(),
                          ),
                          const SizedBox(height: 6),
                          
                          // Calendar Grid
                          GridView.builder(
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 7, 
                                childAspectRatio: 1.0, // Or tweak
                                mainAxisSpacing: 4,
                                crossAxisSpacing: 4
                             ),
                             itemCount: grid.length,
                             itemBuilder: (context, index) {
                                final d = grid[index];
                                if (d == null) return Container();
                                
                                final ds = AppDateUtils.dateToStr(d);
                                final daySessions = sessions.where((s) => s.date == ds).toList();
                                final sessionCount = daySessions.length;
                                final isSelected = AppDateUtils.dateToStr(d) == AppDateUtils.dateToStr(_monthlySelected);
                                final isToday = AppDateUtils.dateToStr(d) == AppDateUtils.dateToStr(DateTime.now());

                                final bloc = context.read<SessionsBloc>();
                                final statuses = daySessions.map((s) => bloc.getRealTimeSessionStatus(s)).toSet();
                                
                                bool hasPending = statuses.contains('Pending') || statuses.contains('Pending Action');
                                bool hasUpcoming = statuses.contains('Upcoming');
                                
                                BoxDecoration indicatorDeco;
                                if (hasPending && hasUpcoming) {
                                   indicatorDeco = const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFF3B82F6)], stops: [0.5, 0.5], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                                   );
                                } else if (hasPending) {
                                   indicatorDeco = const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle);
                                } else if (hasUpcoming) {
                                   indicatorDeco = const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle);
                                } else {
                                   indicatorDeco = const BoxDecoration(color: Colors.grey, shape: BoxShape.circle);
                                }
                                
                                return GestureDetector(
                                   onTap: () => setState(() => _monthlySelected = d),
                                   child: Container(
                                      decoration: BoxDecoration(
                                         color: isSelected ? const Color(0xFFEFF6FF) : (isToday ? Colors.white : Colors.transparent),
                                         border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : (isToday ? const Color(0xFFE5E7EB) : Colors.transparent)),
                                         borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                         mainAxisAlignment: MainAxisAlignment.center,
                                         children: [
                                            Text('${d.day}', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF1E3A8A) : Colors.black)),
                                            if (sessionCount > 0)
                                               Container(
                                                  margin: const EdgeInsets.only(top: 2),
                                                  width: 18, 
                                                  height: 18,
                                                  alignment: Alignment.center,
                                                  decoration: indicatorDeco,
                                                  child: Text('$sessionCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                                               )
                                         ],
                                      ),
                                   ),
                                );
                             },
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          
                          // Selected Day List
                          Padding(
                             padding: const EdgeInsets.symmetric(vertical: 8),
                             child: Text(DateFormat('EEEE, MMMM d').format(_monthlySelected), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                                 ],
                              ),
                           ),
                           SliverFillRemaining(
                              hasScrollBody: false,
                              child: getDaySessions(_monthlySelected).isEmpty 
                              ? const Center(child: Text('No sessions for this day'))
                              : Column(
                                 children: getDaySessions(_monthlySelected).map((s) => _buildSessionItem(s, clients, context)).toList(),
                              ),
                           )
                        ],
                     ),
                 ),
               );
            },
         );
      },
    );
  }

  Widget _buildSessionItem(Session s, List<Client> clients, BuildContext context) {
      final client = clients.firstWhere((c) => c.id == s.clientId, orElse: () => Client(id: 0, firstName: 'Unknown', lastName: '', phone: '', email: '', dob: '', gender: '', occupation: '', description: '', programs: []));
      final status = context.read<SessionsBloc>().getRealTimeSessionStatus(s);
      // Status Details map same as WeeklyView
       final statusDetails = {
           'Upcoming': {'color': const Color(0xFFEFF6FF), 'borderColor': const Color(0xFFBFDBFE), 'textColor': const Color(0xFF1E3A8A), 'icon': Icons.calendar_today, 'iconColor': const Color(0xFF2563EB), 'actions': <String>[]},
           'Pending': {'color': const Color(0xFFFFF7ED), 'borderColor': const Color(0xFFFED7AA), 'textColor': const Color(0xFF9A3412), 'icon': Icons.hourglass_empty, 'iconColor': const Color(0xFFF97316), 'actions': <String>[]},
           'Completed': {'color': const Color(0xFFF0FDF4), 'borderColor': const Color(0xFFBBF7D0), 'textColor': const Color(0xFF14532D), 'icon': Icons.check_circle, 'iconColor': const Color(0xFF16A34A), 'actions': <String>[]},
           'Cancelled': {'color': const Color(0xFFFEF2F2), 'borderColor': const Color(0xFFFECACA), 'textColor': const Color(0xFF7F1D1D), 'icon': Icons.cancel, 'iconColor': const Color(0xFFDC2626), 'actions': <String>[]},
           'Pending Action': {'color': const Color(0xFFFAF5FF), 'borderColor': const Color(0xFFE9D5FF), 'textColor': const Color(0xFF6B21A8), 'icon': Icons.notifications_active, 'iconColor': const Color(0xFF9333EA), 'actions': <String>[]},
       };
      final details = statusDetails[status] ?? statusDetails['Upcoming']!;

      return SessionCard(
        session: s,
        client: client,
        details: details,
        isDetailed: false,
        onActionSelected: (session, action) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action $action not implemented yet')));
        },
      );
  }
}
