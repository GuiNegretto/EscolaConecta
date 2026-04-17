import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'models/models.dart';
import 'services/auth_provider.dart';
import 'utils/app_theme.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/parent/parent_messages_screen.dart';
import 'services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: const EscolaConectaApp(),
  ),
);
}

class EscolaConectaApp extends StatelessWidget {
  const EscolaConectaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
  builder: (context, themeProvider, _) {
    return MaterialApp(
      title: 'EscolaConecta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const _SplashRouter(),
    );
  },
);
  }
}

class _SplashRouter extends StatelessWidget {
  const _SplashRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const _SplashScreen();
          case AuthStatus.authenticated:
            if (auth.isAdmin) return const AdminDashboardScreen();
            return const ParentMessagesScreen();
          case AuthStatus.unauthenticated:
            return const RoleSelectionScreen();
        }
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.accentBlue.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.school_rounded,
                  color: AppTheme.accentBlue, size: 50),
                  
            ),
            const SizedBox(height: 24),
            const Text(
              'Escola Conecta',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          ],
        ),
      ),
    );
  }
}