import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/core/config/app_config.dart';
import 'lib/firebase_options_dev.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DevFirebaseOptions.currentPlatform,
  );

  print('=== TEST DB ADMINS SCRIPT ===');
  
  try {
    // Authenticate with a test account to enable reading
    final creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'a@gmail.com', password: 'Password@123');
    print('Logged in successfully: ${creds.user?.uid}');

    final query = await FirebaseFirestore.instance.collection('users').get();

    print('Found ${query.docs.length} users (workspaces) in total.');
    
    for (var doc in query.docs) {
       print('Workspace ID: ${doc.id}');
       
       final clientsQuery = await doc.reference.collection('clients').limit(5).get();
       print('  -> This workspace has ${clientsQuery.docs.length} clients.');
       for (var clientDoc in clientsQuery.docs) {
          print('    -> Client Email: ${clientDoc.data()['email']}');
       }
    }
    
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    print('Error: $e');
  }
}
