import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../screens/auth/role_selection_screen.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static void Function()? onSessionExpired;

  final ApiService _api = ApiService();

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get isAdmin => _user?.role == UserRole.admin;

  Future<void> init() async {
    onSessionExpired = sessionExpired;
    await _api.loadToken();
    final stored = await _api.getStoredUser();
    if (stored != null) {
      _user = stored;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password, UserRole role, {bool remember = false}) async {
    _error = null;
    try {
      _user = await _api.login(email, password, role, remember: remember);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Erro de conexão. Verifique sua internet.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void sessionExpired() {
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    // Redirecionar para login
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    try {
      _user = await _api.updateProfile(updates);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String email, String currentPassword, String newPassword) async {
    _error = null;
    try {
      _user = await _api.login(email, currentPassword, UserRole.parent);
      await _api.changePassword(currentPassword, newPassword);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Erro de conexão. Verifique sua internet.';
      notifyListeners();
      return false;
    }
  }
}