import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/core/config/app_config.dart';
import 'lib/firebase_options.dart';
import 'lib/firebase_options_dev.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Testing Database)
  await Firebase.initializeApp(
    options: AppConfig.useTestDatabase 
      ? DefaultFirebaseOptionsDev.currentPlatform 
      : DefaultFirebaseOptions.currentPlatform,
  );

  print('=== TEST CLIENT FETCH SCRIPT ===');
  print('Target Workspace ID: ${AppConfig.sharedWorkspaceId}');
  print('Environment: ${AppConfig.useTestDatabase ? "TEST" : "PROD"}');
  
  // We need to sign in to fetch data because of security rules
  // Let's prompt the user or just use a known test account
  print('Attempting to query clients collection...');
  
  try {
    // Log in (Assuming we can log in with a@gmail.com / Password@123 as seen in logs)
    final creds = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'a@gmail.com', password: 'Password@123');
    print('Logged in successfully: ${creds.user?.uid}');

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(AppConfig.sharedWorkspaceId)
        .collection('clients')
        .where('email', isEqualTo: 'a@gmail.com')
        .get();

    print('Query returned ${query.docs.length} documents.');
    
    if (query.docs.isNotEmpty) {
      for (var doc in query.docs) {
         print('Doc ID: ${doc.id}');
         print('Data: ${doc.data()}');
      }
    } else {
       print('NO DOCUMENTS FOUND FOR a@gmail.com');
       
       // Let's do a broad query to see what IS there
       print('Fetching all clients (limit 5) to see format...');
       final allQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(AppConfig.sharedWorkspaceId)
          .collection('clients')
          .limit(5)
          .get();
          
       print('General query returned ${allQuery.docs.length} documents.');
       for (var doc in allQuery.docs) {
           print('Doc ID: ${doc.id} | Email: ${doc.data()['email']}');
       }
    }
    
    // Sign out
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    print('Error: $e');
  }
}
