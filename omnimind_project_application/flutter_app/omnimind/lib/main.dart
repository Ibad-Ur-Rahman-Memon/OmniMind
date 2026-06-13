// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/providers/app_providers.dart';
import 'core/services/groq_llm_service.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load bundled .env (release-safe) and configure Groq.
  // .env is bundled as an asset via pubspec.yaml.
  await dotenv.load(fileName: '.env');
  final groqKey = dotenv.env['GROQ_API_KEY'] ?? '';
  GroqLLMService().configure(apiKey: groqKey);

  // Initialize Firebase with real config from google-services.json
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDeKhrweeF0XEiC7rUcCImokzFAjp1PQQ8",
        authDomain: "omnimind-a53b2.firebaseapp.com",
        projectId: "omnimind-a53b2",
        storageBucket: "omnimind-a53b2.firebasestorage.app",
        messagingSenderId: "522008854801",
        appId: "1:522008854801:android:a70d417e0fad4cba8e8cb0",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // Optional: keep same UI defaults
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const OmniMindApp());
}

class OmniMindApp extends StatelessWidget {
  const OmniMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initAuth()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'OmniMind',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
