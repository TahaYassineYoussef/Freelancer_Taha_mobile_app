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

  /// Adopts a token obtained out-of-band (the Google web-view flow) and
  /// resolves the user it belongs to.
  Future<AppUser?> adoptToken(String token) async {
    await _saveToken(token);
    return me();
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

  Future<Freelancer?> portfolio({String locale = 'en'}) async {
    final res = await http.get(_uri('/portfolio?locale=$locale'), headers: _headers);
    final data = _decode(res);
    return data['freelancer'] == null ? null : Freelancer.fromJson(data['freelancer']);
  }

  // ---- Localization ------------------------------------------------------

  /// UI strings for [locale], already layered over English by the server.
  Future<Map<String, String>> translations(String locale) async {
    final res = await http.get(_uri('/translations/$locale'), headers: _headers);
    final data = _decode(res);
    return ((data['messages'] as Map?) ?? {})
        .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  // ---- Tasks -------------------------------------------------------------

  Future<TaskPage> tasks() async {
    final res = await http.get(_uri('/tasks'), headers: _headers);
    return TaskPage.fromJson(_decode(res));
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

  /// Client approves a delivered task → completed.
  Future<Task> approveTask(int taskId) async {
    final res = await http.post(_uri('/tasks/$taskId/approve'), headers: _headers);
    return Task.fromJson(_decode(res)['task']);
  }

  /// Client sends the delivery back for changes → in progress.
  Future<Task> requestChanges(int taskId, String note) async {
    final res = await http.post(_uri('/tasks/$taskId/request-changes'),
        headers: _headers, body: jsonEncode({'note': note}));
    return Task.fromJson(_decode(res)['task']);
  }

  Future<void> deleteTask(int taskId) async {
    final res = await http.delete(_uri('/tasks/$taskId'), headers: _headers);
    _decode(res);
  }

  // ---- Task actions (freelancer) -----------------------------------------

  Future<Task> acceptTask(int taskId) async {
    final res = await http.post(_uri('/tasks/$taskId/accept'), headers: _headers);
    return Task.fromJson(_decode(res)['task']);
  }

  Future<Task> declineTask(int taskId) async {
    final res = await http.post(_uri('/tasks/$taskId/decline'), headers: _headers);
    return Task.fromJson(_decode(res)['task']);
  }

  Future<Task> deliverTask(int taskId, {String? note, String? link}) async {
    final res = await http.post(_uri('/tasks/$taskId/deliver'),
        headers: _headers,
        body: jsonEncode({
          if (note != null && note.isNotEmpty) 'deliverable_note': note,
          if (link != null && link.isNotEmpty) 'deliverable_link': link,
        }));
    return Task.fromJson(_decode(res)['task']);
  }

  // ---- Payments ----------------------------------------------------------

  Future<PaymentConfig> paymentConfig() async {
    final res = await http.get(_uri('/payments/config'), headers: _headers);
    return PaymentConfig.fromJson(_decode(res));
  }

  /// Records a captured PayPal order against the task.
  Future<void> payWithPaypal(int taskId, String orderId) async {
    final res = await http.post(_uri('/tasks/$taskId/pay'),
        headers: _headers, body: jsonEncode({'provider_order_id': orderId}));
    _decode(res);
  }

  /// Declares a D17 transfer (held pending until Taha confirms it).
  Future<void> payWithD17(int taskId, String reference) async {
    final res = await http.post(_uri('/tasks/$taskId/d17'),
        headers: _headers, body: jsonEncode({'provider_order_id': reference}));
    _decode(res);
  }

  // ---- Freelancer console ------------------------------------------------

  Future<FreelancerDashboard> freelancerDashboard() async {
    final res = await http.get(_uri('/freelancer/dashboard'), headers: _headers);
    return FreelancerDashboard.fromJson(_decode(res));
  }

  Future<PaymentsPage> freelancerPayments() async {
    final res = await http.get(_uri('/freelancer/payments'), headers: _headers);
    return PaymentsPage.fromJson(_decode(res));
  }

  /// Confirm or reject a declared payment. [status] is `completed` or `failed`.
  Future<String> reviewPayment(int paymentId, String status) async {
    final res = await http.patch(_uri('/freelancer/payments/$paymentId'),
        headers: _headers, body: jsonEncode({'status': status}));
    return _decode(res)['message'] ?? 'Payment updated.';
  }

  Future<List<Revision>> revisions() async {
    final res = await http.get(_uri('/freelancer/revisions'), headers: _headers);
    final data = _decode(res);
    return (data['revisions'] as List).map((e) => Revision.fromJson(e)).toList();
  }

  Future<List<ReviewRow>> freelancerReviews() async {
    final res = await http.get(_uri('/freelancer/reviews'), headers: _headers);
    final data = _decode(res);
    return (data['reviews'] as List).map((e) => ReviewRow.fromJson(e)).toList();
  }

  /// Publish or hide a review.
  Future<String> moderateReview(int reviewId, bool approved) async {
    final res = await http.patch(_uri('/freelancer/reviews/$reviewId'),
        headers: _headers, body: jsonEncode({'approved': approved}));
    return _decode(res)['message'] ?? 'Review updated.';
  }

  // ---- Admin console -----------------------------------------------------

  Future<VisitorStats> visitors() async {
    final res = await http.get(_uri('/admin/visitors'), headers: _headers);
    return VisitorStats.fromJson(_decode(res));
  }

  Future<BookingsPage> bookings() async {
    final res = await http.get(_uri('/admin/bookings'), headers: _headers);
    return BookingsPage.fromJson(_decode(res));
  }

  /// [status] is `confirmed` or `declined`.
  Future<String> reviewBooking(int bookingId, String status) async {
    final res = await http.patch(_uri('/admin/bookings/$bookingId'),
        headers: _headers, body: jsonEncode({'status': status}));
    return _decode(res)['message'] ?? 'Booking updated.';
  }

  Future<List<DaySchedule>> availability() async {
    final res = await http.get(_uri('/admin/availability'), headers: _headers);
    final data = _decode(res);
    return (data['schedule'] as List).map((e) => DaySchedule.fromJson(e)).toList();
  }

  Future<List<DaySchedule>> saveAvailability(DaySchedule day) async {
    final res = await http.patch(_uri('/admin/availability'),
        headers: _headers,
        body: jsonEncode({
          'day': day.day,
          'is_open': day.isOpen,
          'start_time': day.startTime,
          'end_time': day.endTime,
        }));
    final data = _decode(res);
    return (data['schedule'] as List).map((e) => DaySchedule.fromJson(e)).toList();
  }

  Future<List<InboxMessage>> inbox() async {
    final res = await http.get(_uri('/admin/inbox'), headers: _headers);
    final data = _decode(res);
    return (data['messages'] as List).map((e) => InboxMessage.fromJson(e)).toList();
  }

  Future<void> markMessageRead(int id) async {
    final res = await http.patch(_uri('/admin/inbox/$id/read'), headers: _headers);
    _decode(res);
  }

  Future<void> deleteMessage(int id) async {
    final res = await http.delete(_uri('/admin/inbox/$id'), headers: _headers);
    _decode(res);
  }

  Future<BlockedPage> blocked() async {
    final res = await http.get(_uri('/admin/blocked'), headers: _headers);
    return BlockedPage.fromJson(_decode(res));
  }

  Future<void> deleteBlocked(int id) async {
    final res = await http.delete(_uri('/admin/blocked/$id'), headers: _headers);
    _decode(res);
  }

  Future<PaymentSettings> paymentSettings() async {
    final res = await http.get(_uri('/admin/payment-settings'), headers: _headers);
    return PaymentSettings.fromJson(_decode(res));
  }

  Future<String> savePaymentSettings({
    required String paypalEmail,
    required String paypalClientId,
    required bool paypalEnabled,
    required String d17Number,
    required bool d17Enabled,
  }) async {
    final res = await http.patch(_uri('/admin/payment-settings'),
        headers: _headers,
        body: jsonEncode({
          'paypal_email': paypalEmail.isEmpty ? null : paypalEmail,
          'paypal_client_id': paypalClientId.isEmpty ? null : paypalClientId,
          'paypal_enabled': paypalEnabled,
          'd17_number': d17Number.isEmpty ? null : d17Number,
          'd17_enabled': d17Enabled,
        }));
    return _decode(res)['message'] ?? 'Payment settings saved.';
  }

  Future<CvOverview> cv() async {
    final res = await http.get(_uri('/admin/cv'), headers: _headers);
    return CvOverview.fromJson(_decode(res));
  }

  Future<String> updateCvProfile(Map<String, String> fields) async {
    final res = await http.patch(_uri('/admin/cv/profile'),
        headers: _headers, body: jsonEncode(fields));
    return _decode(res)['message'] ?? 'Profile updated.';
  }

  // ---- Calls -------------------------------------------------------------

  /// Drains every call signal addressed to me. Signals are consumed once.
  Future<List<Map<String, dynamic>>> pollCalls() async {
    final res = await http.get(_uri('/calls/poll'), headers: _headers);
    final data = _decode(res);
    return (data['signals'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> sendCallSignal({
    required int toId,
    required String kind,
    String? payload,
  }) async {
    final res = await http.post(_uri('/calls/signal'),
        headers: _headers,
        body: jsonEncode({
          'to_id': toId,
          'kind': kind,
          if (payload != null) 'payload': payload,
        }));
    _decode(res);
  }

  /// Drops the call-log card into the conversation.
  Future<void> logCall({
    required int toId,
    required String kind,
    required String status,
    int? seconds,
  }) async {
    final res = await http.post(_uri('/calls/log'),
        headers: _headers,
        body: jsonEncode({
          'to_id': toId,
          'kind': kind,
          'status': status,
          if (seconds != null) 'seconds': seconds,
        }));
    _decode(res);
  }

  // ---- Deliveries --------------------------------------------------------

  Future<List<Delivery>> deliveries() async {
    final res = await http.get(_uri('/deliveries'), headers: _headers);
    final data = _decode(res);
    return (data['deliveries'] as List).map((e) => Delivery.fromJson(e)).toList();
  }

  // ---- Reviews -----------------------------------------------------------

  Future<String> submitReview({
    required int rating,
    required String body,
    String? roleTitle,
    int? taskId,
  }) async {
    final res = await http.post(_uri('/testimonials'),
        headers: _headers,
        body: jsonEncode({
          'rating': rating,
          'body': body,
          if (roleTitle != null && roleTitle.isNotEmpty) 'role_title': roleTitle,
          if (taskId != null) 'task_id': taskId,
        }));
    return _decode(res)['message'] ?? 'Thanks for your review!';
  }

  // ---- Contact -----------------------------------------------------------

  Future<String> sendContact({
    required String name,
    required String email,
    String? subject,
    required String body,
  }) async {
    final res = await http.post(_uri('/contact'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'email': email,
          if (subject != null && subject.isNotEmpty) 'subject': subject,
          'body': body,
        }));
    return _decode(res)['message'] ?? 'Message sent.';
  }

  // ---- Notifications -----------------------------------------------------

  Future<NotificationFeed> notifications() async {
    final res = await http.get(_uri('/notifications'), headers: _headers);
    return NotificationFeed.fromJson(_decode(res));
  }

  Future<void> markAllNotificationsRead() async {
    final res = await http.post(_uri('/notifications/read'), headers: _headers);
    _decode(res);
  }

  Future<void> markNotificationRead(String id) async {
    final res = await http.post(_uri('/notifications/$id/read'), headers: _headers);
    _decode(res);
  }

  // ---- Profile -----------------------------------------------------------

  Future<AppUser> updateProfile({required String name, required String email}) async {
    final res = await http.patch(_uri('/profile'),
        headers: _headers, body: jsonEncode({'name': name, 'email': email}));
    return AppUser.fromJson(_decode(res)['user']);
  }

  Future<String> updatePassword({
    required String currentPassword,
    required String password,
  }) async {
    final res = await http.put(_uri('/profile/password'),
        headers: _headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'password': password,
          'password_confirmation': password,
        }));
    return _decode(res)['message'] ?? 'Password updated.';
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
