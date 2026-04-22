import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pacts_app/pages/about_page.dart';
import 'package:pacts_app/pages/settings_page.dart';

import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

import 'auth/email_login_page.dart' hide AppColors;
import 'auth/phone_login_page.dart';
import 'home/home_page.dart';
import 'share/shared_contract_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.backgroundDark,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: AppColors.divider,
  ));
  
  await Firebase.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pacts',
      debugShowCheckedModeBanner: false,
      
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
      
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const AuthGate());
      
      case '/share':
        final uri = Uri.parse(settings.arguments?.toString() ?? '');
        final contractId = uri.queryParameters['contractId'] ?? '';
        final ownerUid = uri.queryParameters['ownerUid'] ?? '';
        
        if (contractId.isNotEmpty && ownerUid.isNotEmpty) {
          return MaterialPageRoute(
            builder: (_) => SharedContractGate(
              contractId: contractId,
              ownerUid: ownerUid,
            ),
          );
        }
        return _errorRoute('Invalid share link');
      
      case '/phone-login':
        return MaterialPageRoute(builder: (_) => const PhoneLoginPage());
      
      case '/about':
        return MaterialPageRoute(builder: (_) => const AboutPage());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      
      default:
        return _errorRoute('Route not found: ${settings.name}');
    }
  }

  Route<dynamic>? _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.gold,
          title: const Text(
            'Error',
            style: TextStyle(color: AppColors.gold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () => Navigator.popUntil(
                      _,
                      (route) => route.isFirst,
                    ),
                    child: const Text('Go Home'),
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.backgroundDark,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.gold),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }
        
        final user = snapshot.data;
        
        if (user == null) {
          return const EmailLoginPage();
        }
        
        return const HomePage();
      },
    );
  }
}