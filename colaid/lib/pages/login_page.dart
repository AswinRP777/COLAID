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

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _email = '', _password = '';
  bool _obscure = true;
  bool _loading = false;
  List<String> _emailSuggestions = [];
  bool _showSuggestions = false; // Track if suggestions dropdown is open

  @override
  void initState() {
    super.initState();
    _loadEmailHistory();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _loadEmailHistory() {
    _emailSuggestions = UserService().emailHistory;
    setState(() {});
  }

  void _submit() async {
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
        // Save user info
        await UserService().setUserData(email: _email);

        // Reset/Reload Settings for this user
        if (mounted) {
          await Provider.of<ThemeProvider>(context, listen: false).refresh();
        }

        // Save Session Cookie
        String? rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          int index = rawCookie.indexOf(';');
          String cookie = (index == -1)
              ? rawCookie
              : rawCookie.substring(0, index);
          await UserService().setAuthCookie(cookie);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Signed in as $_email')));

        // Navigate to HomePage
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final msg = jsonDecode(response.body)['error'] ?? 'Login failed';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $msg')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  void _guestLogin() async {
    setState(() => _loading = true);

    try {
      final response = await http.post(
        Uri.parse('${dotenv.env['API_URL']}/guest-login'),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;
      setState(() => _loading = false);

      if (response.statusCode == 200) {
        // Save user info - specific for Guest
        await UserService().setUserData(email: 'Guest');

        // Reset/Reload Settings for this user
        if (mounted) {
          await Provider.of<ThemeProvider>(context, listen: false).refresh();
        }

        // Save Session Cookie
        String? rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          int index = rawCookie.indexOf(';');
          String cookie = (index == -1)
              ? rawCookie
              : rawCookie.substring(0, index);
          await UserService().setAuthCookie(cookie);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Signed in as Guest')));

        // Navigate to HomePage
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Guest login failed')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerHighest,
        title: const Text('Sign in'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'app-logo',
                  child: Icon(
                    Icons.volunteer_activism,
                    size: 72,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 18),
                AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      children: [
                        // Email field with autocomplete suggestions
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            // Return empty list if suggestions are collapsed
                            if (!_showSuggestions) {
                              return const Iterable<String>.empty();
                            }
                            if (textEditingValue.text.isEmpty) {
                              // Show all suggestions when field is empty/focused
                              return _emailSuggestions;
                            }
                            // Filter suggestions based on input
                            return _emailSuggestions.where(
                              (email) => email.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                            );
                          },
                          onSelected: (String selection) {
                            _emailController.text = selection;
                            setState(() => _showSuggestions = false);
                          },
                          fieldViewBuilder:
                              (
                                context,
                                controller,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                // Sync controllers
                                if (_emailController.text.isEmpty &&
                                    controller.text.isEmpty) {
                                  controller.text = _emailController.text;
                                }
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    suffixIcon: _emailSuggestions.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              _showSuggestions
                                                  ? Icons.arrow_drop_up
                                                  : Icons.arrow_drop_down,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _showSuggestions =
                                                    !_showSuggestions;
                                              });
                                              if (_showSuggestions) {
                                                // Focus to trigger rebuild and show suggestions
                                                focusNode.requestFocus();
                                              } else {
                                                // Unfocus to close suggestions
                                                focusNode.unfocus();
                                              }
                                            },
                                          )
                                        : null,
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [
                                    AutofillHints.email,
                                    AutofillHints.username,
                                  ],
                                  onTap: () {
                                    // Show suggestions when field is tapped
                                    if (!_showSuggestions &&
                                        _emailSuggestions.isNotEmpty) {
                                      setState(() => _showSuggestions = true);
                                    }
                                  },
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                      ? 'Enter a valid email'
                                      : null,
                                  onSaved: (v) => _email = v?.trim() ?? '',
                                );
                              },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 10,
                                      sigmaY: 10,
                                    ),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 220,
                                        maxWidth: 476,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.surface.withValues(
                                          alpha: 0.85,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: cs.outline.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: cs.shadow.withValues(
                                              alpha: 0.15,
                                            ),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        separatorBuilder: (context, index) =>
                                            Divider(
                                              height: 1,
                                              indent: 72,
                                              endIndent: 16,
                                              color: cs.outline.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                        itemBuilder: (context, index) {
                                          final email = options.elementAt(
                                            index,
                                          );
                                          return Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => onSelected(email),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                              colors: [
                                                                cs.primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.8,
                                                                    ),
                                                                cs.tertiary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.8,
                                                                    ),
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          email[0]
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                            color: cs.onPrimary,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            email,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 15,
                                                              color:
                                                                  cs.onSurface,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            'Previously signed in',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: cs
                                                                  .onSurface
                                                                  .withValues(
                                                                    alpha: 0.6,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.close_rounded,
                                                        size: 18,
                                                        color: cs.outline
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                      onPressed: () async {
                                                        await UserService()
                                                            .removeEmailFromHistory(
                                                              email,
                                                            );
                                                        _loadEmailHistory();
                                                      },
                                                      tooltip:
                                                          'Remove from suggestions',
                                                      splashRadius: 20,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Minimum 6 characters'
                              : null,
                          onSaved: (v) => _password = v ?? '',
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : FilledButton(
                                  onPressed: _submit,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'Sign in',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/register',
                              ),
                              child: const Text(
                                "Don't have an account? Register",
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _loading ? null : _guestLogin,
                          child: const Text(
                            "Continue as Guest",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
