import 'package:flutter/material.dart';
import '../../../../models/payment_entry.dart';
import '../../../../models/client.dart';
import '../../../shared/widgets/payment_card.dart';

class CollapsiblePaymentGroup extends StatefulWidget {
  final String status;
  final List<PaymentEntry> payments;
  final List<Client> clients;
  final void Function(PaymentEntry, String)? onActionSelected;
  final Map<String, Map<String, dynamic>> statusDetails;

  const CollapsiblePaymentGroup({
    super.key,
    required this.status,
    required this.payments,
    required this.clients,
    this.onActionSelected,
    required this.statusDetails,
  });

  @override
  State<CollapsiblePaymentGroup> createState() => _CollapsiblePaymentGroupState();
}

class _CollapsiblePaymentGroupState extends State<CollapsiblePaymentGroup> {
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
                  Text('${widget.status} (${widget.payments.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            ...widget.payments.map((p) {
              return PaymentCard(
                payment: p,
                client: widget.clients.firstWhere((c) => c.id == p.clientId, orElse: () => Client(id: 0, firstName: 'Unknown', lastName: '', dob: '', gender: '', email: '', phone: '', occupation: '', description: '')),
                details: widget.statusDetails[widget.status] ?? {},
                onActionSelected: (payment, action) => widget.onActionSelected?.call(payment, action),
              );
            }),
        ],
      ),
    );
  }
}
