import 'package:flutter/foundation.dart';

class ApiState extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Future<T> execute<T>(Future<T> Function() apiCall) async {
    setLoading(true);
    setError(null);
    try {
      final result = await apiCall();
      setLoading(false);
      return result;
    } catch (e) {
      setError(e.toString());
      setLoading(false);
      rethrow;
    }
  }
}