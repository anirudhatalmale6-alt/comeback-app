import 'package:flutter/material.dart';
import 'package:comeback_app/services/auth_service.dart';
import 'package:comeback_app/services/firestore_service.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/screens/auth/register_screen.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final auth = context.read<AuthService>();
      final firestore = context.read<FirestoreService>();

      final cred = await auth.signIn(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );

      if (!mounted) return;

      final user = await firestore.getUser(cred.user!.uid);
      if (!mounted) return;

      if (user is OwnerUser) {
        Navigator.of(context).pushReplacementNamed('/owner-dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/employee-dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('user-not-found')) return 'No account found with this email.';
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    }
    if (msg.contains('invalid-email')) return 'Please enter a valid email address.';
    if (msg.contains('too-many-requests')) return 'Too many attempts. Try again later.';
    return 'Login failed. Please check your credentials.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App logo / title
                Icon(
                  Icons.notifications_active_rounded,
                  size: 64,
                  color: const Color(0xFF00897B),
                ),
                const SizedBox(height: 12),
                Text(
                  'Come Back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00897B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Employee Paging System',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Login card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Sign In',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Email is required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Password is required';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _loading ? null : _login,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
