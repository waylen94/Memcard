import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';

const _kTokenKey = 'auth_token';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required ApiService apiService}) : _api = apiService;

  final ApiService _api;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _token;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ---------------------------------------------------------------------------
  // Initialisation — call once at app startup
  // ---------------------------------------------------------------------------

  Future<void> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_kTokenKey);
    if (savedToken == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final user = await _api.getMe(token: savedToken);
      _token = savedToken;
      _user = user;
      _status = AuthStatus.authenticated;
    } catch (_) {
      await prefs.remove(_kTokenKey);
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Auth actions
  // ---------------------------------------------------------------------------

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    _errorMessage = null;
    try {
      final result = await _api.register(
        name: name,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );
      await _persistAndSet(result.user, result.token);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _errorMessage = null;
    try {
      final result = await _api.login(email: email, password: password);
      await _persistAndSet(result.user, result.token);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final t = _token;
    if (t != null) {
      try {
        await _api.logout(token: t);
      } catch (_) {
        // Best-effort — clear locally regardless.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    _token = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _persistAndSet(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    _token = token;
    _user = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
}
