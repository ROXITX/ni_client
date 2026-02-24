import 'package:flutter/material.dart';
import '../../../../models/session.dart';
import '../../../../models/client.dart';
import '../../../shared/widgets/session_card.dart';

class CollapsibleSessionGroup extends StatefulWidget {
  final String status;
  final List<Session> sessions;
  final List<Client> clients;
  final void Function(Session, String)? onActionSelected;
  final Map<String, Map<String, dynamic>> statusDetails;
  final String Function(Session) getRealTimeStatus;

  const CollapsibleSessionGroup({
    Key? key,
    required this.status,
    required this.sessions,
    required this.clients,
    this.onActionSelected,
    required this.statusDetails,
    required this.getRealTimeStatus,
  }) : super(key: key);

  @override
  State<CollapsibleSessionGroup> createState() => _CollapsibleSessionGroupState();
}

class _CollapsibleSessionGroupState extends State<CollapsibleSessionGroup> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Text('${widget.status} (${widget.sessions.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            ...widget.sessions.map((s) {
              final realTimeStatus = widget.getRealTimeStatus(s);
              return SessionCard( // Ensure SessionCard is available in the imports
                session: s,
                client: widget.clients.firstWhere((c) => c.id == s.clientId, orElse: () => Client(id: 0, firstName: 'Unknown', lastName: '', dob: '', gender: '', email: '', phone: '', occupation: '', description: '')),
                details: widget.statusDetails[realTimeStatus]!,
                onActionSelected: (session, action) => widget.onActionSelected?.call(session, action),
              );
            }),
        ],
      ),
    );
  }
}
