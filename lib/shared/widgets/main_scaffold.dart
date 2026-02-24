import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Feature Screens
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/sessions/screens/weekly_view_screen.dart';
import '../../features/sessions/screens/monthly_view_screen.dart';
import '../../features/payments/screens/payment_management_screen.dart';
import '../../features/auth/screens/change_password_screen.dart'; // NEW
import '../../features/profile/screens/profile_screen.dart'; // NEW
import '../../features/courses/screens/course_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Widgets
import '../../features/dashboard/bloc/dashboard_bloc.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  
  static final ValueNotifier<String> viewNotifier = ValueNotifier('dashboard');

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    context.read<DashboardBloc>().add(DashboardSubscriptionRequested());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstLogin());
  }

  Future<void> _checkFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('prompt_password_change') == true) {
      if (mounted) {
         Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen(isFirstLogin: true)));
      }
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _closeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      if (mounted) {
         context.read<DashboardBloc>().add(DashboardMarkNotificationsRead());
      }
    }
  }

  void _toggleNotifications(List<Map<String, dynamic>> notifications) {
    if (_overlayEntry != null) {
      _closeOverlay();
    } else {
      _overlayEntry = _createOverlayEntry(notifications);
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  OverlayEntry _createOverlayEntry(List<Map<String, dynamic>> notifications) {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // 1. Transparent Backdrop to catch clicks
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeOverlay,
              child: Container(color: Colors.transparent),
            ),
          ),
          // 2. The Dropdown
          Positioned(
            width: 320,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-280, 50),
              child: Material(
                elevation: 0, 
                color: Colors.transparent,
                child: Container(
                  height: 250, // Fixed height as requested
                  decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(16),
                     color: Colors.white,
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.15),
                         blurRadius: 20,
                         offset: const Offset(0, 10),
                       )
                     ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Gradient
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Notifications', 
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.white
                              )
                            ),
                            GestureDetector(
                              onTap: _closeOverlay,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 16, color: Colors.white),
                              ),
                            )
                          ],
                        ),
                      ),
                      // List - Expanded to fill remaining fixed space
                      Expanded(
                        child: notifications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No new notifications', 
                                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                final message = notification['message'] as String;
                                final dynamic id = notification['id']; // Can be int (Session) or String (Payment)
                                final isRead = notification['read'] as bool? ?? false;
                                final type = notification['type'] as String? ?? 'session';

                                // Mark as read when rendered (viewed) - (Scroll-through)
                                if (!isRead) {
                                  Future.delayed(Duration.zero, () {
                                     if (context.mounted) {
                                         if (type == 'session' && id is int) {
                                            context.read<DashboardBloc>().add(DashboardMarkNotificationsRead(sessionIds: [id]));
                                         } else if (type == 'payment' && id is String) {
                                            context.read<DashboardBloc>().add(DashboardMarkNotificationsRead(paymentIds: [id]));
                                         }
                                     }
                                  });
                                }

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _closeOverlay,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: isRead ? Colors.grey[100] : const Color(0xFFEFF6FF), // Light blue bg for unread
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.info_rounded, 
                                              color: isRead ? Colors.grey[400] : const Color(0xFF3B82F6), 
                                              size: 16
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              message, 
                                              style: TextStyle(
                                                fontSize: 13, 
                                                color: isRead ? const Color(0xFF9CA3AF) : const Color(0xFF374151), 
                                                height: 1.4
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
                      if (notifications.isNotEmpty)
                         InkWell(
                           onTap: _closeOverlay,
                           child: Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(12),
                             decoration: const BoxDecoration(
                                color: Color(0xFFF9FAFB),
                                border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
                             ),
                             child: const Center(
                               child: Text(
                                 'Mark all as read',
                                 style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                               ),
                             ),
                           ),
                         )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.15,
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
             _buildHeader(),
             Container(height: 1, color: const Color(0xFFE5E7EB)),
             Expanded(
               child: ValueListenableBuilder<String>(
                 valueListenable: MainScaffold.viewNotifier,
                 builder: (context, currentView, _) {
                   return _buildBody(currentView);
                 },
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String currentView) {
    switch (currentView) {
      case 'dashboard': return DashboardScreen(username: FirebaseAuth.instance.currentUser?.email ?? '');
      case 'weekly': return const WeeklyViewScreen();
      case 'monthly': return const MonthlyViewScreen();
      case 'courses': return CourseListScreen();
      case 'profile': return const ProfileScreen();
      case 'paymentManagement': return PaymentManagementScreen(); 
      default: return DashboardScreen(username: FirebaseAuth.instance.currentUser?.email ?? '');
    }
  }

  Widget _buildHeader() {
     return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              IconButton(
                 icon: const Icon(Icons.menu, size: 28),
                 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const Image(image: AssetImage('assets/loginpagelogo.png'), height: 70),
              BlocBuilder<DashboardBloc, DashboardState>(
                builder: (context, state) {
                  final notifications = (state is DashboardLoaded) ? state.notifications : <Map<String, dynamic>>[];
                  final hasNotifications = notifications.any((n) => !(n['read'] as bool? ?? false));
                  
                  return CompositedTransformTarget(
                    link: _layerLink,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                         IconButton(
                           icon: const Icon(Icons.notifications_outlined, size: 28), 
                           onPressed: () => _toggleNotifications(notifications),
                         ),
                         if (hasNotifications)
                           Positioned(
                             right: 8,
                             top: 8,
                             child: Container(
                               padding: const EdgeInsets.all(4),
                               decoration: const BoxDecoration(
                                 color: Colors.red,
                                 shape: BoxShape.circle,
                               ),
                               constraints: const BoxConstraints(
                                 minWidth: 8,
                                 minHeight: 8,
                               ),
                             ),
                           ),
                      ],
                    ),
                  );
                },
              )
           ],
        ),
     );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Image.asset('assets/loginpagelogo.png', height: 80, fit: BoxFit.contain),
                  ),
                ),
                _menuItem('📊 Dashboard', 'dashboard'),
                _menuItem('🗓️ Weekly View', 'weekly'),
                _menuItem('📆 Monthly View', 'monthly'),
                const Divider(),
                _menuItem('📚 My Courses', 'courses'),
                _menuItem('💰 Payment Dues', 'paymentManagement'),
                _menuItem('👤 My Profile', 'profile'),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Color(0xFF6B7280)),
                  title: const Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                   if (!snapshot.hasData) return const Text('Version info loading...', style: TextStyle(fontSize: 12, color: Colors.grey));
                   final info = snapshot.data!;
                   return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         const Text('Version', style: TextStyle(fontSize: 12, color: Colors.grey)),
                         Text('${info.version} (Build ${info.buildNumber})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                   );
                },
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _menuItem(String title, String viewId) {
    return ValueListenableBuilder<String>(
      valueListenable: MainScaffold.viewNotifier,
      builder: (context, currentView, _) {
        final bool isSelected = currentView == viewId;
        return ListTile(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF374151),
            ),
          ),
          selected: isSelected,
          selectedTileColor: const Color(0xFFFFFBEB),
          onTap: () {
            MainScaffold.viewNotifier.value = viewId;
            Navigator.pop(context); // Close drawer
          },
        );
      },
    );
  }

}
