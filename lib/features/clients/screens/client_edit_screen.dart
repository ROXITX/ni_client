import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/client.dart';
import '../../../core/utils/date_utils.dart';
import '../bloc/clients_bloc.dart';

class ClientEditScreen extends StatefulWidget {
  final Client client;
  final List<Client> allClients;

  const ClientEditScreen({super.key, required this.client, required this.allClients});

  @override
  State<ClientEditScreen> createState() => _ClientEditScreenState();
}

class _ClientEditScreenState extends State<ClientEditScreen> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _dobCtrl;
  
  late String _selectedGender;
  bool _isSaving = false;
  
  String? _errorMessage;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _firstNameCtrl = TextEditingController(text: c.firstName);
    _lastNameCtrl = TextEditingController(text: c.lastName);
    _emailCtrl = TextEditingController(text: c.email);
    _phoneCtrl = TextEditingController(text: c.phone);
    _occupationCtrl = TextEditingController(text: c.occupation);
    _descriptionCtrl = TextEditingController(text: c.description);
    _dobCtrl = TextEditingController(text: c.dob);
    _selectedGender = c.gender;
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _occupationCtrl.dispose();
    _descriptionCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _validateEmailUniqueness(String email, List<Client> clients, {int? excludeClientId}) async {
    final emailLower = email.trim().toLowerCase();
    if (emailLower.isEmpty) return; 
    
    // 1. Must contain '@'
    if (!emailLower.contains('@')) {
      throw Exception('Email must contain "@"');
    }
    
    // 2. Must contain '.' and not end with it
    if (!emailLower.contains('.')) {
      throw Exception('Email must contain "."');
    }
    if (emailLower.endsWith('.')) {
      throw Exception('Email cannot end with "."');
    }
    
    // 3. Must have something before '@'
    if (emailLower.indexOf('@') == 0) {
      throw Exception('Email must have text before "@"');
    }
    
    // 4. Must have something after '@'
    final parts = emailLower.split('@');
    if (parts.length > 1 && parts[1].isEmpty) {
       throw Exception('Email must have text after "@"');
    }
    
    final exists = clients.any((c) => 
      c.email.trim().toLowerCase() == emailLower && 
      (excludeClientId == null || c.id != excludeClientId)
    );
    
    if (exists) {
      throw Exception('This email is already registered to another client.');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
    });
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _errorMessage = null);
    });
  }

  InputDecoration _inputDecoration() {
      return InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      );
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  String _dateToStr(DateTime d) {
    return AppDateUtils.dateToStr(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Client'),
      ),
      body: Stack(
        children: [
          Container(
            color: const Color(0xFFF9FAFB),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  const Text('Edit Client Bio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _labeledField('First Name', TextField(controller: _firstNameCtrl, decoration: _inputDecoration())),
                  const SizedBox(height: 12),
                  _labeledField('Last Name', TextField(controller: _lastNameCtrl, decoration: _inputDecoration())),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setDateFieldState) {
                      return _labeledField(
                        'Date of Birth',
                        TextField(
                          controller: _dobCtrl,
                          readOnly: true,
                          decoration: _inputDecoration(),
                          onTap: () async {
                             DateTime initial = DateTime(2000);
                             try {
                               initial = AppDateUtils.parseSessionDate(_dobCtrl.text); 
                             } catch(_) {}

                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) {
                              setDateFieldState(() {
                                _dobCtrl.text = _dateToStr(picked);
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _labeledField(
                      'Gender',
                      DropdownButtonFormField<String>(
                        value: _selectedGender.isNotEmpty && ['Male', 'Female', 'Other'].contains(_selectedGender) ? _selectedGender : null,
                        items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => _selectedGender = v ?? ''),
                        decoration: _inputDecoration(),
                      )),
                  const SizedBox(height: 12),
                  _labeledField('Email', TextField(controller: _emailCtrl, decoration: _inputDecoration())),
                  const SizedBox(height: 12),
                  _labeledField('Phone', TextField(controller: _phoneCtrl, decoration: _inputDecoration())),
                  const SizedBox(height: 12),
                  _labeledField('Occupation', TextField(controller: _occupationCtrl, decoration: _inputDecoration())),
                  const SizedBox(height: 12),
                  _labeledField('Description', TextField(controller: _descriptionCtrl, maxLines: 3, decoration: _inputDecoration())),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : () async {
                      setState(() => _isSaving = true);
                      _errorTimer?.cancel();
                      setState(() => _errorMessage = null);

                      try {
                        final newEmail = _emailCtrl.text.trim();
                        
                        await _validateEmailUniqueness(newEmail, widget.allClients, excludeClientId: widget.client.id);

                        final updatedClient = Client(
                          id: widget.client.id,
                          firstName: _firstNameCtrl.text,
                          lastName: _lastNameCtrl.text,
                          dob: _dobCtrl.text,
                          gender: _selectedGender,
                          email: newEmail,
                          phone: _phoneCtrl.text,
                          occupation: _occupationCtrl.text,
                          description: _descriptionCtrl.text,
                          programs: widget.client.programs,
                        );

                        if (mounted) {
                            context.read<ClientsBloc>().add(ClientsUpdateClient(updatedClient));

                            await Future.delayed(const Duration(milliseconds: 500)); 

                            if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Client updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.pop(context);
                            }
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isSaving = false);
                          _showError(e.toString().replaceAll('Exception: ', ''));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFFBBF24).withOpacity(0.5)
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                        : const Text('Save Changes'),
                  )
                ],
              ),
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 4,
                color: Colors.red.shade600,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => setState(() => _errorMessage = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
