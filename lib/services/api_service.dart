import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  String? _token;

  String? get token => _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> _saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', token);
    }
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  dynamic _decode(http.Response res) {
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    if (res.statusCode == 422 && body is Map && body['errors'] != null) {
      final firstError = (body['errors'] as Map).values.first;
      throw ApiException(firstError is List ? firstError.first : firstError.toString());
    }
    throw ApiException(body is Map && body['message'] != null
        ? body['message']
        : 'Request failed (${res.statusCode}).');
  }

  // ---- Auth --------------------------------------------------------------

  Future<AppUser> login(String email, String password) async {
    final res = await http.post(_uri('/login'),
        headers: _headers, body: jsonEncode({'email': email, 'password': password}));
    final data = _decode(res);
    await _saveToken(data['token']);
    return AppUser.fromJson(data['user']);
  }

  Future<AppUser> register(String name, String email, String password) async {
    final res = await http.post(_uri('/register'),
        headers: _headers,
        body: jsonEncode({'name': name, 'email': email, 'password': password}));
    final data = _decode(res);
    await _saveToken(data['token']);
    return AppUser.fromJson(data['user']);
  }

  Future<AppUser?> me() async {
    if (_token == null) return null;
    try {
      final res = await http.get(_uri('/me'), headers: _headers);
      final data = _decode(res);
      return AppUser.fromJson(data['user']);
    } on ApiException {
      await _saveToken(null);
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await http.post(_uri('/logout'), headers: _headers);
    } catch (_) {}
    await _saveToken(null);
  }

  // ---- Portfolio ---------------------------------------------------------

  Future<Freelancer?> portfolio() async {
    final res = await http.get(_uri('/portfolio'), headers: _headers);
    final data = _decode(res);
    return data['freelancer'] == null ? null : Freelancer.fromJson(data['freelancer']);
  }

  // ---- Tasks -------------------------------------------------------------

  Future<List<Task>> tasks() async {
    final res = await http.get(_uri('/tasks'), headers: _headers);
    final data = _decode(res);
    return (data['tasks'] as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<Task> createTask({
    required String title,
    required String description,
    String? category,
    String? budget,
    String? deadline,
  }) async {
    final res = await http.post(_uri('/tasks'),
        headers: _headers,
        body: jsonEncode({
          'title': title,
          'description': description,
          if (category != null && category.isNotEmpty) 'category': category,
          if (budget != null && budget.isNotEmpty) 'budget': budget,
          if (deadline != null && deadline.isNotEmpty) 'deadline': deadline,
        }));
    final data = _decode(res);
    return Task.fromJson(data['task']);
  }

  // ---- Chat --------------------------------------------------------------

  Future<List<ChatPartner>> chatPartners() async {
    final res = await http.get(_uri('/chat/partners'), headers: _headers);
    final data = _decode(res);
    return (data['partners'] as List).map((e) => ChatPartner.fromJson(e)).toList();
  }

  Future<List<Message>> messages(int userId) async {
    final res = await http.get(_uri('/chat/$userId/messages'), headers: _headers);
    final data = _decode(res);
    return (data['messages'] as List).map((e) => Message.fromJson(e)).toList();
  }

  Future<List<Message>> sendMessage(int userId, String body) async {
    final res = await http.post(_uri('/chat/$userId/messages'),
        headers: _headers, body: jsonEncode({'body': body}));
    final data = _decode(res);
    return (data['messages'] as List).map((e) => Message.fromJson(e)).toList();
  }
}
