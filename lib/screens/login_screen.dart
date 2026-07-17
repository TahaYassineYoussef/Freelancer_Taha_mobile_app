import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/auth.dart';
import 'register_screen.dart';

/// Palette mirrored from the website's Login page (Tailwind violet/indigo/pink).
class _LoginColors {
  static const indigo500 = Color(0xFF6366F1);
  static const violet500 = Color(0xFF8B5CF6);
  static const purple600 = Color(0xFF9333EA);
  static const violet600 = Color(0xFF7C3AED);
  static const violet400 = Color(0xFFA78BFA);
  static const pink500 = Color(0xFFEC4899);
  static const indigo50 = Color(0xFFEEF2FF);
  static const gray500 = Color(0xFF6B7280);
  static const gray700 = Color(0xFF374151);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'client@freelancer.test');
  final _password = TextEditingController(text: 'password');
  bool _loading = false;
  bool _obscure = true;
  bool _remember = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().login(_email.text.trim(), _password.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not connect to the server.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_LoginColors.indigo500, _LoginColors.violet500, _LoginColors.purple600],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand + welcome copy (matches the web's left decorative panel).
                  const Text('Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Log in to connect with Taha Yassine Youssef — post your tasks, chat directly, and manage your projects in one place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFC7D2FE)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // White form card.
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'USER LOGIN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.5,
                            color: _LoginColors.violet600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_error != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_error!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                          ),
                        _field(
                          controller: _email,
                          hint: 'Email',
                          icon: Icons.person_outline,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _password,
                          hint: 'Password',
                          icon: Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                color: _LoginColors.violet400, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _remember = !_remember),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: Checkbox(
                                      value: _remember,
                                      onChanged: (v) => setState(() => _remember = v ?? false),
                                      activeColor: _LoginColors.violet500,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Remember',
                                      style: TextStyle(color: _LoginColors.gray500, fontSize: 13)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please reset your password on the website.')),
                              ),
                              child: const Text('Forgot password?',
                                  style: TextStyle(color: _LoginColors.violet500, fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _submitButton(),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? ",
                                style: TextStyle(color: _LoginColors.gray500, fontSize: 13)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                              ),
                              child: const Text('Sign up',
                                  style: TextStyle(
                                      color: _LoginColors.violet600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
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

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      cursorColor: _LoginColors.violet500,
      style: const TextStyle(color: _LoginColors.gray700, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _LoginColors.violet400, fontSize: 14),
        prefixIcon: Icon(icon, color: _LoginColors.violet400, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _LoginColors.indigo50,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: _LoginColors.violet400, width: 2),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_LoginColors.violet500, _LoginColors.pink500],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _LoginColors.violet500.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _loading ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 15),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'LOGIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
