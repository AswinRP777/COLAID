// lib/pages/welcome_page.dart
import 'package:flutter/material.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      body: Stack(
        children: [
          // Animated radial gradient background
          AnimatedContainer(
            duration: const Duration(seconds: 6),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  cs.primary.withAlpha(40),
                  cs.secondary.withAlpha(30),
                  cs.background,
                ],
                radius: 1.0,
                focal: Alignment.topLeft,
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 28.0,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(child: _leftPanel(cs)),
                            const SizedBox(width: 32),
                            Expanded(child: _rightPanel(context)),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _leftPanel(cs),
                            const SizedBox(height: 26),
                            _rightPanel(context),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leftPanel(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _pulse,
          child: Hero(
            tag: 'app-logo',
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.volunteer_activism,
                size: 72,
                color: cs.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Welcome to COLAID',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: cs.onBackground,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A collaborative platform for quick aid & community support. Sign in to access your dashboard or create a new account.',
          style: TextStyle(
            fontSize: 15,
            color: cs.onBackground.withOpacity(0.75),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _rightPanel(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Create an account',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Sign in', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Continue as guest (demo)')),
          ),
          child: const Text('Continue as guest'),
        ),
      ],
    );
  }
}
