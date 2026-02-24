import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ni_client/firebase_options_dev.dart';
import 'package:ni_client/firebase_options.dart';
import 'package:ni_client/core/config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: AppConfig.useTestDatabase 
        ? DevFirebaseOptions.currentPlatform 
        : DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SetupAuthApp());
}

class SetupAuthApp extends StatelessWidget {
  const SetupAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Setup Client Auth',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SetupAuthScreen(),
    );
  }
}

class SetupAuthScreen extends StatefulWidget {
  const SetupAuthScreen({super.key});

  @override
  State<SetupAuthScreen> createState() => _SetupAuthScreenState();
}

class _SetupAuthScreenState extends State<SetupAuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: 'Password@123');
  String _status = '';
  
  Future<void> _createAuthAccount() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    
    setState(() => _status = 'Checking Firestore for $email...');
    
    try {
       // Search for client in DB
       final query = await FirebaseFirestore.instance
                 .collection('users')
                 .doc(AppConfig.sharedWorkspaceId)
                 .collection('clients')
                 .where('email', isEqualTo: email.toLowerCase())
                 .get();
                 
       if (query.docs.isEmpty) {
          // Check if any case works by fetching all and filtering in dart
          final allDocs = await FirebaseFirestore.instance
                 .collection('users')
                 .doc(AppConfig.sharedWorkspaceId)
                 .collection('clients').get();
          
          bool found = false;
          for (var doc in allDocs.docs) {
             final data = doc.data();
             if ((data['email'] as String? ?? '').toLowerCase() == email.toLowerCase()) {
                 found = true;
                 break;
             }
          }
          
          if (!found) {
            setState(() => _status = 'WARNING: Client email $email NOT FOUND in Firestore under workspace ${AppConfig.sharedWorkspaceId}. Auth account will be created anyway, but Client will see no data until an admin registers this email.');
          } else {
            setState(() => _status = 'Client found manually (case mismatch in DB). Proceeding to create auth...');
          }
       } else {
         setState(() => _status = 'Client verified in DB! Creating Firebase Auth account...');
       }
       
       try {
           final creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
           setState(() => _status = 'SUCCESS! Auth account created for ${creds.user?.email}. They can now log in.');
       } on FirebaseAuthException catch (e) {
           if (e.code == 'email-already-in-use') {
               setState(() => _status = 'SUCCESS! Auth account already exists for this email! They should be able to log in with their password.');
           } else {
               setState(() => _status = 'AUTH ERROR: ${e.message}');
           }
       }
    } catch (e) {
       setState(() => _status = 'ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Provisioning Tool')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text('Use this tool to manually force-create an authentication login for a client email.', style: TextStyle(fontSize: 16)),
             const SizedBox(height: 20),
             TextField(
               controller: _emailController,
               decoration: const InputDecoration(labelText: 'Client Email', border: OutlineInputBorder()),
             ),
             const SizedBox(height: 12),
             TextField(
               controller: _passwordController,
               decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
             ),
             const SizedBox(height: 20),
             ElevatedButton(
               onPressed: _createAuthAccount,
               child: const Text('Provision Login'),
             ),
             const SizedBox(height: 24),
             Text(_status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
          ],
        ),
      ),
    );
  }
}
