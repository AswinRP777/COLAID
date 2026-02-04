import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
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

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  String _email = '';
  // ignore: unused_field
  String _password = '';
  bool _obscure = true;
  bool _loading = false;

  /// Validates password strength and returns error message if invalid
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    final List<String> errors = [];

    // Check minimum length
    if (value.length < 8) {
      errors.add('• At least 8 characters');
    }

    // Check for uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      errors.add('• At least one uppercase letter (A-Z)');
    }

    // Check for lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      errors.add('• At least one lowercase letter (a-z)');
    }

    // Check for digit
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      errors.add('• At least one number (0-9)');
    }

    // Check for special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(value)) {
      errors.add('• At least one special character (!@#\$%^&*...)');
    }

    // Check for common weak passwords
    final commonWeakPasswords = [
      '12345678',
      '123456789',
      '1234567890',
      'password',
      'password1',
      'qwerty12',
      'qwertyui',
      'abcdefgh',
      'abc12345',
      '11111111',
      '00000000',
      'aaaaaaaa',
      'password123',
      'admin123',
      'letmein1',
    ];
    if (commonWeakPasswords.contains(value.toLowerCase())) {
      errors.add('• Password is too common, choose a stronger one');
    }

    // Check for sequential patterns (like 12345678 or abcdefgh)
    if (RegExp(r'^(.)\1+$').hasMatch(value)) {
      errors.add('• Password cannot be all the same character');
    }

    if (errors.isNotEmpty) {
      return 'Password must contain:\n${errors.join('\n')}';
    }

    return null;
  }

  void _submit() async {
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
        // Trigger password manager save prompt
        TextInput.finishAutofillContext();

        // Automatically sign in locally
        await UserService().setUserData(email: _email);

        // Reset/Reload Settings for this new user
        if (mounted) {
          await Provider.of<ThemeProvider>(context, listen: false).refresh();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Registered $_email')));

        // Navigate to HomePage
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final msg = jsonDecode(response.body)['error'] ?? 'Registration failed';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $msg')));
      }
    } catch (e) {
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
        title: const Text('Create account'),
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
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.newUsername,
                          ],
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                          onSaved: (v) => _email = v?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Password',
                            helperText:
                                'Must include uppercase, lowercase, number & special character',
                            helperMaxLines: 2,
                            errorMaxLines: 6,
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
                          autofillHints: const [AutofillHints.newPassword],
                          validator: _validatePassword,
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
                                      'Create account',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
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
