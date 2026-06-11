import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_provider.dart';
import 'services/link_provider.dart';
import 'services/notification_service.dart';
import 'services/update_provider.dart';
import 'utils/app_theme.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/parent/parent_messages_screen.dart';
import 'services/theme_provider.dart';
import 'firebase_options.dart';
import 'widgets/app_loading_error_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isFirebaseReady = false;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase inicializado com sucesso!");
    isFirebaseReady = true;
  } catch (e) {
    debugPrint("Erro CRÍTICO ao inicializar Firebase: $e");
    // O Dynatrace ou outra ferramenta nativa bloqueou o canal
  }

  // SÓ inicializa as notificações se o Firebase Core não tiver falhado
  if (isFirebaseReady) {
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint("Erro ao inicializar NotificationService: $e");
    }
  } else {
    debugPrint("NotificationService ignorado porque o Firebase falhou.");
  }
  
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

  final themeProvider = ThemeProvider();
  await themeProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => LinkProvider()),
        ChangeNotifierProvider(
          create: (_) => UpdateProvider(
            // Replace with your actual version.json URL
            versionCheckUrl: 'https://myserver.com/version.json',
          )..init(),
        ),
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
      navigatorKey: AuthProvider.navigatorKey,
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

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _logoController.forward();

    // Check for updates silently on startup
    _checkUpdatesOnStartup();
  }

  /// Silently checks for updates on app startup
  Future<void> _checkUpdatesOnStartup() async {
    try {
      final updateProvider = context.read<UpdateProvider>();
      final hasUpdate = await updateProvider.checkForUpdates(silent: true);

      if (!mounted) return;

      if (hasUpdate) {
        if (updateProvider.forceUpdate) {
          // Force update: show blocking dialog
          _showForcedUpdateDialog();
        } else {
          // Regular update: show snackbar banner
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nova versão disponível'),
              backgroundColor: AppTheme.warning,
              action: SnackBarAction(
                label: 'Ver',
                onPressed: () {
                  // The user can navigate to about screen from dashboard/menu
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking updates on startup: $e');
      // Silently fail - don't disrupt the splash screen
    }
  }

  /// Shows a blocking forced update dialog
  void _showForcedUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Consumer<UpdateProvider>(
          builder: (ctx, provider, _) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              'Atualização Obrigatória',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Uma nova versão deve ser instalada para continuar usando o app.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (provider.changelog.isNotEmpty) ...[
                  Text(
                    'Mudanças: ${provider.changelog}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                ],
                if (provider.downloading)
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: provider.downloadProgress,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(provider.downloadProgress * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                ),
                onPressed: provider.downloading
                    ? null
                    : () async {
                  final success = await provider.downloadAndInstall(
                    provider.downloadUrl,
                  );
                  if (!dialogContext.mounted && !success) {
                    AppErrorDialog.show(
                      dialogContext,
                      message: 'Erro: ${provider.error}',
                    );
                  }
                },
                child: Text(
                  provider.downloading ? 'Baixando...' : 'Atualizar Agora',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _logoAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _logoAnimation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: AppTheme.accentBlue, size: 50),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: const Text(
                    'Escola Conecta',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            const AppThreeDotLoader(
              size: 14,
              dotSpacing: 10,
            ),
          ],
        ),
      ),
    );
  }
}