import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../../core/utils/date_utils.dart';
import '../../clients/bloc/clients_bloc.dart';
import '../bloc/sessions_bloc.dart';
import '../../../shared/widgets/session_card.dart';

class WeeklyViewScreen extends StatefulWidget {
  const WeeklyViewScreen({super.key});

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  DateTime _weeklyCursor = DateTime.now();
  DateTime? _weeklySelectedDay;
  bool _weeklyShowAllWeek = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, clientsState) {
        final clients = (clientsState is ClientsLoaded) ? clientsState.clients : <Client>[];
        return BlocBuilder<SessionsBloc, SessionsState>(
          builder: (context, sessionsState) {
            final sessions = (sessionsState is SessionsLoaded) ? sessionsState.sessions : <Session>[];
            
            // Logic
            int toSunday = _weeklyCursor.weekday % 7;
            DateTime sunday = _weeklyCursor.subtract(Duration(days: toSunday));
            String header = '${DateFormat('MMM').format(sunday)} ${sunday.day} – ${DateFormat('MMM').format(sunday.add(const Duration(days: 6)))} ${sunday.add(const Duration(days: 6)).day}, ${sunday.year}';
            List<DateTime> days = List.generate(7, (i) => sunday.add(Duration(days: i)));

            List<Session> getDaySessions(DateTime d) {
               final ds = AppDateUtils.dateToStr(d);
               final list = sessions.where((s) => s.date == ds).toList();
               list.sort((a, b) {
                  final tA = AppDateUtils.parseTimeRange(a.time);
                  final tB = AppDateUtils.parseTimeRange(b.time);
                  return (tA['start'] ?? 0).compareTo(tB['start'] ?? 0);
               });
               return list;
            }

            return Container(
              color: const Color(0xFFF9FAFB),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Nav
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.grey),
                          onPressed: () => setState(() {
                            _weeklyCursor = _weeklyCursor.subtract(const Duration(days: 7));
                            _weeklySelectedDay = null;
                            _weeklyShowAllWeek = true;
                          }),
                        ),
                        Text(header, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.grey),
                          onPressed: () => setState(() {
                            _weeklyCursor = _weeklyCursor.add(const Duration(days: 7));
                            _weeklySelectedDay = null;
                            _weeklyShowAllWeek = true;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Day Tiles
                    Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: days.map((d) {
                          final dayFormat = DateFormat('yyyy-MM-dd').format(d);
                          final daySessions = sessions.where((s) => s.date == AppDateUtils.dateToStr(d)).toList();
                          final sessionCount = daySessions.length;
                          
                          bool isSelected = _weeklySelectedDay != null && AppDateUtils.dateToStr(_weeklySelectedDay!) == AppDateUtils.dateToStr(d);
                          bool isToday = AppDateUtils.dateToStr(d) == AppDateUtils.dateToStr(DateTime.now());

                          // Indicator Logic
                          final bloc = context.read<SessionsBloc>();
                          final statuses = daySessions.map((s) => bloc.getRealTimeSessionStatus(s)).toSet();

                          bool hasPending = statuses.contains('Pending') || statuses.contains('Pending Action');
                          bool hasUpcoming = statuses.contains('Upcoming');
                          
                          BoxDecoration indicatorDeco;
                          if (hasPending && hasUpcoming) {
                             indicatorDeco = const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFFF59E0B), Color(0xFF3B82F6)],
                                  stops: [0.5, 0.5],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                             );
                          } else if (hasPending) {
                             indicatorDeco = const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle);
                          } else if (hasUpcoming) {
                             indicatorDeco = const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle);
                          } else {
                             indicatorDeco = const BoxDecoration(color: Colors.grey, shape: BoxShape.circle);
                          }

                          return Expanded(
                            child: GestureDetector(
                               onTap: () {
                                  setState(() {
                                     if (isSelected) {
                                        _weeklySelectedDay = null; 
                                        _weeklyShowAllWeek = true;
                                     } else {
                                        _weeklySelectedDay = d;
                                        _weeklyShowAllWeek = false;
                                     }
                                  });
                               },
                               child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                     color: isSelected ? const Color(0xFFEFF6FF) : (isToday ? Colors.white : Colors.transparent),
                                     border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : (isToday ? const Color(0xFFE5E7EB) : Colors.transparent)),
                                     borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                     children: [
                                        Text(DateFormat('E').format(d), style: TextStyle(fontSize: 12, color: isSelected ? const Color(0xFF1E40AF) : Colors.grey)),
                                        const SizedBox(height: 4),
                                        Text('${d.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF1E3A8A) : Colors.black)),
                                        if (sessionCount > 0) ...[
                                           const SizedBox(height: 4),
                                           Container(
                                              width: 20, 
                                              height: 20,
                                              alignment: Alignment.center,
                                              decoration: indicatorDeco,
                                              child: Text('$sessionCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                           )
                                        ]
                                     ],
                                  ),
                               ),
                            ),
                          );
                       }).toList(),
                    ),
                    const SizedBox(height: 12),
                    
                    // Sessions List
                    Expanded(
                       child: ListView(
                          children: [
                             if (_weeklyShowAllWeek) ...[
                                for (final d in days) ...[
                                   if (getDaySessions(d).isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                                        child: Text(DateFormat('EEEE, MMM d').format(d), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                      ),
                                      ...getDaySessions(d).map((s) => _buildSessionItem(s, clients, context)),
                                   ]
                                ]
                             ] else if (_weeklySelectedDay != null) ...[
                                 ...getDaySessions(_weeklySelectedDay!).map((s) => _buildSessionItem(s, clients, context)),
                                 if (getDaySessions(_weeklySelectedDay!).isEmpty)
                                    const Padding(
                                       padding: EdgeInsets.all(32),
                                       child: Center(child: Text('No sessions for this day')),
                                    )
                             ]
                          ],
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
      
      // Inline status details map for now, ideally in Bloc or Utils
      final status = context.read<SessionsBloc>().getRealTimeSessionStatus(s);
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
            // TODO: Action handling
        },
      );
  }
}
