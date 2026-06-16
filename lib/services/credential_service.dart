import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Container for cached credentials
class CachedCredentials {
  final String? email;
  final String? password;
  final bool rememberMe;

  CachedCredentials({
    this.email,
    this.password,
    this.rememberMe = false,
  });

  bool get hasCredentials => email != null && email!.isNotEmpty;
}

/// Service for securely caching and retrieving login credentials
/// 
/// Storage strategy:
/// - Email & rememberMe flag: shared_preferences (not sensitive)
/// - Password: flutter_secure_storage (encrypted)
/// - All credentials scoped by UserRole to avoid mixing admin/parent logins
class CredentialService {
  CredentialService._();
  static final CredentialService _instance = CredentialService._();
  factory CredentialService() => _instance;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  /// Build storage keys scoped by role to avoid credential mixing
  static String _emailKey(UserRole role) => 'credential_email_${role.name}';
  static String _passwordKey(UserRole role) => 'credential_password_${role.name}';
  static String _rememberMeKey(UserRole role) => 'credential_remember_${role.name}';

  /// Save credentials for a specific role
  /// 
  /// [email]: User's email (stored in shared_preferences)
  /// [password]: User's password (stored in flutter_secure_storage, encrypted)
  /// [role]: Which role these credentials belong to (admin/parent)
  /// [rememberMe]: Whether to remember these credentials
  Future<void> saveCredentials({
    required String email,
    required String password,
    required UserRole role,
    bool rememberMe = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (rememberMe) {
        // Save email and flag in shared_preferences (not sensitive)
        await prefs.setString(_emailKey(role), email);
        await prefs.setBool(_rememberMeKey(role), true);
        
        // Save password securely in flutter_secure_storage (encrypted)
        await _secureStorage.write(
          key: _passwordKey(role),
          value: password,
        );
        
        debugPrint('Credentials saved for ${role.name} role');
      } else {
        // User unchecked "Remember me" - clear all credentials for this role
        await clearAll(role);
        debugPrint('Credentials cleared (remember not checked) for ${role.name} role');
      }
    } catch (e) {
      debugPrint('Error saving credentials: $e');
      rethrow;
    }
  }

  /// Load cached credentials for a specific role
  /// 
  /// Returns [CachedCredentials] with email, password, and rememberMe flag
  /// Returns empty CachedCredentials if none exist
  Future<CachedCredentials> loadCredentials(UserRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final email = prefs.getString(_emailKey(role));
      final rememberMe = prefs.getBool(_rememberMeKey(role)) ?? false;
      
      // Email might exist without password if credentials were partially cleared
      if (email == null || email.isEmpty) {
        return CachedCredentials(rememberMe: false);
      }
      
      // Load password from secure storage
      String? password;
      if (rememberMe) {
        password = await _secureStorage.read(key: _passwordKey(role));
      }
      
      debugPrint('Credentials loaded for ${role.name} role: email=$email, hasPassword=${password != null}');
      
      return CachedCredentials(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
    } catch (e) {
      debugPrint('Error loading credentials: $e');
      return CachedCredentials(rememberMe: false);
    }
  }

  /// Clear only the password for a role (keep email for convenience)
  /// 
  /// Called during logout to remove password but keep email prefilled
  Future<void> clearPassword(UserRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear password from secure storage
      await _secureStorage.delete(key: _passwordKey(role));
      
      // Clear remember flag but keep email
      await prefs.remove(_rememberMeKey(role));
      
      debugPrint('Password cleared for ${role.name} role (email retained)');
    } catch (e) {
      debugPrint('Error clearing password: $e');
    }
  }

  /// Clear all credentials for a role (email, password, remember flag)
  /// 
  /// Called when user explicitly unchecks "Remember me" before login
  Future<void> clearAll(UserRole role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all keys for this role
      await prefs.remove(_emailKey(role));
      await prefs.remove(_rememberMeKey(role));
      await _secureStorage.delete(key: _passwordKey(role));
      
      debugPrint('All credentials cleared for ${role.name} role');
    } catch (e) {
      debugPrint('Error clearing all credentials: $e');
    }
  }

  /// Clear credentials for all roles (when user wants complete reset)
  Future<void> clearAllRoles() async {
    try {
      await clearAll(UserRole.admin);
      await clearAll(UserRole.parent);
      debugPrint('All credentials cleared for all roles');
    } catch (e) {
      debugPrint('Error clearing credentials for all roles: $e');
    }
  }

  /// Get credential statistics (for debugging)
  Future<Map<String, dynamic>> getStats() async {
    try {
      final adminCreds = await loadCredentials(UserRole.admin);
      final parentCreds = await loadCredentials(UserRole.parent);
      
      return {
        'admin': {
          'hasEmail': adminCreds.email != null && adminCreds.email!.isNotEmpty,
          'hasPassword': adminCreds.password != null && adminCreds.password!.isNotEmpty,
          'rememberMe': adminCreds.rememberMe,
        },
        'parent': {
          'hasEmail': parentCreds.email != null && parentCreds.email!.isNotEmpty,
          'hasPassword': parentCreds.password != null && parentCreds.password!.isNotEmpty,
          'rememberMe': parentCreds.rememberMe,
        },
      };
    } catch (e) {
      debugPrint('Error getting credential stats: $e');
      return {};
    }
  }
}
