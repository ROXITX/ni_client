import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:ni_client/core/config/app_config.dart';
import 'package:ni_client/firebase_options_dev.dart' as dev;
import 'package:ni_client/firebase_options.dart' as prod;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Connect to Prod
  final prodApp = await Firebase.initializeApp(
    name: 'prod',
    options: prod.DefaultFirebaseOptions.currentPlatform,
  );
  
  // Connect to Test
  final testApp = await Firebase.initializeApp(
    name: 'test',
    options: dev.DevFirebaseOptions.currentPlatform,
  );
  
  print('=============================================');
  print(' DIAGNOSTIC: PROD VS TEST DATABASE CONTENTS');
  print('=============================================');
  print('Workspace ID being queried: \'oxs3ec0udCM2j3rK4CVIEe68kWw2\'\n');

  // Query Prod
  final prodQuery = await FirebaseFirestore.instanceFor(app: prodApp)
      .collection('users')
      .doc('oxs3ec0udCM2j3rK4CVIEe68kWw2')
      .collection('clients')
      .get();
      
  print('PROD DATABASE (${prodApp.options.projectId}):');
  print('  -> Found ${prodQuery.docs.length} clients registered here.');
  
  // Query Test
  final testQuery = await FirebaseFirestore.instanceFor(app: testApp)
      .collection('users')
      .doc('oxs3ec0udCM2j3rK4CVIEe68kWw2')
      .collection('clients')
      .get();
      
  print('\nTEST DATABASE (${testApp.options.projectId}):');
  print('  -> Found ${testQuery.docs.length} clients registered here.');
  
  print('\nCONCLUSION:');
  if (testQuery.docs.isNotEmpty) {
     print('  Your TEST database ACTUALLY CONTAINS client data under this specific Workspace ID.');
     print('  If these are OLD production clients, it means your Test DB has a copied snapshot of Prod data.');
     print('  This is why *some* production clients can log in to the test app (they exist in the snapshot),');
     print('  but newer ones cannot (they were added to Prod after the snapshot was taken).');
  } else {
     print('  Test database is empty for this ID. The workspace ID in app_config.dart might be wrong for Test.');
  }
}
