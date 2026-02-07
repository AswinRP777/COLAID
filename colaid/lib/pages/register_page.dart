import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../providers/theme_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();

  String _email = '';
  String _password = '';
  bool _obscure = true;
  bool _loading = false;

  late final AnimationController _pageController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pageController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Password validation (UNCHANGED)
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';

    final List<String> errors = [];

    if (value.length < 8) errors.add('• At least 8 characters');
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      errors.add('• At least one uppercase letter (A-Z)');
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      errors.add('• At least one lowercase letter (a-z)');
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      errors.add('• At least one number (0-9)');
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(value)) {
      errors.add('• At least one special character');
    }

    final commonWeakPasswords = [
      '12345678',
      'password',
      'password123',
      'admin123',
    ];
    if (commonWeakPasswords.contains(value.toLowerCase())) {
      errors.add('• Password is too common');
    }

    if (errors.isNotEmpty) {
      return 'Password must contain:\n${errors.join('\n')}';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    _form.currentState?.save();

    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_URL']}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _email, 'password': _password}),
      );

      setState(() => _loading = false);

      if (response.statusCode == 201) {
        TextInput.finishAutofillContext();

        await UserService().setUserData(email: _email);
        await Provider.of<ThemeProvider>(context, listen: false).refresh();

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final msg = jsonDecode(response.body)['error'] ?? 'Registration failed';
        _showSnack(msg);
      }
    } catch (_) {
      _showSnack('Connection error');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          );

    final titleColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final labelColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final textColor =
        isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: bgGradient)),

          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF020617)
                                      .withOpacity(0.85)
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDark ? 0.6 : 0.12,
                                  ),
                                  blurRadius: 28,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _form,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Logo (always white)
                                  Hero(
                                    tag: 'colaid-logo',
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: Image.asset(
                                        'assets/colaid_eye.png',
                                        width: 64,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  Text(
                                    'Create your account',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  TextFormField(
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      labelStyle:
                                          TextStyle(color: labelColor),
                                    ),
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    autofillHints: const [
                                      AutofillHints.email,
                                      AutofillHints.newUsername,
                                    ],
                                    validator: (v) =>
                                        (v == null || !v.contains('@'))
                                            ? 'Enter a valid email'
                                            : null,
                                    onSaved: (v) =>
                                        _email = v?.trim() ?? '',
                                  ),

                                  const SizedBox(height: 12),

                                  TextFormField(
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle:
                                          TextStyle(color: labelColor),
                                      helperText:
                                          'Uppercase, lowercase, number & symbol',
                                      helperMaxLines: 2,
                                      errorMaxLines: 6,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscure
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color:
                                              const Color(0xFF1E293B),
                                        ),
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                      ),
                                    ),
                                    obscureText: _obscure,
                                    autofillHints: const [
                                      AutofillHints.newPassword
                                    ],
                                    validator: _validatePassword,
                                    onSaved: (v) => _password = v ?? '',
                                  ),

                                  const SizedBox(height: 24),

                                  SizedBox(
                                    width: double.infinity,
                                    child: _loading
                                        ? const Center(
                                            child:
                                                CircularProgressIndicator(),
                                          )
                                        : FilledButton(
                                            style:
                                                FilledButton.styleFrom(
                                              backgroundColor: isDark
                                                  ? Colors.white
                                                  : const Color(
                                                      0xFF1E293B,
                                                    ),
                                              foregroundColor: isDark
                                                  ? Colors.black
                                                  : Colors.white,
                                            ),
                                            onPressed: _submit,
                                            child: const Padding(
                                              padding:
                                                  EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              child: Text(
                                                'Create account',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),

                                  const SizedBox(height: 14),

                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/login',
                                      );
                                    },
                                    child: Text(
                                      'Already have an account? Sign in',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: labelColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
