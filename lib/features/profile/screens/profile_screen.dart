import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/app_config.dart';
import '../../auth/screens/change_password_screen.dart';
import '../../../models/client.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Center(
            child: Text('Could not load profile information.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        final client = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               // Header Avatar
               Center(
                 child: CircleAvatar(
                   radius: 50,
                   backgroundColor: const Color(0xFFFCD34D),
                   child: Text(
                     client.firstName.isNotEmpty ? client.firstName[0].toUpperCase() : '?',
                     style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                   ),
                 ),
               ),
               const SizedBox(height: 16),
               Center(
                 child: Text(
                   '${client.firstName} ${client.lastName}',
                   style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                 ),
               ),
               const SizedBox(height: 32),
               
               // Bio Data Details
               _buildProfileCard(client),
               
               const SizedBox(height: 32),
               
               // Actions
               ElevatedButton.icon(
                 icon: const Icon(Icons.lock_outline, color: Colors.white),
                 label: const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF3B82F6),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                 ),
                 onPressed: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (_) => const ChangePasswordScreen(isFirstLogin: false)),
                   );
                 },
               ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileCard(Client client) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(12),
         side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             _buildInfoRow(Icons.email_outlined, 'Email', client.email),
             const Divider(height: 24),
             _buildInfoRow(Icons.phone_outlined, 'Phone', client.phone),
             const Divider(height: 24),
             _buildInfoRow(Icons.cake_outlined, 'Date of Birth', client.dob),
             const Divider(height: 24),
             _buildInfoRow(Icons.work_outline, 'Occupation', client.occupation),
             const Divider(height: 24),
             _buildInfoRow(Icons.person_outline, 'Gender', client.gender),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : 'Not provided', 
                style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937), fontWeight: FontWeight.w500)
              ),
            ],
          )
        )
      ],
    );
  }
}
