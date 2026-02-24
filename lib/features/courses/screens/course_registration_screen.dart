import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/course.dart';
import '../bloc/courses_bloc.dart';

class CourseRegistrationScreen extends StatefulWidget {
  final Course? courseToEdit; // If null, mode is Add
  const CourseRegistrationScreen({super.key, this.courseToEdit});

  @override
  State<CourseRegistrationScreen> createState() => _CourseRegistrationScreenState();
}

class _CourseRegistrationScreenState extends State<CourseRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(); // Or dropdown
  
  // Pre-defined duration options as seen in SessionDuration enum, but as strings for now
  final List<String> _durationOptions = [
    '0.5 Hour',
    '1 Hour',
    '2 Hours',
    '3 Hours',
    'Whole Day',
  ];
  String? _selectedDuration;

  @override
  void initState() {
    super.initState();
    if (widget.courseToEdit != null) {
       _nameCtrl.text = widget.courseToEdit!.name;
       _descCtrl.text = widget.courseToEdit!.description;
       _selectedDuration = widget.courseToEdit!.duration;
       // If stored duration isn't in list, add it or leave as custom?
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _clearForm() {
    _nameCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _selectedDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.courseToEdit != null;
    return BlocListener<CoursesBloc, CoursesState>(
      listener: (context, state) {
        if (state is CoursesOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          if (isEditing) {
             Navigator.of(context).pop(); // Go back to list
          } else {
             _clearForm();
          }
        } else if (state is CoursesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold( // Wrappable in Scaffold or plain Container if embedded
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: isEditing ? AppBar(title: const Text('Edit Course')) : null, 
        // If not editing, we might be embedded in MainScaffold, so no AppBar unless pushed?
        // But the previous RegistrationScreen had no custom AppBar, just a Title text.
        // We'll follow that pattern.
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isEditing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      'New Course Registration', // "Registration" terminology as requested
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),

                  _buildLabeledField(
                    'Course Name',
                    TextFormField(
                      controller: _nameCtrl,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      decoration: _inputDecoration(hintText: 'e.g. Graphic Design Masterclass'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildLabeledField(
                     'Default Duration',
                     DropdownButtonFormField<String>(
                        value: _selectedDuration,
                        items: _durationOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setState(() => _selectedDuration = v),
                        decoration: _inputDecoration(hintText: 'Select Duration'),
                        // Optional
                     ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabeledField(
                    'Description',
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: _inputDecoration(hintText: 'Course details...'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _submitForm,
                      child: Text(isEditing ? 'Update Course' : 'Register Course'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (widget.courseToEdit != null) {
          // Editing
          final updated = Course(
             id: widget.courseToEdit!.id,
             name: _nameCtrl.text.trim(),
             description: _descCtrl.text.trim(),
             duration: _selectedDuration
          );
          context.read<CoursesBloc>().add(CoursesUpdateCourse(updated));
      } else {
          // Creating
          // Generate ID logic from Bloc State (similar to Client Registration)
          final state = context.read<CoursesBloc>().state;
          int nextId = 1;
          if (state is CoursesLoaded && state.courses.isNotEmpty) {
             nextId = state.courses.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;
          }

          final newCourse = Course(
             id: nextId,
             name: _nameCtrl.text.trim(),
             description: _descCtrl.text.trim(),
             duration: _selectedDuration
          );

          context.read<CoursesBloc>().add(CoursesAddCourse(newCourse));
      }
    }
  }

  Widget _buildLabeledField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF374151))),
        const SizedBox(height: 4),
        field,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFd1d5db)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFd1d5db)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF3B82F6)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
