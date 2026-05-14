import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';

class ApiInterceptor {
  static Future<http.Response> intercept(http.Response response, BuildContext? context) async {
    if (response.statusCode == 401) {
      // Token expirado ou inválido
      await ApiService().clearToken();
      if (context != null && context.mounted) {
        // Navegar para login
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sessão expirada. Faça login novamente.')),
        );
      }
    }
    return response;
  }
}