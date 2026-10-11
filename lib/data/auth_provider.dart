import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../services/api_service.dart';

const _kTokenKey = 'auth_token';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required ApiService apiService, this.clearAccountData})
    : _api = apiService;

  final ApiService _api;
  final Future<void> Function()? clearAccountData;
  bool _deletingAccount = false;
  bool get isDeletingAccount => _deletingAccount;

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
    if (_deletingAccount) return;
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

  Future<bool> deleteAccount() async {
    final t = _token;
    if (t == null || _deletingAccount) return false;
    _deletingAccount = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _api.deleteAccount(token: t);
    } on ApiException catch (e) {
      _errorMessage = e.statusCode == 404 || e.statusCode == 405
          ? 'Account deletion is currently unavailable. Please try again later.'
          : e.message;
      _deletingAccount = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage =
          'Could not confirm account deletion. Check your connection and try again.';
      _deletingAccount = false;
      notifyListeners();
      return false;
    }

    // Only clear the session after the server confirms permanent deletion.
    _token = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.remove(_kTokenKey)) {
        throw StateError('Could not remove the saved session.');
      }
    } catch (_) {
      _errorMessage =
          'Your account was deleted, but some data could not be removed from this device.';
    }
    try {
      await clearAccountData?.call();
    } catch (_) {
      _errorMessage =
          'Your account was deleted, but some data could not be removed from this device.';
    } finally {
      _deletingAccount = false;
      notifyListeners();
    }
    return true;
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
