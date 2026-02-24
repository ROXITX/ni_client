class AppConfig {
  // --- ENVIRONMENT CONFIG ---
  
  /// Toggle this to TRUE to use the Testing Database.
  /// Toggle this to FALSE to use the Live Production Database.
  /// 
  /// location: lib/firebase_options_dev.dart (Test) vs lib/firebase_options.dart (Prod)
  static const bool useTestDatabase = true; 

  // --- UNIFIED VIEW CONFIG ---

  /// The Master User ID whose data will be shared with ALL logged-in users.
  /// 
  /// INSTRUCTIONS:
  /// 1. Go to Firebase Console -> Authentication.
  /// 2. Find your MAIN account (the one with the data you want to share).
  /// 3. Copy the "User UID" string.
  /// 4. Paste it below to replace 'REPLACE_WITH_YOUR_MAIN_USER_UID'.
  static const String sharedWorkspaceId = 'oxs3ec0udCM2j3rK4CVIEe68kWw2';
}
