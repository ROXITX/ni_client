// Manual fix script for session status
// This will directly update sessions 812 and 813 from Pending to Upcoming
// Run with: flutter run fix_sessions.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  print('🔧 Manual Session Status Fix Script');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final firestore = FirebaseFirestore.instance;
  final sessionsRef = firestore.collection('sessions').withConverter<Map<String, dynamic>>(
    fromFirestore: (snapshot, _) => snapshot.data()!,
    toFirestore: (data, _) => data,
  );
  
  // Check and fix specific sessions
  await fixSession(sessionsRef, '812');
  await fixSession(sessionsRef, '813');
  
  print('✅ Session fix complete!');
}

Future<void> fixSession(CollectionReference<Map<String, dynamic>> sessionsRef, String sessionId) async {
  try {
    print('\n🔍 Checking session $sessionId...');
    
    final doc = await sessionsRef.doc(sessionId).get();
    if (!doc.exists) {
      print('❌ Session $sessionId not found');
      return;
    }
    
    final data = doc.data()!;
    final currentStatus = data['status'] as String?;
    final sessionDate = data['date'] as String?;
    final sessionTime = data['time'] as String?;
    
    print('📊 Current status: $currentStatus');
    print('📅 Date: $sessionDate');
    print('⏰ Time: $sessionTime');
    
    if (currentStatus == 'Pending' && sessionDate != null) {
      // Check if this is a future session
      try {
        final parsedDate = DateTime.parse(sessionDate);
        final now = DateTime.now();
        
        if (parsedDate.isAfter(now)) {
          print('🔧 Session $sessionId is in the future but marked as Pending - fixing to Upcoming');
          
          await sessionsRef.doc(sessionId).update({
            'status': 'Upcoming',
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          print('✅ Session $sessionId updated to Upcoming');
        } else {
          print('✅ Session $sessionId is correctly marked as Pending (past date)');
        }
      } catch (e) {
        print('❌ Error parsing date for session $sessionId: $e');
      }
    } else if (currentStatus == 'Upcoming') {
      print('✅ Session $sessionId is already marked as Upcoming');
    } else {
      print('ℹ️ Session $sessionId status: $currentStatus (no change needed)');
    }
  } catch (e) {
    print('❌ Error processing session $sessionId: $e');
  }
}