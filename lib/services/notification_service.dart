import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../utils/app_theme.dart';

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

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  // Chave para contagem de notificações não lidas (badge)
  static const _badgeKey = 'notif_badge_count';
  // Chave para preferências salvas
  static const _prefsKey = 'notif_prefs';

  // Callback para quando o usuário toca na notificação
  // A tela que quiser ouvir pode registrar aqui
  ValueChanged<RemoteMessage>? onMessageTap;

  // ── Inicialização ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // 1. Permissões (Android 13+ e iOS)
    await _requestPermission();

    // 2. Criar canal Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Configurar flutter_local_notifications
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );

    // 4. Foreground: FCM não exibe banner sozinho — fazemos via local notif
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 5. Background tap — app estava em background e usuário tocou
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 6. App aberto a partir de notificação (estava morto)
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // 7. Registrar token no servidor sempre que renovar
    _fcm.onTokenRefresh.listen(_sendTokenToServer);

    // 8. Enviar token atual na inicialização
    final token = await getToken();
    if (token != null) await _sendTokenToServer(token);
  }

  // ── Permissão ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
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
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    debugPrint('[FCM] Token: $token');
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) return; // usuário não logado ainda

    try {
      await http.post(
        Uri.parse('${AppConstants.baseUrl}/notifications/token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }),
      );
      debugPrint('[FCM] Token enviado ao servidor');
    } catch (e) {
      debugPrint('[FCM] Erro ao enviar token: $e');
    }
  }

  // Chama isso após o login para garantir que o token está atualizado
  Future<void> onUserLoggedIn() async {
    final token = await getToken();
    if (token != null) await _sendTokenToServer(token);
  }

  // Chama isso no logout para remover o token do servidor
  Future<void> onUserLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    if (authToken == null) return;

    try {
      await http.delete(
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
    // Ex: "turma_1ano_a"
    final topic = _topicName(className);
    await _fcm.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed: $topic');
  }

  Future<void> unsubscribeFromClass(String className) async {
    await _fcm.unsubscribeFromTopic(_topicName(className));
  }

  Future<void> subscribeToGlobal() async {
    await _fcm.subscribeToTopic('escola_geral');
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