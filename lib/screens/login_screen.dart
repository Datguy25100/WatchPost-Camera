import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  String? _emailError;
  String? _passwordError;
  String? _serverError;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _email.text.trim();
    final emailError =
        RegExp(r'^\S+@\S+\.\S+$').hasMatch(email) ? null : 'Enter a valid email address';
    final passwordError =
        _password.text.length >= 6 ? null : 'Password must be at least 6 characters';
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _serverError = null;
    });
    if (emailError != null || passwordError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    final error = await context.read<AppState>().signIn(email, _password.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _serverError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Logo(),
                  const SizedBox(height: 18),
                  const Text('WatchPost',
                      style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.1)),
                  const SizedBox(height: 8),
                  const Text('Your home. Always watched.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 48),
                  AppTextField(
                    label: 'Email address',
                    hint: 'you@example.com',
                    icon: Icons.mail_outline_rounded,
                    controller: _email,
                    error: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Password',
                    hint: 'Enter your password',
                    icon: Icons.lock_outline_rounded,
                    controller: _password,
                    error: _passwordError,
                    obscure: !_show,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    trailing: IconButton(
                      tooltip: _show ? 'Hide password' : 'Show password',
                      icon: Icon(
                        _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.muted,
                      ),
                      onPressed: () => setState(() => _show = !_show),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_serverError != null) ...[
                    Text(_serverError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                  ],
                  AppButton(
                    label: _loading ? 'Signing in…' : 'Sign in',
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
