
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth/email_login_page.dart';
import 'auth/phone_login_page.dart';
import 'home/home_page.dart';
import 'share/shared_contract_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    if (settings.name == '/') {
      return MaterialPageRoute(builder: (_) => const AuthGate());
    }
    if (settings.name == '/share') {
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
    }

    if (settings.name == '/phone-login') {
      return MaterialPageRoute(builder: (_) => const PhoneLoginPage());
    }

    return _errorRoute('Route not found: ${settings.name}');
  }

  Route<dynamic>? _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(message)),
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
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final user = snapshot.data;
        
        if (user == null) {
          return const EmailLoginPage();
        }
        
        if (!user.emailVerified) {
          return const HomePage();
        }
        
        return const HomePage();
      },
    );
  }
}