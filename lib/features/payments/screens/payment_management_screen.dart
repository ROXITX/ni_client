import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/app_config.dart';
import 'client_payment_page.dart';
import '../../../../models/client.dart';

class PaymentManagementScreen extends StatelessWidget {
  const PaymentManagementScreen({super.key});

  Future<Client?> _fetchClientProfile() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return null;

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(AppConfig.sharedWorkspaceId)
        .collection('clients')
        .where('email', isEqualTo: email.toLowerCase())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return Client.fromJson(query.docs.first.data());
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Client?>(
      future: _fetchClientProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: Text('Client profile not found. Please log out and back in.')));
        }
        
        return ClientPaymentPage(client: snapshot.data!);
      },
    );
  }
}
