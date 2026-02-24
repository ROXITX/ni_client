import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../models/client.dart';
import '../../../../models/session.dart';
import '../../../core/utils/date_utils.dart';
import '../../sessions/bloc/sessions_bloc.dart';
import '../bloc/clients_bloc.dart';
import '../screens/client_detail_screen.dart';

class ClientListWidget extends StatefulWidget {
  final void Function(Client)? onClientSelected;
  final bool showAppBar; // Useful if we want to embed it without the search bar header (though usually we want search)

  const ClientListWidget({
    super.key,
    this.onClientSelected,
    this.showAppBar = true, // Defaults to true to show the search bar
  });

  @override
  State<ClientListWidget> createState() => _ClientListWidgetState();
}

class _ClientListWidgetState extends State<ClientListWidget> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _clientSearch = '';
  String _clientActivityFilter = 'all';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure data is loaded
    context.read<ClientsBloc>().add(ClientsSubscriptionRequested());
    context.read<SessionsBloc>().add(SessionsSubscriptionRequested());

    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, clientsState) {
        final isLoading = clientsState is ClientsLoading;
        final clients = (clientsState is ClientsLoaded) ? clientsState.clients : <Client>[];

        return BlocBuilder<SessionsBloc, SessionsState>(
          builder: (context, sessionsState) {
            final sessions = (sessionsState is SessionsLoaded) ? sessionsState.sessions : <Session>[];

            // --- Filter Logic ---
            final searchTerm = _clientSearch.trim().toLowerCase();
            List<Client> filtered = clients.where((c) {
              final name = ('${c.firstName} ${c.lastName}').toLowerCase();
              final phone = c.phone.toLowerCase();
              final email = c.email.toLowerCase();
              if (searchTerm.isNotEmpty && !name.contains(searchTerm) && !phone.contains(searchTerm) && !email.contains(searchTerm)) return false;
              
              bool hasFuture(int clientId) => sessions.any((s) => s.clientId == clientId && AppDateUtils.isSessionDateInFuture(s.date));
              
              if (_clientActivityFilter == 'future') return hasFuture(c.id);
              if (_clientActivityFilter == 'none') return !hasFuture(c.id);
              return true;
            }).toList()
              ..sort((a, b) => ('${a.firstName} ${a.lastName}').compareTo('${b.firstName} ${b.lastName}'));

            // --- UI ---
            return Container(
              color: const Color(0xFFF9FAFB),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search Bar & Filter (Standardized)
                    if (widget.showAppBar) ...[
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            decoration: InputDecoration(
                              hintText: 'Search by name, phone, or email...',
                              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFd1d5db))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onChanged: (v) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(const Duration(milliseconds: 200), () {
                                if (!mounted) return;
                                setState(() {
                                  _clientSearch = v;
                                });
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                final RenderBox button = context.findRenderObject() as RenderBox;
                                final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
                                final RelativeRect position = RelativeRect.fromRect(
                                  Rect.fromPoints(
                                    button.localToGlobal(Offset.zero + const Offset(0, 40), ancestor: overlay),
                                    button.localToGlobal(button.size.bottomRight(Offset.zero) + const Offset(0, 40), ancestor: overlay),
                                  ),
                                  Offset.zero & overlay.size,
                                );
                                showMenu<String>(
                                  context: context,
                                  position: position,
                                  items: [
                                    const PopupMenuItem(value: 'all', child: Text('All Clients')),
                                    const PopupMenuItem(value: 'future', child: Text('With Future Sessions')),
                                    const PopupMenuItem(value: 'none', child: Text('No Future Sessions')),
                                  ],
                                ).then((v) {
                                  if (v != null) setState(() => _clientActivityFilter = v);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFd1d5db)),
                                ),
                                child: const Icon(Icons.filter_list, size: 20, color: Color(0xFF6B7280)),
                              ),
                            );
                          }
                        )
                      ]),
                      const SizedBox(height: 12),
                    ],

                    // List
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : filtered.isEmpty
                              ? const Center(child: Text('No clients found.', style: TextStyle(color: Color(0xFF6B7280))))
                              : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final c = filtered[i];
                                // Collect session stats for this client
                                final clientSessions = sessions.where((s) => s.clientId == c.id).toList();
                                final upcomingSessions = <Session>[]; // Keep variable name for Next logic compatibility
                                int typeUpcoming = 0;
                                int typePending = 0;
                                int typeCompleted = 0; // Distinct variable name

                                for (final s in clientSessions) {
                                  if (s.status == 'Cancelled') continue;
                                  if (s.status == 'Completed') {
                                    typeCompleted++;
                                    continue;
                                  }
                                  
                                  final st = AppDateUtils.determineSessionStatus(s.status, s.date, s.time);
                                  if (st == 'Pending' || st == 'Pending Action') {
                                    typePending++;
                                    upcomingSessions.add(s);
                                  } else if (st == 'Upcoming') {
                                    typeUpcoming++;
                                    upcomingSessions.add(s);
                                  }
                                }
                                
                                // Determine next upcoming session time
                                DateTime? nextDt;
                                String? nextTimeDisplay;
                                for (final s in upcomingSessions) {
                                  final dt = AppDateUtils.parseSessionDateTime(s.date, s.time);
                                  if (dt == null) continue;
                                  // Ensure we only show truly future sessions as "Next"
                                  if (dt.isBefore(DateTime.now())) continue;
                                  
                                  if (nextDt == null || dt.isBefore(nextDt)) {
                                    nextDt = dt;
                                    nextTimeDisplay = s.time.split(' - ').first.trim();
                                  }
                                }
                                
                                String? nextLabel;
                                if (nextDt != null) {
                                  try {
                                    nextLabel = 'Next: ${intl.DateFormat('EEE, MMM d • h:mm a').format(nextDt)}';
                                  } catch (_) {
                                    nextLabel = 'Next: ${AppDateUtils.dateToStr(nextDt)} • ${nextTimeDisplay ?? ''}';
                                  }
                                }

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    title: Text('${c.firstName} ${c.lastName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (c.phone.isNotEmpty) Text('📞 ${c.phone}', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                                        if (c.email.isNotEmpty) Text('✉️ ${c.email}', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            if (typeUpcoming > 0) ...[
                                               _sessionStatChip(label: 'Upcoming', value: typeUpcoming, color: const Color(0xFF2563EB), bg: const Color(0xFFE0E7FF)),
                                               const SizedBox(width: 6),
                                            ],
                                            if (typePending > 0) ...[
                                               _sessionStatChip(label: 'Pending', value: typePending, color: const Color(0xFFF59E0B), bg: const Color(0xFFFEF3C7)),
                                               const SizedBox(width: 6),
                                            ],
                                            _sessionStatChip(label: 'Completed', value: typeCompleted, color: const Color(0xFF059669), bg: const Color(0xFFD1FAE5)),
                                          ],
                                        ),
                                        if (nextLabel != null) ...[
                                          const SizedBox(height: 6),
                                          Text(nextLabel, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                                        ],
                                      ],
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      if (widget.onClientSelected != null) {
                                        widget.onClientSelected!(c);
                                      } else {
                                        // Default navigation
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ClientDetailScreen(client: c),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sessionStatChip({required String label, required int value, required Color color, required Color bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bg.withOpacity(0.9)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$value ',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            TextSpan(
              text: label.toLowerCase(),
              style: TextStyle(
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
