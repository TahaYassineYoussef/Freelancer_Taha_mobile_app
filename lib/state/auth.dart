import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_service.dart';

class AuthState extends ChangeNotifier {
  final ApiService api = ApiService();

  AppUser? user;
  bool loading = true;

  bool get isLoggedIn => user != null;

  /// Called once at startup — restores a saved session if present.
  ///
  /// Never rethrows: if the token or the /me call fails (server down, no
  /// network), we fall through to the login screen instead of leaving the app
  /// stuck on its loading spinner.
  Future<void> bootstrap() async {
    try {
      await api.loadToken();
      user = await api.me();
    } catch (_) {
      user = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    user = await api.login(email, password);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    user = await api.register(name, email, password);
    notifyListeners();
  }

  /// Completes a Google sign-in that finished in the web view.
  Future<void> signInWithToken(String token) async {
    user = await api.adoptToken(token);
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    notifyListeners();
  }
}
