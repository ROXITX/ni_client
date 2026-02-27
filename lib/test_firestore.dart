import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:ni_client/core/config/app_config.dart';
import 'package:ni_client/firebase_options_dev.dart' as dev;
import 'package:ni_client/firebase_options.dart' as prod;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final firebaseOptions = AppConfig.useTestDatabase 
      ? dev.DefaultFirebaseOptions.currentPlatform 
      : prod.DefaultFirebaseOptions.currentPlatform;
      
  await Firebase.initializeApp(options: firebaseOptions);
  
  final query = await FirebaseFirestore.instance
      .collection('users')
      .doc(AppConfig.sharedWorkspaceId)
      .collection('clients')
      .get();
      
  print('--- CLIENTS IN WORKSPACE: ${AppConfig.sharedWorkspaceId} ---');
  for (final doc in query.docs) {
     print('Client ID: ${doc.id}');
     print('Email: ${doc.data()['email']}');
     print('Name: ${doc.data()['firstName']} ${doc.data()['lastName']}');
     print('--------------------');
  }
}
