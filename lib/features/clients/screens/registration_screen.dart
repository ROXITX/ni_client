import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/client.dart';
import '../../../core/utils/date_utils.dart';
import '../bloc/clients_bloc.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _selectedGender;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _occupationCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _clearForm() {
    _firstNameCtrl.clear();
    _lastNameCtrl.clear();
    _dobCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _occupationCtrl.clear();
    _descriptionCtrl.clear();
    setState(() {
      _selectedGender = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClientsBloc, ClientsState>(
      listener: (context, state) {
        if (state is ClientsOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.green,
            ),
          );
          _clearForm();
          // Optionally navigate back if this was a pushed route:
          // Navigator.of(context).pop();
        } else if (state is ClientsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Container(
        color: const Color(0xFFF9FAFB),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Area (if stand-alone screen)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      'New Client Registration',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),

                  // First Name & Last Name Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildLabeledField(
                          'First Name',
                          TextFormField(
                            controller: _firstNameCtrl,
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            decoration: _inputDecoration(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildLabeledField(
                          'Last Name',
                          TextFormField(
                            controller: _lastNameCtrl,
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            decoration: _inputDecoration(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // DOB & Gender Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildLabeledField(
                          'Date of Birth',
                          TextFormField(
                            controller: _dobCtrl,
                            readOnly: true,
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.tryParse(_dobCtrl.text) ?? DateTime(2000),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _dobCtrl.text = AppDateUtils.dateToStr(picked);
                                });
                              }
                            },
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            decoration: _inputDecoration(hintText: 'Select a date'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildLabeledField(
                          'Gender',
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            items: ['Male', 'Female', 'Other']
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedGender = v),
                            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            decoration: _inputDecoration(hintText: 'Select gender'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabeledField(
                    'Email',
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(hintText: 'e.g., john.doe@email.com'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required';
                        final emailRegex = RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                        if (!emailRegex.hasMatch(v)) return 'Please enter a valid email address';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabeledField(
                    'Phone Number',
                    TextFormField(
                      controller: _phoneCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+-]'))
                      ],
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabeledField(
                    'Occupation',
                    TextFormField(
                      controller: _occupationCtrl,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      decoration: _inputDecoration(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabeledField(
                    'Optional Description',
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration(),
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
                      child: const Text('Register Client'),
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
      // Calculate ID
      final state = context.read<ClientsBloc>().state;
      int nextId = 1;
      if (state is ClientsLoaded && state.clients.isNotEmpty) {
        nextId = state.clients.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1; 
      }
      // Note: There's a small race condition here if multiple admins are adding clients simultaneously,
      // but simpler to replicate existing logic for now. Use a Transaction or AutoID in repo for better solution.

      final newClient = Client(
        id: nextId,
        firstName: _firstNameCtrl.text,
        lastName: _lastNameCtrl.text,
        dob: _dobCtrl.text,
        gender: _selectedGender ?? '',
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        occupation: _occupationCtrl.text,
        description: _descriptionCtrl.text,
        programs: [],
      );

      context.read<ClientsBloc>().add(ClientsAddClient(newClient));
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
