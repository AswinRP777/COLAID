import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // created by flutterfire configure
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'services/user_service.dart';

// pages
import 'pages/welcome_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/home_page.dart';
import 'pages/ishihara_test_page.dart'; 
import 'pages/settings_page.dart';      
import 'pages/camera_page.dart';        
import 'pages/legend_page.dart';
import 'pages/results_history_page.dart';        

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize UserService to load persisted user data
  await UserService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    bool isHighContrast = themeProvider.contrastMode == 'High Contrast';

    ColorScheme lightScheme = isHighContrast 
        ? const ColorScheme.highContrastLight() 
        : ColorScheme.fromSeed(seedColor: Colors.deepPurple);

    ColorScheme darkScheme = isHighContrast 
        ? const ColorScheme.highContrastDark() 
        : ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          );

    final baseTheme = ThemeData(
      colorScheme: lightScheme,
      useMaterial3: true,
    );

    final darkTheme = ThemeData(
      colorScheme: darkScheme,
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'COLAID',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme),
      ),
      darkTheme: darkTheme.copyWith(
         textTheme: GoogleFonts.interTextTheme(darkTheme.textTheme),
      ),
      initialRoute: '/',
      builder: (context, child) {
        // Calculate font scale
        double textScaleFactor = 1.0;
        if (themeProvider.fontSize == 'Small') {
          textScaleFactor = 0.85;
        } else if (themeProvider.fontSize == 'Large') {
          textScaleFactor = 1.15;
        }

        Widget currentChild = child!;

        // Apply Text Scaler
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: currentChild,
        );
      },
      routes: {
        '/': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/ishihara': (context) => const IshiharaTestPage(),
        '/settings': (context) => const SettingsPage(),
        '/camera': (context) => const CameraPage(),
        '/legend': (context) => const LegendPage(),
        '/history': (context) => const ResultsHistoryPage(),
      },
    );
  }
}
