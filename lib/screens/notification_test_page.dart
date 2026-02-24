// import 'package:flutter/material.dart';
// import 'package:timezone/timezone.dart' as tz;
// import '../services/notification_service.dart';

// class NotificationTestWidget extends StatefulWidget {
//   const NotificationTestWidget({super.key});

//   @override
//   State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
// }

// class _NotificationTestWidgetState extends State<NotificationTestWidget> {
//   final NotificationService _notificationService = NotificationService();
//   final List<String> _testResults = [];

//   @override
//   void initState() {
//     super.initState();
//     _initializeAndTest();
//   }

//   Future<void> _initializeAndTest() async {
//     await _notificationService.init();
//     await _runNotificationTests();
//   }

//   Future<void> _runNotificationTests() async {
//     setState(() {
//       _testResults.clear();
//       _testResults.add('🧪 Starting Notification System Tests...\n');
//     });

//     // Test 1: Check basic notification permissions
//     await _testNotificationPermissions();
    
//     // Test 2: Check timezone handling
//     await _testTimezoneHandling();
    
//     // Test 3: Test notification scheduling for specific times
//     await _testNotificationScheduling();
    
//     // Test 4: Test 7 AM daily summary logic
//     await _test7AMSummaryLogic();
    
//     // Test 5: Test 2-hour and 5-minute reminders
//     await _testSessionReminders();

//     setState(() {
//       _testResults.add('\n✅ All notification tests completed!');
//     });
//   }

//   Future<void> _testNotificationPermissions() async {
//     setState(() {
//       _testResults.add('📱 Testing notification permissions...');
//     });

//     try {
//       final permissionsEnabled = await _notificationService.areNotificationsEnabled();
//       setState(() {
//         _testResults.add(permissionsEnabled 
//           ? '✅ iOS & Android permissions: ENABLED' 
//           : '❌ iOS & Android permissions: DISABLED');
//       });
//     } catch (e) {
//       setState(() {
//         _testResults.add('❌ Permission check failed: $e');
//       });
//     }
//   }

//   Future<void> _testTimezoneHandling() async {
//     setState(() {
//       _testResults.add('\n🌍 Testing timezone handling...');
//     });

//     try {
//       final now = tz.TZDateTime.now(tz.local);
//       setState(() {
//         _testResults.add('✅ Current timezone: ${tz.local.name}');
//         _testResults.add('✅ Current time: $now');
//       });
//     } catch (e) {
//       setState(() {
//         _testResults.add('❌ Timezone initialization failed: $e');
//       });
//     }
//   }

//   Future<void> _testNotificationScheduling() async {
//     setState(() {
//       _testResults.add('\n⏰ Testing notification scheduling...');
//     });

//     try {
//       final now = tz.TZDateTime.now(tz.local);
      
//       // Test scheduling a notification 10 seconds from now
//       final testTime = now.add(const Duration(seconds: 10));
//       await _notificationService.scheduleZonedNotification(
//         id: 99999,
//         title: '🧪 Test Scheduled Notification',
//         body: 'This notification was scheduled 10 seconds ago!',
//         scheduledTime: testTime,
//       );

//       setState(() {
//         _testResults.add('✅ Test notification scheduled for: $testTime');
//         _testResults.add('   (Check your device in 10 seconds)');
//       });
//     } catch (e) {
//       setState(() {
//         _testResults.add('❌ Notification scheduling failed: $e');
//       });
//     }
//   }

//   Future<void> _test7AMSummaryLogic() async {
//     setState(() {
//       _testResults.add('\n🌅 Testing 7 AM summary logic...');
//     });

//     try {
//       final now = tz.TZDateTime.now(tz.local);
//       var scheduled7AM = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7);
      
//       // If it's already past 7 AM today, schedule for tomorrow
//       if (now.isAfter(scheduled7AM)) {
//         scheduled7AM = scheduled7AM.add(const Duration(days: 1));
//       }

//       setState(() {
//         _testResults.add('✅ Current time: ${now.hour}:${now.minute.toString().padLeft(2, '0')}');
//         _testResults.add('✅ Next 7 AM summary: $scheduled7AM');
//         _testResults.add(now.isAfter(tz.TZDateTime(tz.local, now.year, now.month, now.day, 7))
//           ? '   (Today is past 7 AM, scheduled for tomorrow)'
//           : '   (Scheduled for today)');
//       });
//     } catch (e) {
//       setState(() {
//         _testResults.add('❌ 7 AM logic test failed: $e');
//       });
//     }
//   }

//   Future<void> _testSessionReminders() async {
//     setState(() {
//       _testResults.add('\n⏰ Testing session reminder timing...');
//     });

//     try {
//       // Test with a simulated session 3 hours from now
//       final now = tz.TZDateTime.now(tz.local);
//       final sessionTime = now.add(const Duration(hours: 3));
      
//       // Calculate reminder times
//       final twoHourReminder = sessionTime.subtract(const Duration(hours: 2));
//       final fiveMinReminder = sessionTime.subtract(const Duration(minutes: 5));

//       setState(() {
//         _testResults.add('✅ Simulated session time: ${sessionTime.hour}:${sessionTime.minute.toString().padLeft(2, '0')}');
//         _testResults.add('✅ 2-hour reminder would be at: ${twoHourReminder.hour}:${twoHourReminder.minute.toString().padLeft(2, '0')}');
//         _testResults.add('✅ 5-minute reminder would be at: ${fiveMinReminder.hour}:${fiveMinReminder.minute.toString().padLeft(2, '0')}');
        
//         // Check if reminders would be scheduled correctly
//         if (twoHourReminder.isAfter(now)) {
//           _testResults.add('✅ 2-hour reminder: WOULD BE SCHEDULED');
//         } else {
//           _testResults.add('⚠️ 2-hour reminder: TOO LATE TO SCHEDULE');
//         }
        
//         if (fiveMinReminder.isAfter(now)) {
//           _testResults.add('✅ 5-minute reminder: WOULD BE SCHEDULED');
//         } else {
//           _testResults.add('⚠️ 5-minute reminder: TOO LATE TO SCHEDULE');
//         }
//       });

//       // Test actual scheduling of reminders
//       if (twoHourReminder.isAfter(now)) {
//         await _notificationService.scheduleZonedNotification(
//           id: 88888,
//           title: '🧪 Test 2-Hour Reminder',
//           body: 'This is a test 2-hour session reminder',
//           scheduledTime: twoHourReminder,
//         );
//         setState(() {
//           _testResults.add('✅ 2-hour test reminder scheduled successfully');
//         });
//       }

//       if (fiveMinReminder.isAfter(now)) {
//         await _notificationService.scheduleZonedNotification(
//           id: 77777,
//           title: '🧪 Test 5-Minute Reminder',
//           body: 'This is a test 5-minute session reminder',
//           scheduledTime: fiveMinReminder,
//         );
//         setState(() {
//           _testResults.add('✅ 5-minute test reminder scheduled successfully');
//         });
//       }

//     } catch (e) {
//       setState(() {
//         _testResults.add('❌ Session reminder test failed: $e');
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Notification Tests'),
//         backgroundColor: const Color(0xFF1E88E5),
//         foregroundColor: Colors.white,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: _runNotificationTests,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFF22C55E),
//                       foregroundColor: Colors.white,
//                     ),
//                     child: const Text('Run Tests Again'),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: ElevatedButton(
//                     onPressed: () async {
//                       await _notificationService.showImmediateNotification(
//                         id: 12345,
//                         title: '🧪 Immediate Test',
//                         body: 'This is an immediate notification test',
//                       );
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: const Color(0xFFF59E0B),
//                       foregroundColor: Colors.white,
//                     ),
//                     child: const Text('Test Now'),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Expanded(
//               child: Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.black,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.grey),
//                 ),
//                 child: SingleChildScrollView(
//                   child: Text(
//                     _testResults.join('\n'),
//                     style: const TextStyle(
//                       color: Colors.green,
//                       fontFamily: 'monospace',
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }