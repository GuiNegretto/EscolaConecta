import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/logging_http_client.dart';
import '../utils/constants.dart';
import '../firebase_options.dart';

// ─── Handler de background (top-level obrigatório) ────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Quando o app está morto ou em background o FCM exibe a notificação
  // automaticamente. Aqui apenas persistimos para o badge.
  await NotificationService._incrementBadge();
}

// ─── Canal Android ────────────────────────────────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'escola_conecta_high',           // id
  'EscolaConecta — Mensagens',     // nome visível nas configurações do Android
  description: 'Mensagens e avisos da escola',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging? _fcm;
  final _localNotif = FlutterLocalNotificationsPlugin();
  final http.Client _client = LoggingHttpClient();
  bool _isInitialized = false;

  // Chave para contagem de notificações não lidas (badge)
  static const _badgeKey = 'notif_badge_count';
  // Chave para preferências salvas
  static const _prefsKey = 'notif_prefs';

  // Callback para quando o usuário toca na notificação
  // A tela que quiser ouvir pode registrar aqui
  ValueChanged<RemoteMessage>? onMessageTap;

  // ── Inicialização ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[FCM] Já inicializado, ignorando...');
      return;
    }

    debugPrint('[FCM] ===== INICIANDO INICIALIZAÇÃO =====');
    
    try {
      // Verificar se Firebase Core está inicializado antes de continuar
      bool firebaseCoreReady = false;
      try {
        Firebase.app(); // Tenta acessar o app padrão
        firebaseCoreReady = true;
        debugPrint('[FCM] ✅ Firebase Core já está inicializado');
      } catch (e) {
        debugPrint('[FCM] ⚠️ Firebase Core não encontrado: $e');
        debugPrint('[FCM] Tentando inicializar Firebase Core...');
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          firebaseCoreReady = true;
          debugPrint('[FCM] ✅ Firebase Core inicializado com sucesso');
        } catch (initError) {
          debugPrint('[FCM] ❌ Erro ao inicializar Firebase Core: $initError');
          firebaseCoreReady = false;
        }
      }
      
      if (!firebaseCoreReady) {
        debugPrint('[FCM] ❌ Impossível continuar sem Firebase Core');
        _isInitialized = true; // Marcar como inicializado para não travar
        return;
      }
      
      // Inicializar Firebase Messaging APENAS se Firebase Core estiver pronto
      // e NÃO estiver na web (web usa service worker)
      if (!kIsWeb) {
        debugPrint('[FCM] Plataforma: ${defaultTargetPlatform.toString()}');
        
        // Aguardar um tick para garantir que Firebase Core está completamente pronto
        debugPrint('[FCM] Aguardando 300ms para Firebase Core estar pronto...');
        await Future.delayed(const Duration(milliseconds: 300));
        
        debugPrint('[FCM] Criando FirebaseMessaging.instance...');
        _fcm = FirebaseMessaging.instance;
        debugPrint('[FCM] ✅ FirebaseMessaging.instance criado com sucesso');
        
        // Aguardar FCM estar pronto antes de continuar
        debugPrint('[FCM] Aguardando mais 500ms para FCM estabilizar...');
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('[FCM] ✅ Delays completados');
      } else {
        debugPrint('[FCM] Web detectada, usando service worker');
        // Na web, o Firebase Messaging é gerenciado pelo service worker
        // Não inicializamos _fcm aqui
      }

      // 1. Permissões (Android 13+ e iOS) - só se não for web
      if (!kIsWeb && _fcm != null) {
        debugPrint('[FCM] Solicitando permissões...');
        await _requestPermission();
        debugPrint('[FCM] ✅ Permissões solicitadas');
      }

      // 2. Criar canal Android - só se for Android
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        debugPrint('[FCM] Criando canal de notificação Android...');
        await _localNotif
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(_channel);
        debugPrint('[FCM] ✅ Canal Android criado');
      }

      // 3. Configurar flutter_local_notifications - só se não for web
      if (!kIsWeb) {
        debugPrint('[FCM] Inicializando flutter_local_notifications...');
        const androidInit =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const initSettings = InitializationSettings(android: androidInit);
        await _localNotif.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onLocalNotifTap,
        );
        debugPrint('[FCM] ✅ flutter_local_notifications inicializado');
      }

      // 4. Foreground: FCM não exibe banner sozinho — fazemos via local notif
      if (!kIsWeb) {
        debugPrint('[FCM] Configurando listeners de mensagens...');
        FirebaseMessaging.onMessage.listen(_handleForeground);

        // 5. Background tap — app estava em background e usuário tocou
        FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

        // 6. App aberto a partir de notificação (estava morto)
        if (_fcm != null) {
          final initial = await _fcm!.getInitialMessage();
          if (initial != null) {
            debugPrint('[FCM] App aberto via notificação inicial');
            _handleTap(initial);
          }

          // 7. Registrar token no servidor sempre que renovar
          _fcm!.onTokenRefresh.listen(_sendTokenToServer);
        }
        debugPrint('[FCM] ✅ Listeners configurados');
      }

      // 8. Enviar token atual na inicialização (com verificação e retry)
      if (!kIsWeb && _fcm != null) {
        debugPrint('[FCM] Tentando obter token FCM...');
        final token = await _getTokenWithRetry();
        if (token != null) {
          debugPrint('[FCM] ✅ Token obtido: ${token.substring(0, 20)}...');
          await _sendTokenToServer(token);
        } else {
          debugPrint('[FCM] ⚠️ Não foi possível obter token após tentativas');
        }
      }

      _isInitialized = true;
      debugPrint('[FCM] ===== ✅ INICIALIZAÇÃO CONCLUÍDA COM SUCESSO =====');
    } catch (e, stackTrace) {
      debugPrint('[FCM] ===== ❌ ERRO NA INICIALIZAÇÃO =====');
      debugPrint('[FCM] Erro: $e');
      debugPrint('[FCM] StackTrace: $stackTrace');
      
      // IMPORTANTE: Marcar como inicializado mesmo com erro
      // para não ficar travado eternamente
      _isInitialized = true;
      debugPrint('[FCM] Marcado como inicializado (com erro) para não bloquear o app');
    }
  }

  // ── Permissão ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    if (_fcm == null) return;
    final settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,   // false = pede permissão explícita no Android 13+
    );
    debugPrint(
        '[FCM] Permission status: ${settings.authorizationStatus}');
  }

  // ── Token FCM ────────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    if (_fcm == null) {
      debugPrint('[FCM] getToken: FCM não inicializado');
      return null;
    }
    try {
      return await _fcm!.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  // Tenta obter token com retry (máximo 3 tentativas)
  Future<String?> _getTokenWithRetry({int maxAttempts = 3}) async {
    if (_fcm == null) {
      debugPrint('[FCM] _getTokenWithRetry: FCM não inicializado');
      return null;
    }

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        debugPrint('[FCM] Tentativa $attempt de $maxAttempts para obter token');
        final token = await _fcm!.getToken();
        if (token != null) {
          debugPrint('[FCM] Token obtido com sucesso na tentativa $attempt');
          return token;
        }
        debugPrint('[FCM] Token null na tentativa $attempt');
      } catch (e) {
        debugPrint('[FCM] Erro na tentativa $attempt: $e');
      }

      // Aguardar antes de tentar novamente (exceto na última tentativa)
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    debugPrint('[FCM] Não foi possível obter token após $maxAttempts tentativas');
    return null;
  }

  Future<void> _sendTokenToServer(String token) async {
    debugPrint('[FCM] Token: $token');
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) return; // usuário não logado ainda

    try {
      await _client.post(
        Uri.parse('${AppConstants.baseUrl}/notifications/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': token,
          'platform': kIsWeb 
              ? 'web' 
              : (defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios'),
        }),
      );
      debugPrint('[FCM] Token enviado ao servidor');
    } catch (e) {
      debugPrint('[FCM] Erro ao enviar token: $e');
    }
  }

  // Chama isso após o login para garantir que o token está atualizado
  Future<void> onUserLoggedIn() async {
    debugPrint('[Auth] onUserLoggedIn chamado');
    
    // Aguardar o FCM estar inicializado antes de tentar obter o token
    int attempts = 0;
    const maxAttempts = 10;
    const delayMs = 500;
    
    while (!_isInitialized && attempts < maxAttempts) {
      debugPrint('[Auth] Aguardando FCM inicializar... (tentativa ${attempts + 1}/$maxAttempts)');
      await Future.delayed(const Duration(milliseconds: delayMs));
      attempts++;
    }
    
    if (!_isInitialized) {
      debugPrint('[Auth] ⚠️ FCM não inicializado após ${maxAttempts * delayMs}ms');
      debugPrint('[Auth] Tentando inicializar novamente (lazy initialization)...');
      
      // Tentar inicializar novamente
      try {
        await initialize();
      } catch (e) {
        debugPrint('[Auth] Erro ao tentar reinicializar: $e');
      }
      
      // Verificar se agora está inicializado
      if (!_isInitialized) {
        debugPrint('[Auth] ❌ FCM ainda não está pronto, pulando registro de token');
        return;
      }
    }
    
    debugPrint('[Auth] ✅ FCM inicializado, obtendo token...');
    final token = await getToken();
    if (token != null) {
      debugPrint('[Auth] ✅ Token obtido, enviando ao servidor...');
      await _sendTokenToServer(token);
      debugPrint('[Auth] ✅ Token FCM registrado após login');
    } else {
      debugPrint('[Auth] ⚠️ Não foi possível obter token FCM');
    }
  }

  // Chama isso no logout para remover o token do servidor
  Future<void> onUserLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) return;

    try {
      await _client.delete(
        Uri.parse('${AppConstants.baseUrl}/notifications/token'),
        headers: {'Authorization': 'Bearer $authToken'},
      );
    } catch (_) {}
  }

  // ── Handlers de mensagem ─────────────────────────────────────────────────

  // App em FOREGROUND — FCM não mostra banner; exibimos via local notif
  void _handleForeground(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    _showLocalNotification(message);
    _incrementBadge();
  }

  // Usuário tocou na notificação
  void _handleTap(RemoteMessage message) {
    debugPrint('[FCM] Tap: ${message.notification?.title}');
    _resetBadge();
    onMessageTap?.call(message);
  }

  void _onLocalNotifTap(NotificationResponse resp) {
    // Toque em notificação local (foreground)
    _resetBadge();
  }

  // ── Exibir notificação local ──────────────────────────────────────────────

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;

    // Respeitar preferências do usuário
    final prefs = await _loadPrefs();
    final type = message.data['type'] ?? 'general';
    if (!_shouldShow(prefs, type)) return;

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1A3DB5), // primaryBlue
      styleInformation: BigTextStyleInformation(
        notif.body ?? '',
        contentTitle: notif.title,
      ),
    );

    await _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  }

  // Envia notificação LOCAL de teste (útil durante desenvolvimento)
  Future<void> showTestNotification({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF1A3DB5),
    );
    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode({'type': type}),
    );
  }

  // ── Badge (contador de não lidas) ─────────────────────────────────────────

  static Future<void> _incrementBadge() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_badgeKey) ?? 0;
    await prefs.setInt(_badgeKey, current + 1);
  }

  Future<void> _resetBadge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_badgeKey, 0);
  }

  Future<int> getBadgeCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_badgeKey) ?? 0;
  }

  // ── Preferências de notificação ───────────────────────────────────────────

  Future<NotifPrefs> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const NotifPrefs();
    try {
      return NotifPrefs.fromJson(jsonDecode(raw));
    } catch (_) {
      return const NotifPrefs();
    }
  }

  Future<void> savePrefs(NotifPrefs prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode(prefs.toJson()));
  }

  bool _shouldShow(NotifPrefs prefs, String type) {
    if (!prefs.allEnabled) return false;
    switch (type) {
      case 'meeting':
        return prefs.meetingsEnabled;
      case 'urgent':
        return prefs.urgentEnabled;
      default:
        return prefs.messagesEnabled;
    }
  }

  // ── Inscrição em tópicos FCM ───────────────────────────────────────────────
  // Permite que o servidor envie para grupos sem precisar de token individual

  Future<void> subscribeToClass(String className) async {
    if (_fcm == null) {
      debugPrint('[FCM] subscribeToClass: FCM não inicializado');
      return;
    }
    // Ex: "turma_1ano_a"
    final topic = _topicName(className);
    await _fcm!.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed: $topic');
  }

  Future<void> unsubscribeFromClass(String className) async {
    if (_fcm == null) return;
    await _fcm!.unsubscribeFromTopic(_topicName(className));
  }

  Future<void> subscribeToGlobal() async {
    if (_fcm == null) return;
    await _fcm!.subscribeToTopic('escola_geral');
  }

  String _topicName(String cls) =>
      'turma_${cls.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
}

// ─── Modelo de preferências ───────────────────────────────────────────────────

class NotifPrefs {
  final bool allEnabled;
  final bool messagesEnabled;
  final bool meetingsEnabled;
  final bool urgentEnabled;

  const NotifPrefs({
    this.allEnabled = true,
    this.messagesEnabled = true,
    this.meetingsEnabled = true,
    this.urgentEnabled = false,
  });

  NotifPrefs copyWith({
    bool? allEnabled,
    bool? messagesEnabled,
    bool? meetingsEnabled,
    bool? urgentEnabled,
  }) =>
      NotifPrefs(
        allEnabled: allEnabled ?? this.allEnabled,
        messagesEnabled: messagesEnabled ?? this.messagesEnabled,
        meetingsEnabled: meetingsEnabled ?? this.meetingsEnabled,
        urgentEnabled: urgentEnabled ?? this.urgentEnabled,
      );

  factory NotifPrefs.fromJson(Map<String, dynamic> j) => NotifPrefs(
        allEnabled: j['allEnabled'] ?? true,
        messagesEnabled: j['messagesEnabled'] ?? true,
        meetingsEnabled: j['meetingsEnabled'] ?? true,
        urgentEnabled: j['urgentEnabled'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'allEnabled': allEnabled,
        'messagesEnabled': messagesEnabled,
        'meetingsEnabled': meetingsEnabled,
        'urgentEnabled': urgentEnabled,
      };
}