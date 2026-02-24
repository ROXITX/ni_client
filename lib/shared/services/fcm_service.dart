import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM service with proper token handling
  Future<void> initialize() async {
    try {
      print('🔥 Initializing FCM Service...');

      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      print('📱 FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ FCM notifications authorized');
        
        // Get FCM token
        await _getFCMToken();
        
        // Listen for token refresh
        _firebaseMessaging.onTokenRefresh.listen(_updateFCMToken);
        
        // Setup message handlers
        _setupMessageHandlers();
        
      } else {
        print('❌ FCM notifications not authorized');
      }
    } catch (e) {
      print('❌ FCM initialization error: $e');
    }
  }

  /// Get and store FCM token
  Future<void> _getFCMToken() async {
    try {
      // For iOS simulator, FCM tokens are not available
      if (defaultTargetPlatform == TargetPlatform.iOS && kDebugMode) {
        print('⚠️ iOS Simulator detected - FCM token not available');
        return;
      }

      _fcmToken = await _firebaseMessaging.getToken();
      
      if (_fcmToken != null) {
        print('✅ FCM Token obtained: ${_fcmToken!.substring(0, 20)}...');
        await _storeFCMToken(_fcmToken!);
      } else {
        print('⚠️ FCM Token is null');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Store FCM token in Firestore for server-side messaging
  Future<void> _storeFCMToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform.name,
        }, SetOptions(merge: true));
        
        print('✅ FCM token stored in Firestore');
      }
    } catch (e) {
      print('❌ Error storing FCM token: $e');
    }
  }

  /// Update FCM token when it refreshes
  Future<void> _updateFCMToken(String token) async {
    print('🔄 FCM token refreshed');
    _fcmToken = token;
    await _storeFCMToken(token);
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Handle background messages (app terminated)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages (app open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Foreground message received: ${message.notification?.title}');
      _handleForegroundMessage(message);
    });

    // Handle notification tap (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from notification: ${message.notification?.title}');
      _handleNotificationTap(message);
    });
  }

  /// Handle messages when app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    // You can show a local notification or update UI
    print('📨 Foreground message data: ${message.data}');
    
    // Extract session information if available
    final sessionId = message.data['sessionId'];
    if (sessionId != null) {
      // Update session status in Firestore to show red dot
      _updateSessionForNotification(sessionId);
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped with data: ${message.data}');
    
    // Navigate to appropriate screen based on message data
    final sessionId = message.data['sessionId'];
    if (sessionId != null) {
      // You can implement navigation logic here
      _updateSessionForNotification(sessionId);
    }
  }

  /// Update session when notification is received
  Future<void> _updateSessionForNotification(String sessionId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(sessionId)
            .update({'read': false, 'notificationReceived': true});
        
        print('✅ Session $sessionId marked as unread for notification');
      }
    } catch (e) {
      print('❌ Error updating session for notification: $e');
    }
  }

  /// Send notification to a specific user (requires server endpoint)
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token from Firestore
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) {
        print('❌ No FCM token found for user $userId');
        return false;
      }

      // Send notification via FCM
      return await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: data ?? {},
      );
    } catch (e) {
      print('❌ Error sending notification to user: $e');
      return false;
    }
  }

  /// Send FCM notification using HTTP API
  Future<bool> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Note: In production, this should be done on your server/Cloud Function
      // This is a simplified version for demonstration
      
      const String serverKey = 'YOUR_SERVER_KEY'; // You need to get this from Firebase Console
      
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'to': token,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
            'badge': '1',
          },
          'data': data,
          'priority': 'high',
          'android': {
            'notification': {
              'channel_id': 'session_reminders_channel_id',
              'importance': 'max',
              'priority': 'high',
            }
          },
          'apns': {
            'payload': {
              'aps': {
                'sound': 'default',
                'badge': 1,
              }
            }
          }
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM notification sent successfully');
        return true;
      } else {
        print('❌ FCM notification failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending FCM notification: $e');
      return false;
    }
  }

  /// Schedule a notification to be sent at a specific time
  /// Note: This would typically be done on your server with a scheduler
  Future<void> scheduleNotification({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Store scheduled notification in Firestore
      // Your server/Cloud Function would read this and send at the right time
      await _firestore.collection('scheduledNotifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'scheduledTime': Timestamp.fromDate(scheduledTime),
        'data': data ?? {},
        'sent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Notification scheduled for $scheduledTime');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  /// Clear FCM token when user logs out
  Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      }
      _fcmToken = null;
      print('✅ FCM token cleared');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message received: ${message.notification?.title}');
  
  // Handle background notification logic here
  final sessionId = message.data['sessionId'];
  if (sessionId != null) {
    // Update database to show notification was received
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(sessionId)
            .update({'read': false, 'backgroundNotificationReceived': true});
      }
    } catch (e) {
      print('❌ Error handling background notification: $e');
    }
  }
}