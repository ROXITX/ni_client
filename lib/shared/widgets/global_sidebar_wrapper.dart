import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; // DB Access for actions
import 'package:package_info_plus/package_info_plus.dart'; 
import '../../features/dashboard/bloc/dashboard_bloc.dart';
import '../../features/dashboard/widgets/month_view_sidebar.dart';
import '../../models/client.dart';
import '../../models/session.dart';
import '../../features/dashboard/widgets/dashboard_dialogs.dart'; 
import 'main_scaffold.dart'; // For viewNotifier

class GlobalSidebarWrapper extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  
  const GlobalSidebarWrapper({
    super.key, 
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<GlobalSidebarWrapper> createState() => _GlobalSidebarWrapperState();
}

class _GlobalSidebarWrapperState extends State<GlobalSidebarWrapper> with TickerProviderStateMixin {
  // RIGHT Sidebar (Monthly)
  late AnimationController _rightSidebarController;
  late ValueNotifier<bool> _rightSidebarVisible;
  
  // LEFT Sidebar (Menu)
  late AnimationController _leftSidebarController;
  late ValueNotifier<bool> _leftSidebarVisible; // To control visibility logic if needed

  // State for gestures
  bool _isDraggingRight = false;
  bool _isDraggingLeft = false;
  double _dragStartGlobalX = 0.0;
  double _dragStartControllerValue = 0.0;
  
  // Popup state
  bool _sidebarInteractiveActive = false;

  @override
  void initState() {
    super.initState();
    // Right Sidebar Setup
    _rightSidebarVisible = ValueNotifier<bool>(false);
    _rightSidebarController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _rightSidebarController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) _rightSidebarVisible.value = false;
    });

    // Left Sidebar Setup
    _leftSidebarVisible = ValueNotifier<bool>(false); // Unused currently but good for structure
    _leftSidebarController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _rightSidebarController.dispose();
    _rightSidebarVisible.dispose();
    _leftSidebarController.dispose();
    _leftSidebarVisible.dispose();
    super.dispose();
  }

  Future<void> _handleSessionAction(BuildContext context, Session session, String action, List<Client> clients, List<Session> allSessions) async {
       if (action == 'Upcoming' || action == 'Pending') {
           final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'mvp_user';
           final querySnapshot = await FirebaseFirestore.instance
               .collection('users').doc(userId).collection('sessions')
               .where('id', isEqualTo: session.id)
               .limit(1)
               .get();

           if (querySnapshot.docs.isNotEmpty) {
             await querySnapshot.docs.first.reference.update({'status': action});
           }
           return;
       }
       
       if (!context.mounted) return;
       
       if (action == 'Completed' || action == 'Cancelled') {
           showFeedbackDialog(context, session: session, mode: action, clients: clients);
       } else if (action == 'Postpone') {
           showPostponeDialog(context, session: session, allSessions: allSessions, clients: clients);
       } else if (action == 'Edit/View Details') {
           showFeedbackDialog(context, session: session, mode: 'View', clients: clients);
       }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // 1. Auth Guard: If no user (Login Page), disable sidebars completely.
        if (!authSnapshot.hasData) {
          return widget.child;
        }

        // 2. Authenticated: Show Sidebars
        return BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            List<Client> clients = [];
            List<Session> sessions = [];
            if (state is DashboardLoaded) {
              clients = state.clients;
              sessions = state.sessions;
            }
            
            // Calculate safe top area to avoid blocking Hamburger/Back buttons
            // Header is inside SafeArea so it starts after padding.top. 
            // We add extra buffer (100 total) to ensure "fat finger" taps on header don't trigger swipe.
            final double topPadding = MediaQuery.of(context).padding.top; 
            final double detectorTop = topPadding + 220; 

            return Stack(
              children: [
                // 1. The App Content (Navigator)
                widget.child,

                // 2. Gesture Detectors (Edge Swipes)
                // Left Edge Detector (Sidebar Menu)
                Positioned(
                  left: 0, top: detectorTop, bottom: 0, width: 45,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (d) => _startDrag(d, isLeft: true),
                    onHorizontalDragUpdate: (d) => _updateDrag(d, isLeft: true),
                    onHorizontalDragEnd: (d) => _endDrag(d, isLeft: true),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                
                // Right Edge Detector (Monthly Calendar)
                Positioned(
                  right: 0, top: detectorTop, bottom: 0, width: 45,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (d) => _startDrag(d, isLeft: false),
                    onHorizontalDragUpdate: (d) => _updateDrag(d, isLeft: false),
                    onHorizontalDragEnd: (d) => _endDrag(d, isLeft: false),
                    child: Container(color: Colors.transparent),
                  ),
                ),

                 // 3. RIGHT SIDEBAR (Monthly View)
                 AnimatedBuilder(
                  animation: _rightSidebarController,
                  builder: (context, child) {
                    if (_rightSidebarController.value == 0) return const SizedBox.shrink();
                    
                    final double slide = 300.0 * (1.0 - _rightSidebarController.value);
                    
                    return Stack(
                       children: [
                          // Backdrop
                          GestureDetector(
                            onTap: () => _rightSidebarController.reverse(),
                            child: Container(color: Colors.black.withOpacity(0.5 * _rightSidebarController.value)),
                          ),
                          
                          // Sidebar Content
                          Positioned(
                             right: 0, top: 0, bottom: 0, width: 300,
                             child: Transform.translate(
                                offset: Offset(slide, 0),
                                child: GestureDetector(
                                   onHorizontalDragStart: (d) => _startDrag(d, isLeft: false),
                                   onHorizontalDragUpdate: (d) => _updateDrag(d, isLeft: false),
                                   onHorizontalDragEnd: (d) => _endDrag(d, isLeft: false),
                                   child: MonthlySidebar(
                                      clients: clients,
                                      sessions: sessions,
                                      onClose: () => _rightSidebarController.reverse(),
                                      onSessionAction: (s, a) => _handleSessionAction(context, s, a, clients, sessions),
                                      onInteractiveStart: () => _sidebarInteractiveActive = true,
                                      onInteractiveEnd: () => _sidebarInteractiveActive = false,
                                   ),
                                ),
                             ),
                          ),
                       ],
                    );
                  },
                ),

                 // 4. LEFT SIDEBAR (Global Menu)
                 AnimatedBuilder(
                  animation: _leftSidebarController,
                  builder: (context, child) {
                    if (_leftSidebarController.value == 0) return const SizedBox.shrink();
                    final width = MediaQuery.of(context).size.width * 0.75;
                    return Stack(
                      children: [
                        // Backdrop
                        GestureDetector(
                          onTap: () => _leftSidebarController.reverse(),
                          child: Container(color: Colors.black.withOpacity(0.5 * _leftSidebarController.value)),
                        ),
                        // Menu
                        Positioned(
                          left: 0, top: 0, bottom: 0, width: width,
                          child: Transform.translate(
                             offset: Offset(width * (_leftSidebarController.value - 1), 0),
                             child: Material(
                               elevation: 16,
                               color: Colors.white,
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
                                         _buildGlobalMenuItem(context, '📊 Dashboard', 'dashboard'),
                                         _buildGlobalMenuItem(context, '🗓️ Weekly View', 'weekly'),
                                         _buildGlobalMenuItem(context, '📆 Monthly View', 'monthly'),
                                         const Divider(),
                                         _buildGlobalMenuItem(context, '📚 My Courses', 'courses'),
                                         _buildGlobalMenuItem(context, '💰 Payment Dues', 'paymentManagement'),
                                         _buildGlobalMenuItem(context, '👤 My Profile', 'profile'),
                                         const Divider(),
                                         ListTile(
                                           leading: const Icon(Icons.logout, color: Color(0xFF6B7280)),
                                           title: const Text('Logout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                           onTap: () {
                                              _leftSidebarController.reverse();
                                              FirebaseAuth.instance.signOut();
                                           },
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
                                             if (!snapshot.hasData) return const Text('Version info...', style: TextStyle(fontSize: 12, color: Colors.grey));
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
                             ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

              ],
            );
          },
        );
      },
    );
  }

  void _startDrag(DragStartDetails details, {required bool isLeft}) {
    if (_sidebarInteractiveActive) return;
    
    if (isLeft) {
      _isDraggingLeft = true;
      _dragStartGlobalX = details.globalPosition.dx;
      _dragStartControllerValue = _leftSidebarController.value;
    } else {
      _isDraggingRight = true;
      _dragStartGlobalX = details.globalPosition.dx;
      _dragStartControllerValue = _rightSidebarController.value;
      _rightSidebarVisible.value = true; // Ensure logic knows it's active
    }
  }

  void _updateDrag(DragUpdateDetails details, {required bool isLeft}) {
    final dragDelta = details.globalPosition.dx - _dragStartGlobalX;
    
    if (isLeft && _isDraggingLeft) {
       final width = MediaQuery.of(context).size.width * 0.75;
       double newVal = _dragStartControllerValue + (dragDelta / width);
       _leftSidebarController.value = newVal.clamp(0.0, 1.0);
    } else if (!isLeft && _isDraggingRight) {
       final width = 300.0; // Sidebar width
       double newVal = _dragStartControllerValue - (dragDelta / width);
       _rightSidebarController.value = newVal.clamp(0.0, 1.0);
    }
  }

  void _endDrag(DragEndDetails details, {required bool isLeft}) {
     final velocity = details.primaryVelocity ?? 0.0;
     
     if (isLeft && _isDraggingLeft) {
       _isDraggingLeft = false;
       if (velocity > 500 || _leftSidebarController.value > 0.5) {
         _leftSidebarController.forward();
       } else {
         _leftSidebarController.reverse();
       }
     } else if (!isLeft && _isDraggingRight) {
       _isDraggingRight = false;
       if (velocity < -500 || _rightSidebarController.value > 0.5) {
         _rightSidebarController.forward();
       } else {
         _rightSidebarController.reverse();
       }
     }
  }
  Widget _buildGlobalMenuItem(BuildContext context, String title, String viewId) {
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
            _leftSidebarController.reverse(); // Close sidebar first
            
            // 1. Update State
            MainScaffold.viewNotifier.value = viewId;
            
            // 2. Navigation Reset
            // If we are deep in stack (e.g. Client Details), pop to root (MainScaffold).
            // If we are already at root, this does nothing, which is correct (viewNotifier handles update).
            widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
          },
        );
      },
    );
  }
}
