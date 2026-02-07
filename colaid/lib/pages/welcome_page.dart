// lib/pages/welcome_page.dart
import 'package:flutter/material.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _pageController;

  late final Animation<double> _floatAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _floatAnim = Tween(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _fadeAnim = CurvedAnimation(
      parent: _pageController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background
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

    final subtitleColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: bgGradient),
          ),

          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 👁 Floating Logo (ALWAYS WHITE BACKGROUND)
                        AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (_, child) {
                            return Transform.translate(
                              offset: Offset(0, _floatAnim.value),
                              child: child,
                            );
                          },
                          child: Hero(
                            tag: 'colaid-logo',
                            child: Container(
                              width: 150,
                              height: 150,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white, // ✅ fixed
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      isDark ? 0.5 : 0.12,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/colaid_eye.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          'Welcome to ColAid',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Real-time color assistance designed to improve\nclarity, confidence, and accessibility.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.5,
                            color: subtitleColor,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Get Started Button
                        SizedBox(
  width: double.infinity,
  child: GestureDetector(
    onTap: () {
      Navigator.pushReplacementNamed(context, '/login');
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.white
            : const Color(0xFF1E293B), // dark navy
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              isDark ? 0.5 : 0.2,
            ),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'Get Started',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.black : Colors.white,
            letterSpacing: 0.4,
          ),
        ),
      ),
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
        ],
      ),
    );
  }
}
