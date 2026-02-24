import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../courses/bloc/courses_bloc.dart';
import '../../../../models/course.dart';
import '../../../../models/session.dart';

class ProgramDialog extends StatefulWidget {
  final Map<String, dynamic>? initialProgram;
  
  const ProgramDialog({super.key, this.initialProgram});

  @override
  State<ProgramDialog> createState() => _ProgramDialogState();
}

class _ProgramDialogState extends State<ProgramDialog> {
  String? _selectedCourseName;
  late TextEditingController _customCourseCtrl;
  late TextEditingController _daysCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _startDateCtrl;
  late TextEditingController _endDateCtrl;
  bool _isCustomCourse = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProgram ?? {};
    _selectedCourseName = p['course'];
    _customCourseCtrl = TextEditingController(text: p['course'] ?? '');
    _daysCtrl = TextEditingController(text: p['days'] ?? '');
    _timeCtrl = TextEditingController(text: p['time'] ?? '');
    _startDateCtrl = TextEditingController(text: p['startDate'] ?? '');
    _endDateCtrl = TextEditingController(text: p['endDate'] ?? '');
    
    // If existing course is not in list (checked later) or if empty, might default.
  }

  @override
  void dispose() {
    _customCourseCtrl.dispose();
    _daysCtrl.dispose();
    _timeCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialProgram == null ? 'Add Program' : 'Edit Program'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Course Selection
             BlocBuilder<CoursesBloc, CoursesState>(
                builder: (context, state) {
                  List<Course> courses = [];
                  if (state is CoursesLoaded) {
                      courses = state.courses;
                  }
                  
                  // If we have courses, show dropdown
                  if (courses.isNotEmpty) {
                      // Ensure selected value exists in list or is handled
                      final exists = courses.any((c) => c.name == _selectedCourseName);
                      if (!exists && _selectedCourseName != null && _selectedCourseName!.isNotEmpty) {
                          // If current name is not in list, maybe it was custom or legacy.
                          // For now, we can add a "Other" option or just show it if we support custom.
                          // Let's stick to Dropdown. If legacy, we might force them to pick new?
                          // Or we add it to list conceptually?
                          // Simpler: Just allow Dropdown.
                      }
                      
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             DropdownButtonFormField<String>(
                                value: exists ? _selectedCourseName : null,
                                items: [
                                   ...courses.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                                   const DropdownMenuItem(value: '__custom__', child: Text('Other (Type Manually)')),
                                ],
                                onChanged: (v) {
                                   if (v == '__custom__') {
                                       setState(() { 
                                          _isCustomCourse = true; 
                                          _selectedCourseName = null;
                                       });
                                   } else {
                                       setState(() { 
                                          _isCustomCourse = false;
                                          _selectedCourseName = v; 
                                          _customCourseCtrl.text = v ?? '';
                                          
                                          // Auto-fill defaults if available
                                          final selectedCourse = courses.firstWhere((c) => c.name == v, orElse: () => Course(id: 0, name: '', description: '', duration: ''));
                                          if ((selectedCourse.duration ?? '').isNotEmpty && _timeCtrl.text.isEmpty) {
                                              // We could auto-fill duration into time/days? No, duration is e.g. "1 hour".
                                          }
                                       });
                                   }
                                },
                                decoration: InputDecoration(labelText: 'Select Course', border: OutlineInputBorder()),
                             ),
                             if (_isCustomCourse) ...[
                                 const SizedBox(height: 8),
                                 TextField(
                                   controller: _customCourseCtrl,
                                   decoration: InputDecoration(labelText: 'Custom Course Name', border: OutlineInputBorder()),
                                 ),
                             ]
                          ],
                      );
                  } else {
                      // Fallback to text field if no courses defined
                      return TextField(
                        controller: _customCourseCtrl,
                        decoration: InputDecoration(labelText: 'Course Name', border: OutlineInputBorder(), helperText: 'No courses found in Course Management.'),
                      );
                  }
                }
             ),
            const SizedBox(height: 12),
            TextField(
              controller: _daysCtrl,
              decoration: InputDecoration(labelText: 'Days (e.g., Mon, Wed, Fri)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _timeCtrl,
              decoration: InputDecoration(labelText: 'Time (e.g., 10:00 AM - 11:00 AM)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startDateCtrl,
              decoration: InputDecoration(labelText: 'Start Date', border: OutlineInputBorder()),
              readOnly: true,
              onTap: () => _pickDate(_startDateCtrl),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endDateCtrl,
              decoration: InputDecoration(labelText: 'End Date', border: OutlineInputBorder()),
              readOnly: true,
              onTap: () => _pickDate(_endDateCtrl),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            // Determine final course name
            String finalCourseName = _isCustomCourse ? _customCourseCtrl.text.trim() : (_selectedCourseName ?? _customCourseCtrl.text.trim());
            
            if (finalCourseName.isNotEmpty) {
              Navigator.pop(context, {
                'course': finalCourseName,
                'days': _daysCtrl.text.trim(),
                'time': _timeCtrl.text.trim(),
                'startDate': _startDateCtrl.text.trim(),
                'endDate': _endDateCtrl.text.trim(),
              });
            }
          },
          child: Text(widget.initialProgram == null ? 'Add Program' : 'Update Program'),
        ),
      ],
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      ctrl.text = '${date.day}/${date.month}/${date.year}';
    }
  }
}
