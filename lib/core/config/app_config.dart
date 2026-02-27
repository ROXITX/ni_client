import 'package:flutter/foundation.dart'; // Added for ValueNotifier

class AppConfig {
  // --- ENVIRONMENT CONFIG ---
  
  /// Toggle this to TRUE to use the Testing Database.
  /// Toggle this to FALSE to use the Live Production Database.
  /// 
  /// location: lib/firebase_options_dev.dart (Test) vs lib/firebase_options.dart (Prod)
  static const bool useTestDatabase = true; 

  /// ValueNotifier to prevent AuthGate from navigating to MainScaffold 
  /// while a new user's Firestore authorization is being verified.
  static final ValueNotifier<bool> isVerifyingNewUser = ValueNotifier<bool>(false);

  // --- UNIFIED VIEW CONFIG ---

  /// The Workspace ID for the Production Database
  static const String _prodWorkspaceId = 'oxs3ec0udCM2j3rK4CVIEe68kWw2';
  
  /// The Workspace ID for the Test Database
  /// REPLACE this string with your actual Test Admin UID from the Firebase Console 
  static const String _testWorkspaceId = 'oxs3ec0udCM2j3rK4CVIEe68kWw2';

  /// Automatically retrieves the correct Workspace ID based on the environment.
  static String get sharedWorkspaceId
  {
    return useTestDatabase ? _testWorkspaceId : _prodWorkspaceId;
  }
}
