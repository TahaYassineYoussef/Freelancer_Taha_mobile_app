import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_service.dart';

class AuthState extends ChangeNotifier {
  final ApiService api = ApiService();

  AppUser? user;
  bool loading = true;

  bool get isLoggedIn => user != null;

  /// Called once at startup — restores a saved session if present.
  Future<void> bootstrap() async {
    await api.loadToken();
    user = await api.me();
    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    user = await api.login(email, password);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    user = await api.register(name, email, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    notifyListeners();
  }
}
