import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/main_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (!RegExp(r'[A-Za-z]').hasMatch(value))
      return 'Password must contain at least one letter';
    if (!RegExp(r'[0-9]').hasMatch(value))
      return 'Password must contain at least one number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>+]').hasMatch(value))
      return 'Password must contain at least one symbol';
    if (value.length < 8) return 'Password must be at least 8 characters long';
    return null;
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      try {
        // Use Firebase to sign in with the entered credentials
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        if (password == 'Password@123') {
           final prefs = await SharedPreferences.getInstance();
           final hasPrompted = prefs.getBool('has_prompted_password_change_${email.toLowerCase()}') ?? false;
           if (!hasPrompted) {
             await prefs.setBool('prompt_password_change', true);
             await prefs.setBool('has_prompted_password_change_${email.toLowerCase()}', true);
           }
        }
        
        // Ensure we land on the dashboard whenever we successfully log in.
        MainScaffold.viewNotifier.value = 'dashboard';

        // After a successful login, AuthGate handles navigation.
      } on FirebaseAuthException catch (e) {
        // Handle first time login with default password
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
          if (password == 'Password@123') {
             try {
               // Prevent AuthGate from changing screens while we verify the user
               AppConfig.isVerifyingNewUser.value = true;
               
               // Try dynamically creating the auth user
               final creds = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                 email: email, 
                 password: password
               );
               
               // Verify against admin clients list
               final query = await FirebaseFirestore.instance
                 .collection('users')
                 .doc(AppConfig.sharedWorkspaceId)
                 .collection('clients')
                 .where('email', isEqualTo: email.toLowerCase())
                 .get();
                 
               if (query.docs.isEmpty) {
                  // Not registered in admin app. Delete auth account.
                  await creds.user?.delete();
                  AppConfig.isVerifyingNewUser.value = false;
                  if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email not registered by the admin. Access denied.')));
                  }
               } else {
                  final prefs = await SharedPreferences.getInstance();
                  final hasPrompted = prefs.getBool('has_prompted_password_change_${email.toLowerCase()}') ?? false;
                  if (!hasPrompted) {
                    await prefs.setBool('prompt_password_change', true);
                    await prefs.setBool('has_prompted_password_change_${email.toLowerCase()}', true);
                  }
                  AppConfig.isVerifyingNewUser.value = false;
                  MainScaffold.viewNotifier.value = 'dashboard';

               }
             } on FirebaseAuthException catch (createError) {
               AppConfig.isVerifyingNewUser.value = false;
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login Failed: ${createError.message}')));
               }
             } catch (e) {
               AppConfig.isVerifyingNewUser.value = false;
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${e.toString()}')));
               }
             }
          } else {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login Failed: Invalid Email or Password')));
             }
          }
        } else {
          // If login fails, show an error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login Failed: ${e.message}')));
          }
        }
      } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login Error: ${e.toString()}')));
          }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/loginpagelogo.png', height: 120),
                const SizedBox(height: 16),
                const Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to continue to your dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _usernameController,
                        decoration: inputDecoration,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Username is required'
                            : null,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: inputDecoration.copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF9CA3AF),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: _passwordValidator,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(237, 191, 69, 1.0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                  child: const Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
