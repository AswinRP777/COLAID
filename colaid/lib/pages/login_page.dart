import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../providers/theme_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  String _email = '', _password = '';
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
    _emailController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    _form.currentState?.save();
    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_URL']}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _email, 'password': _password}),
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (response.statusCode == 200) {
        await UserService().setUserData(email: _email);
        await Provider.of<ThemeProvider>(context, listen: false).refresh();

        final rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          final index = rawCookie.indexOf(';');
          final cookie =
              (index == -1) ? rawCookie : rawCookie.substring(0, index);
          await UserService().setAuthCookie(cookie);
        }

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final msg = jsonDecode(response.body)['error'] ?? 'Login failed';
        _showSnack(msg);
      }
    } catch (_) {
      _showSnack('Connection error');
    }
  }

  Future<void> _guestLogin() async {
    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_URL']}/guest-login'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (response.statusCode == 200) {
        await UserService().setUserData(email: 'Guest');
        await Provider.of<ThemeProvider>(context, listen: false).refresh();

        final rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          final index = rawCookie.indexOf(';');
          final cookie =
              (index == -1) ? rawCookie : rawCookie.substring(0, index);
          await UserService().setAuthCookie(cookie);
        }

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showSnack('Guest login failed');
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
            colors: [
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEFF6FF),
            ],
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
                                  // Logo
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
                                    'Sign in to ColAid',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: titleColor,
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  TextFormField(
                                    controller: _emailController,
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      labelStyle:
                                          TextStyle(color: labelColor),
                                    ),
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    validator: (v) =>
                                        (v == null || !v.contains('@'))
                                            ? 'Enter a valid email'
                                            : null,
                                    onSaved: (v) => _email = v ?? '',
                                  ),

                                  const SizedBox(height: 12),

                                  TextFormField(
                                    style: TextStyle(color: textColor),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle:
                                          TextStyle(color: labelColor),
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
                                    validator: (v) =>
                                        (v == null || v.length < 6)
                                            ? 'Minimum 6 characters'
                                            : null,
                                    onSaved: (v) => _password = v ?? '',
                                  ),

                                  const SizedBox(height: 24),

                                  // Sign in
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
                                                'Sign in',
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

                                  // Register link
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account?",
                                        style: TextStyle(
                                          color: labelColor,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacementNamed(
                                            context,
                                            '/register',
                                          );
                                        },
                                        child: const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFF97316),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Guest
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : _guestLogin,
                                    child: const Text(
                                      'Continue as Guest',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFF97316),
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
