import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart'; // For RepositoryProvider

import 'firebase_options.dart';
import 'firebase_options_dev.dart'; // NEW
import 'core/config/app_config.dart'; // NEW
import 'core/theme/app_theme.dart';
import 'shared/data/appointment_repository.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/fcm_service.dart';
import 'shared/widgets/main_scaffold.dart';
import 'shared/widgets/global_sidebar_wrapper.dart';

// Feature screens
import 'features/auth/screens/login_page.dart';

// BLoCs
import 'features/clients/bloc/clients_bloc.dart';
import 'features/sessions/bloc/sessions_bloc.dart';
import 'features/dashboard/bloc/dashboard_bloc.dart';
import 'features/scheduling/bloc/scheduling_bloc.dart';
import 'features/courses/bloc/courses_bloc.dart';

import 'features/payments/data/payment_repository.dart';
import 'features/payments/bloc/payments_bloc.dart';

// ... existing imports ...

// Background handler
import 'package:firebase_messaging/firebase_messaging.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final firebaseOptions = AppConfig.useTestDatabase 
      ? DevFirebaseOptions.currentPlatform 
      : DefaultFirebaseOptions.currentPlatform;
  await Firebase.initializeApp(options: firebaseOptions);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with Dual DB Support
  final firebaseOptions = AppConfig.useTestDatabase 
      ? DevFirebaseOptions.currentPlatform 
      : DefaultFirebaseOptions.currentPlatform;
      
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: firebaseOptions,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate-app')) {
        rethrow;
      }
    }
  }

  // Initialize notifications
  final notificationService = NotificationService();
  
  // Background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(MvpApp(notificationService: notificationService));

  // Initialize notifications and FCM AFTER runApp to prevent system permission 
  // dialogs from blocking the first Flutter frame and causing a black screen.
  Future.delayed(const Duration(milliseconds: 500), () async {
    // Debug Print: Tell us exactly which database we connected to!
    print('\n\n==================================================');
    print('🔥 FIREBASE INITIALIZED SUCCESSFULLY 🔥');
    print('   CONNECTED TO: ${Firebase.app().options.projectId}');
    print('   ENVIRONMENT: ${AppConfig.useTestDatabase ? "TEST" : "PRODUCTION"}');
    print('   WORKSPACE ID: ${AppConfig.sharedWorkspaceId}');
    print('==================================================\n\n');

    await notificationService.init();
    final fcmService = FCMService();
    await fcmService.initialize();
  });
}

class MvpApp extends StatelessWidget {
  final NotificationService notificationService;

  const MvpApp({
    super.key,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
       providers: [
          RepositoryProvider(create: (context) => AppointmentRepository()),
          RepositoryProvider(create: (context) => PaymentRepository()), // Added here
          RepositoryProvider.value(value: notificationService),
       ],
       child: MultiBlocProvider(
          providers: [
             BlocProvider(create: (context) => ClientsBloc(repository: context.read<AppointmentRepository>())..add(ClientsSubscriptionRequested())),
             BlocProvider(create: (context) => SessionsBloc(
                repository: context.read<AppointmentRepository>(),
                notificationService: context.read<NotificationService>(),
             )..add(SessionsSubscriptionRequested())),
             BlocProvider(
                 create: (context) => DashboardBloc(
                    repository: context.read<AppointmentRepository>(),
                    paymentRepository: context.read<PaymentRepository>(), // NEW
                    notificationService: context.read<NotificationService>(),
                 )..add(DashboardSubscriptionRequested()),
                 lazy: false,
             ),
             BlocProvider(create: (context) => CoursesBloc(repository: context.read<AppointmentRepository>())..add(CoursesSubscriptionRequested())),
             BlocProvider(create: (context) => SchedulingBloc(repository: context.read<AppointmentRepository>())..add(SchedulingSubscriptionRequested())),
             BlocProvider(create: (context) => PaymentsBloc(repository: context.read<PaymentRepository>())), // Added Bloc here
          ],
          child: MaterialApp(
             navigatorKey: navigatorKey,
             title: 'Nurturing Institute',
             theme: AppTheme.lightTheme,
             debugShowCheckedModeBanner: false,
             builder: (context, child) {
                  return GlobalSidebarWrapper(
                    navigatorKey: navigatorKey,
                    child: child!
                  );
                },
             home: const AuthGate(),
          )
       )
    );
  }
}

class AuthGate extends StatelessWidget {
   const AuthGate({super.key});
   
   @override
   Widget build(BuildContext context) {
      return ValueListenableBuilder<bool>(
        valueListenable: AppConfig.isVerifyingNewUser,
        builder: (context, isVerifying, child) {
          return StreamBuilder<User?>(
             stream: FirebaseAuth.instance.authStateChanges(),
             builder: (context, snapshot) {
                // If we have a user and we are NOT currently verifying a new auth account, show dashboard
                if (snapshot.hasData && !isVerifying) {
                   return const MainScaffold();
                }
                // Otherwise show login (or keep showing login while verifying)
                return const LoginPage();
             },
          );
        },
      );
   }
}
