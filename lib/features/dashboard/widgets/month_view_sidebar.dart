import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' as intl;
import '../../../models/client.dart';
import '../../../models/session.dart';
import '../../../shared/widgets/session_card.dart';
import '../../../core/utils/date_utils.dart';

class MonthlySidebar extends StatefulWidget {
  final List<Client> clients;
  final List<Session> sessions;
  final Function(Session, String) onSessionAction;
  final VoidCallback onClose;
  final VoidCallback onInteractiveStart;
  final VoidCallback onInteractiveEnd;

  const MonthlySidebar({
    super.key,
    required this.clients,
    required this.sessions,
    required this.onSessionAction,
    required this.onClose,
    required this.onInteractiveStart,
    required this.onInteractiveEnd,
  });

  @override
  State<MonthlySidebar> createState() => _MonthlySidebarState();
}

class _MonthlySidebarState extends State<MonthlySidebar> {
  late ValueNotifier<DateTime> _sidebarMonthlyCursor;
  late ValueNotifier<DateTime> _sidebarMonthlySelected;


  final Map<String, Map<String, dynamic>> statusDetails = {
    'Upcoming': {'color': const Color(0xFF3B82F6), 'icon': Icons.calendar_today_outlined},
    'Pending': {'color': const Color(0xFFF59E0B), 'icon': Icons.hourglass_top_rounded},
    'Completed': {'color': const Color(0xFF22C55E), 'icon': Icons.check_circle_outline},
    'Cancelled': {'color': const Color(0xFFEF4444), 'icon': Icons.cancel_outlined},
  };

  @override
  void initState() {
    super.initState();
    _sidebarMonthlyCursor = ValueNotifier<DateTime>(DateTime.now());
    _sidebarMonthlySelected = ValueNotifier<DateTime>(DateTime.now());
  }

  @override
  void dispose() {
    _sidebarMonthlyCursor.dispose();
    _sidebarMonthlySelected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // print('🎯 Sidebar build completed');
      });
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        child: Container(
          width: 300,
          height: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(4, 0),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Drag handle
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                          // Header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              border: const Border(
                                bottom: BorderSide(color: Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: SafeArea(
                              bottom: false,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDE68A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Color(0xFF92400E),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Monthly Calendar',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF374151),
                                        letterSpacing: 0.2,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: widget.onClose,
                                    icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 22),
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  )
                                ],
                              ),
                            ),
                          ),

                          // Subtle section divider
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: const Color(0xFFE2E8F0),
                          ),

                          // Month navigation
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Prev month
                                _buildNavButton(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: () {
                                    final current = _sidebarMonthlyCursor.value;
                                    _sidebarMonthlyCursor.value = DateTime(
                                      current.year,
                                      current.month - 1,
                                    );
                                    _sidebarMonthlySelected.value = DateTime(
                                      _sidebarMonthlyCursor.value.year,
                                      _sidebarMonthlyCursor.value.month,
                                      1,
                                    );
                                  },
                                ),

                                // Month label
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFDE68A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFBBF24), width: 1),
                                    ),
                                    child: ValueListenableBuilder<DateTime>(
                                      valueListenable: _sidebarMonthlyCursor,
                                      builder: (context, cursor, child) {
                                        return Text(
                                          intl.DateFormat('MMM yyyy').format(cursor),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF92400E),
                                            letterSpacing: 0.2,
                                            decoration: TextDecoration.none,
                                          ),
                                          textAlign: TextAlign.center,
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Next month
                                _buildNavButton(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: () {
                                    final current = _sidebarMonthlyCursor.value;
                                    _sidebarMonthlyCursor.value = DateTime(
                                      current.year,
                                      current.month + 1,
                                    );
                                    _sidebarMonthlySelected.value = DateTime(
                                      _sidebarMonthlyCursor.value.year,
                                      _sidebarMonthlyCursor.value.month,
                                      1,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Monthly view
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAFBFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: ValueListenableBuilder<DateTime>(
                                    valueListenable: _sidebarMonthlyCursor,
                                    builder: (context, cursor, child) {
                                      return _buildSidebarMonthlyView(widget.clients, widget.sessions);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildSidebarMonthlyView(List<Client> clients, List<Session> sessions) {
    const Color borderColor = Color(0xFFE2E8F0);
    const Color textMuted = Color(0xFF64748B);
    const Color textStrong = Color(0xFF1E293B);
    
    DateTime firstOfMonth = DateTime(_sidebarMonthlyCursor.value.year, _sidebarMonthlyCursor.value.month, 1);
    int firstWeekday = firstOfMonth.weekday % 7;
    int daysInMonth = DateTime(_sidebarMonthlyCursor.value.year, _sidebarMonthlyCursor.value.month + 1, 0).day;
    List<DateTime?> grid = [];
    
    for (int i = 0; i < firstWeekday; i++) {
      grid.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      grid.add(DateTime(_sidebarMonthlyCursor.value.year, _sidebarMonthlyCursor.value.month, d));
    }
    while (grid.length % 7 != 0) {
      grid.add(null);
    }

    List<Session> daySessions(DateTime d) {
      final ds = _dateToStr(d);
      return sessions.where((s) => s.date == ds).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Enhanced day headers
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((day) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          
          // Enhanced calendar grid
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth - 16; // Account for padding
                final cellWidth = availableWidth / 7;
                
                return Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (final date in grid)
                      SizedBox(
                        width: cellWidth,
                        height: cellWidth * 0.8, // Aspect ratio for better fit
                        child: date == null
                            ? Container()
                            : ValueListenableBuilder<DateTime>(
                                valueListenable: _sidebarMonthlySelected,
                                builder: (context, selectedDate, child) {
                                  return _sidebarMonthDayTile(
                                    date,
                                    isSelected: _dateToStr(date) == _dateToStr(selectedDate),
                                    sessionCount: sessions.where((s) => s.date == _dateToStr(date)).length,
                                    onTap: () => _sidebarMonthlySelected.value = date,
                                  );
                                },
                              ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Enhanced sessions section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                      ),
                      child: const Icon(
                        Icons.event_rounded,
                        size: 16,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ValueListenableBuilder<DateTime>(
                        valueListenable: _sidebarMonthlySelected,
                        builder: (context, selectedDate, child) {
                          return Text(
                            'Sessions for ${_monthShort(selectedDate.month)} ${selectedDate.day}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textStrong,
                              decoration: TextDecoration.none,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                ValueListenableBuilder<DateTime>(
                  valueListenable: _sidebarMonthlySelected,
                  builder: (context, selectedDate, child) {
                    final sessionsForDay = daySessions(selectedDate);
                    sessionsForDay.sort((a, b) {
                       final startA = AppDateUtils.parseTimeRange(a.time)['start'] ?? 0;
                       final startB = AppDateUtils.parseTimeRange(b.time)['start'] ?? 0;
                       return startA.compareTo(startB);
                    });

                    if (sessionsForDay.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.event_busy_rounded, color: Colors.grey[400], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ValueListenableBuilder<DateTime>(
                                valueListenable: _sidebarMonthlySelected,
                                builder: (context, selectedDate, _) {
                                  final now = DateTime.now();
                                  final isToday = now.year == selectedDate.year && now.month == selectedDate.month && now.day == selectedDate.day;
                                  final msg = isToday ? 'No sessions for today' : 'No sessions for ${_monthShort(selectedDate.month)} ${selectedDate.day}';
                                  return Text(
                                    msg,
                                    style: const TextStyle(
                                      color: textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.none,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: sessionsForDay.map((s) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: SessionCard(
                            session: s,
                            client: clients.firstWhere((c) => c.id == s.clientId, orElse: () => Client(id: 0, firstName: 'Unknown', lastName: '', dob: '', gender: '', email: '', phone: '', occupation: '', description: '')),
                            details: statusDetails[_getRealTimeSessionStatus(s)]!,
                            isDetailed: false, // Compact view for sidebar
                            onActionSelected: widget.onSessionAction,
                            onMenuOpen: () {
                              widget.onInteractiveStart();
                              // setState(() => _sessionPopupOpen = true);
                            },
                            onMenuClose: () {
                              widget.onInteractiveEnd();
                              // setState(() => _sessionPopupOpen = false);
                            },
                            displayStatus: _getRealTimeSessionStatus(s),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
            ],
          ),
        );
  }

  Widget _sidebarMonthDayTile(DateTime d, {required bool isSelected, required int sessionCount, required VoidCallback onTap}) {
    const Color selectedBorder = Color(0xFFF59E0B);
    const Color selectedBg = Color(0xFFFEF3C7);
    const Color textColor = Color(0xFF111827);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? selectedBorder : const Color(0xFFE5E7EB)),
          boxShadow: [if (!isSelected) BoxShadow(blurRadius: 2, color: Colors.black.withOpacity(0.03))],
        ),
        child: Stack(
          children: [
            Center(child: Text('${d.day}', style: const TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 11))),
            if (sessionCount > 0)
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                  ),
                ),
              ),
            if (sessionCount > 1)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE68A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                  ),
                  child: Text(
                    sessionCount > 9 ? '9+' : '$sessionCount',
                    style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _dateToStr(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _monthShort(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
  
  // Legacy parsing methods removed in favor of AppDateUtils

  String _getRealTimeSessionStatus(Session session) {
    // Use centralized utility
    return AppDateUtils.determineSessionStatus(session.status, session.date, session.time);
  }
}
