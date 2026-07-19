import 'config.dart';

/// Coerce a JSON value that may arrive as an int, a numeric String, or null
/// (e.g. year columns the API serialises as strings) into an [int?].
int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

class AppUser {
  final int id;
  final String name;
  final String email;
  final String role;

  AppUser({required this.id, required this.name, required this.email, required this.role});

  bool get isFreelancer => role == 'freelancer';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        role: j['role'] ?? 'client',
      );
}

class Skill {
  final String name;
  final int level;
  Skill({required this.name, required this.level});
  factory Skill.fromJson(Map<String, dynamic> j) =>
      Skill(name: j['name'] ?? '', level: (j['level'] ?? 0) is int ? j['level'] : int.tryParse('${j['level']}') ?? 0);
}

class Service {
  final String title;
  final String? description;
  final String? price;
  Service({required this.title, this.description, this.price});
  factory Service.fromJson(Map<String, dynamic> j) => Service(
        title: j['title'] ?? '',
        description: j['description'],
        price: j['price']?.toString(),
      );
}

class Experience {
  final String position;
  final String company;
  final String? location;
  final String? description;
  final String? startDate;
  final String? endDate;
  final bool isCurrent;
  Experience({
    required this.position,
    required this.company,
    this.location,
    this.description,
    this.startDate,
    this.endDate,
    this.isCurrent = false,
  });
  factory Experience.fromJson(Map<String, dynamic> j) => Experience(
        position: j['position'] ?? '',
        company: j['company'] ?? '',
        location: j['location'],
        description: j['description'],
        startDate: j['start_date'],
        endDate: j['end_date'],
        isCurrent: j['is_current'] == true || j['is_current'] == 1,
      );
}

class Diploma {
  final String title;
  final String institution;
  final String? field;
  final int? startYear;
  final int? endYear;
  final String? description;
  Diploma({
    required this.title,
    required this.institution,
    this.field,
    this.startYear,
    this.endYear,
    this.description,
  });
  factory Diploma.fromJson(Map<String, dynamic> j) => Diploma(
        title: j['title'] ?? '',
        institution: j['institution'] ?? '',
        field: j['field'],
        startYear: _asInt(j['start_year']),
        endYear: _asInt(j['end_year']),
        description: j['description'],
      );
}

class Project {
  final String title;
  final String? description;
  final String? techStack;
  final String? imageUrl;
  final String? videoUrl;
  final String? liveUrl;
  final String? githubUrl;
  Project({
    required this.title,
    this.description,
    this.techStack,
    this.imageUrl,
    this.videoUrl,
    this.liveUrl,
    this.githubUrl,
  });
  factory Project.fromJson(Map<String, dynamic> j) => Project(
        title: j['title'] ?? '',
        description: j['description'],
        techStack: j['tech_stack'],
        imageUrl: mediaUrl(j['image_url']),
        videoUrl: mediaUrl(j['video_url']),
        liveUrl: j['live_url'],
        githubUrl: j['github_url'],
      );

  /// Uploaded image if present, otherwise the YouTube thumbnail from [liveUrl].
  String? get thumbnailUrl => imageUrl ?? youtubeThumbnail(liveUrl);

  /// A link the project media can open when tapped: the live/YouTube link
  /// first, then any uploaded video.
  String? get watchUrl => liveUrl ?? videoUrl;
}

class Freelancer {
  final String name;
  final String? email;
  final String? headline;
  final String? bio;
  final String? location;
  final String? phone;
  final String? avatarUrl;
  final List<Skill> skills;
  final List<Service> services;
  final List<Experience> experiences;
  final List<Experience> internships;
  final List<Diploma> diplomas;
  final List<Project> projects;
  final List<Testimonial> testimonials;
  final String? cvUrl;

  Freelancer({
    required this.name,
    this.email,
    this.headline,
    this.bio,
    this.location,
    this.phone,
    this.avatarUrl,
    this.skills = const [],
    this.services = const [],
    this.experiences = const [],
    this.internships = const [],
    this.diplomas = const [],
    this.projects = const [],
    this.testimonials = const [],
    this.cvUrl,
  });

  static List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      (v as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();

  factory Freelancer.fromJson(Map<String, dynamic> j) => Freelancer(
        name: j['name'] ?? '',
        email: j['email'],
        headline: j['headline'],
        bio: j['bio'],
        location: j['location'],
        phone: j['phone'],
        avatarUrl: mediaUrl(j['avatar_url']),
        skills: _list(j['skills'], Skill.fromJson),
        services: _list(j['services'], Service.fromJson),
        experiences: _list(j['experiences'], Experience.fromJson),
        internships: _list(j['internships'], Experience.fromJson),
        diplomas: _list(j['diplomas'], Diploma.fromJson),
        projects: _list(j['projects'], Project.fromJson),
        testimonials: _list(j['testimonials'], Testimonial.fromJson),
        cvUrl: j['cv_url'],
      );
}

class Task {
  final int id;
  final String title;
  final String description;
  final String? category;
  final String? budget;
  final String? deadline;
  final String status;
  final bool isPaid;
  final bool pendingPayment;
  final String? clientName;
  final String? createdAt;
  // Delivery from the freelancer
  final String? deliverableNote;
  final String? deliverableLink;
  final String? deliverableUrl;
  final String? deliveredAt;
  final String? revisionNote;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    this.budget,
    this.deadline,
    required this.status,
    this.isPaid = false,
    this.pendingPayment = false,
    this.clientName,
    this.createdAt,
    this.deliverableNote,
    this.deliverableLink,
    this.deliverableUrl,
    this.deliveredAt,
    this.revisionNote,
  });

  /// True when the client still owes money on this task.
  bool get isPayable => !isPaid && !pendingPayment && budget != null;

  /// True when there is anything to show in the delivery panel.
  bool get hasDelivery =>
      deliverableUrl != null || deliverableLink != null || (deliverableNote?.isNotEmpty ?? false);

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        category: j['category'],
        budget: j['budget']?.toString(),
        deadline: j['deadline'],
        status: j['status'] ?? 'open',
        isPaid: j['is_paid'] == true,
        pendingPayment: j['pending_payment'] == true,
        clientName: j['client']?['name'],
        createdAt: j['created_at'],
        deliverableNote: j['deliverable_note'],
        deliverableLink: j['deliverable_link'],
        deliverableUrl: mediaUrl(j['deliverable_url']),
        deliveredAt: j['delivered_at'],
        revisionNote: j['revision_note'],
      );
}

/// A task list plus the per-status counts used by the filter chips.
class TaskPage {
  final List<Task> tasks;
  final Map<String, int> counts;
  TaskPage({required this.tasks, this.counts = const {}});

  factory TaskPage.fromJson(Map<String, dynamic> j) => TaskPage(
        tasks: (j['tasks'] as List? ?? []).map((e) => Task.fromJson(e)).toList(),
        counts: ((j['counts'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), _asInt(v) ?? 0)),
      );
}

/// Which payment methods the freelancer has switched on in Payment Settings.
class PaymentConfig {
  final bool paypalEnabled;
  final String? paypalClientId;
  final String paypalCurrency;
  final bool d17Enabled;
  final String? d17Number;
  final String? d17QrUrl;

  PaymentConfig({
    this.paypalEnabled = false,
    this.paypalClientId,
    this.paypalCurrency = 'USD',
    this.d17Enabled = false,
    this.d17Number,
    this.d17QrUrl,
  });

  /// Mirrors the web: a method shows only when the toggle is on AND the
  /// credential exists (client id for PayPal, wallet number for D17).
  bool get showPaypal => paypalEnabled && (paypalClientId?.isNotEmpty ?? false);
  bool get showD17 => d17Enabled && (d17Number?.isNotEmpty ?? false);
  bool get any => showPaypal || showD17;

  factory PaymentConfig.fromJson(Map<String, dynamic> j) {
    final p = (j['paypal'] as Map?) ?? {};
    final d = (j['d17'] as Map?) ?? {};
    return PaymentConfig(
      paypalEnabled: p['enabled'] == true,
      paypalClientId: p['client_id'],
      paypalCurrency: p['currency'] ?? 'USD',
      d17Enabled: d['enabled'] == true,
      d17Number: d['number'],
      d17QrUrl: mediaUrl(d['qr_url']),
    );
  }
}

class Delivery {
  final int id;
  final String title;
  final String status;
  final String? note;
  final String? link;
  final String? fileUrl;
  final String? deliveredAt;

  Delivery({
    required this.id,
    required this.title,
    required this.status,
    this.note,
    this.link,
    this.fileUrl,
    this.deliveredAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
        id: j['id'],
        title: j['title'] ?? '',
        status: j['status'] ?? '',
        note: j['deliverable_note'],
        link: j['deliverable_link'],
        fileUrl: mediaUrl(j['deliverable_url']),
        deliveredAt: j['delivered_at'],
      );
}

class Testimonial {
  final int id;
  final int rating;
  final String body;
  final String? roleTitle;
  final String? author;
  final String? createdAt;

  Testimonial({
    required this.id,
    required this.rating,
    required this.body,
    this.roleTitle,
    this.author,
    this.createdAt,
  });

  factory Testimonial.fromJson(Map<String, dynamic> j) => Testimonial(
        id: j['id'],
        rating: _asInt(j['rating']) ?? 0,
        body: j['body'] ?? '',
        roleTitle: j['role_title'],
        author: j['author'],
        createdAt: j['created_at'],
      );
}

class AppNotification {
  final String id;
  final bool read;
  final String title;
  final String message;
  final String? icon;
  final String? type;
  final String? createdAt;

  AppNotification({
    required this.id,
    required this.read,
    required this.title,
    required this.message,
    this.icon,
    this.type,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'].toString(),
        read: j['read'] == true,
        title: j['title'] ?? '',
        message: j['message'] ?? '',
        icon: j['icon'],
        type: j['type'],
        createdAt: j['created_at'],
      );
}

class NotificationFeed {
  final int unread;
  final List<AppNotification> items;
  NotificationFeed({this.unread = 0, this.items = const []});

  factory NotificationFeed.fromJson(Map<String, dynamic> j) => NotificationFeed(
        unread: _asInt(j['unread']) ?? 0,
        items: (j['items'] as List? ?? []).map((e) => AppNotification.fromJson(e)).toList(),
      );
}

class ChatPartner {
  final int id;
  final String name;
  final String role;
  final int unread;
  ChatPartner({required this.id, required this.name, required this.role, this.unread = 0});
  factory ChatPartner.fromJson(Map<String, dynamic> j) => ChatPartner(
        id: j['id'],
        name: j['name'] ?? '',
        role: j['role'] ?? '',
        unread: _asInt(j['unread']) ?? 0,
      );
}

class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String body;
  final String? createdAt;
  final bool read;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentMime;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    this.createdAt,
    this.read = false,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentMime,
  });

  bool get hasAttachment => attachmentUrl != null;
  bool get isImage => attachmentMime?.startsWith('image/') ?? false;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        senderId: j['sender_id'],
        receiverId: j['receiver_id'],
        body: j['body'] ?? '',
        createdAt: j['created_at'],
        read: j['read'] == true,
        attachmentUrl: mediaUrl(j['attachment_url']),
        attachmentName: j['attachment_name'],
        attachmentMime: j['attachment_mime'],
      );
}

// ---- Freelancer console ----------------------------------------------------

class FreelancerKpis {
  final double revenue;
  final String currency;
  final int accepted;
  final int? onTimePct;
  final int clients;

  FreelancerKpis({
    this.revenue = 0,
    this.currency = 'USD',
    this.accepted = 0,
    this.onTimePct,
    this.clients = 0,
  });

  factory FreelancerKpis.fromJson(Map<String, dynamic> j) => FreelancerKpis(
        revenue: (j['revenue'] as num?)?.toDouble() ?? 0,
        currency: j['currency'] ?? 'USD',
        accepted: _asInt(j['accepted']) ?? 0,
        onTimePct: _asInt(j['on_time_pct']),
        clients: _asInt(j['clients']) ?? 0,
      );
}

class LatestClient {
  final String name;
  final String task;
  final bool paid;
  LatestClient({required this.name, required this.task, this.paid = false});

  factory LatestClient.fromJson(Map<String, dynamic> j) => LatestClient(
        name: j['name'] ?? '',
        task: j['task'] ?? '',
        paid: j['paid'] == true,
      );
}

class FreelancerDashboard {
  final FreelancerKpis kpis;
  final Map<String, int> counts;
  final List<LatestClient> latestClients;
  final ChartSeries chart;

  FreelancerDashboard({
    required this.kpis,
    this.counts = const {},
    this.latestClients = const [],
    ChartSeries? chart,
  }) : chart = chart ?? ChartSeries();

  factory FreelancerDashboard.fromJson(Map<String, dynamic> j) => FreelancerDashboard(
        kpis: FreelancerKpis.fromJson((j['kpis'] as Map?)?.cast<String, dynamic>() ?? {}),
        counts: ((j['counts'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), _asInt(v) ?? 0)),
        latestClients:
            (j['latest_clients'] as List? ?? []).map((e) => LatestClient.fromJson(e)).toList(),
        chart: ChartSeries.fromJson((j['chart'] as Map?)?.cast<String, dynamic>()),
      );
}

class PaymentRow {
  final int id;
  final String amount;
  final String currency;
  final String provider;
  final String status;
  final String? reference;
  final String? createdAt;
  final String? taskTitle;
  final String? clientName;

  PaymentRow({
    required this.id,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.status,
    this.reference,
    this.createdAt,
    this.taskTitle,
    this.clientName,
  });

  bool get isPending => status == 'pending';

  factory PaymentRow.fromJson(Map<String, dynamic> j) => PaymentRow(
        id: j['id'],
        amount: j['amount']?.toString() ?? '0',
        currency: j['currency'] ?? '',
        provider: j['provider'] ?? '',
        status: j['status'] ?? '',
        reference: j['reference'],
        createdAt: j['created_at'],
        taskTitle: j['task']?['title'],
        clientName: j['client']?['name'],
      );
}

class PaymentsPage {
  final List<PaymentRow> payments;
  final double totalReceived;
  final int completedCount;
  final int pendingCount;
  final String currency;

  PaymentsPage({
    this.payments = const [],
    this.totalReceived = 0,
    this.completedCount = 0,
    this.pendingCount = 0,
    this.currency = 'USD',
  });

  factory PaymentsPage.fromJson(Map<String, dynamic> j) {
    final s = (j['stats'] as Map?) ?? {};
    return PaymentsPage(
      payments: (j['payments'] as List? ?? []).map((e) => PaymentRow.fromJson(e)).toList(),
      totalReceived: (s['total_received'] as num?)?.toDouble() ?? 0,
      completedCount: _asInt(s['completed_count']) ?? 0,
      pendingCount: _asInt(s['pending_count']) ?? 0,
      currency: s['currency'] ?? 'USD',
    );
  }
}

class Revision {
  final int id;
  final String title;
  final String? note;
  final String? deadline;
  final String? budget;
  final String? client;
  final String? previousNote;
  final String? previousLink;
  final String? previousFile;

  Revision({
    required this.id,
    required this.title,
    this.note,
    this.deadline,
    this.budget,
    this.client,
    this.previousNote,
    this.previousLink,
    this.previousFile,
  });

  factory Revision.fromJson(Map<String, dynamic> j) => Revision(
        id: j['id'],
        title: j['title'] ?? '',
        note: j['revision_note'],
        deadline: j['deadline'],
        budget: j['budget']?.toString(),
        client: j['client'],
        previousNote: j['previous_note'],
        previousLink: j['previous_link'],
        previousFile: mediaUrl(j['previous_file']),
      );
}

class ReviewRow {
  final int id;
  final int rating;
  final String body;
  final String? roleTitle;
  final bool approved;
  final String? author;
  final String? createdAt;

  ReviewRow({
    required this.id,
    required this.rating,
    required this.body,
    this.roleTitle,
    this.approved = false,
    this.author,
    this.createdAt,
  });

  factory ReviewRow.fromJson(Map<String, dynamic> j) => ReviewRow(
        id: j['id'],
        rating: _asInt(j['rating']) ?? 0,
        body: j['body'] ?? '',
        roleTitle: j['role_title'],
        approved: j['approved'] == true,
        author: j['author'],
        createdAt: j['created_at'],
      );
}

// ---- Admin console (visitors, bookings, availability, inbox, blocked) ------

class LabelCount {
  final String label;
  final int count;
  LabelCount({required this.label, required this.count});
  factory LabelCount.fromJson(Map<String, dynamic> j) =>
      LabelCount(label: j['label']?.toString() ?? '', count: _asInt(j['count']) ?? 0);
}

class VisitorStats {
  final Map<String, int> kpis;
  final List<LabelCount> topPages;
  final List<LabelCount> topReferrers;
  final List<LabelCount> devices;
  final ChartSeries chart;

  VisitorStats({
    this.kpis = const {},
    this.topPages = const [],
    this.topReferrers = const [],
    this.devices = const [],
    ChartSeries? chart,
  }) : chart = chart ?? ChartSeries();

  static List<LabelCount> _rows(dynamic v) =>
      (v as List? ?? []).map((e) => LabelCount.fromJson(e)).toList();

  factory VisitorStats.fromJson(Map<String, dynamic> j) => VisitorStats(
        kpis: ((j['kpis'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), _asInt(v) ?? 0)),
        topPages: _rows(j['top_pages']),
        topReferrers: _rows(j['top_referrers']),
        devices: _rows(j['devices']),
        chart: ChartSeries.fromJson((j['chart'] as Map?)?.cast<String, dynamic>()),
      );
}

class BookingRow {
  final int id;
  final String? startsAt;
  final int durationMin;
  final String? topic;
  final String? note;
  final String status;
  final String? client;
  final String? email;

  BookingRow({
    required this.id,
    this.startsAt,
    this.durationMin = 60,
    this.topic,
    this.note,
    required this.status,
    this.client,
    this.email,
  });

  bool get isPending => status == 'pending';

  factory BookingRow.fromJson(Map<String, dynamic> j) => BookingRow(
        id: j['id'],
        startsAt: j['starts_at'],
        durationMin: _asInt(j['duration_min']) ?? 60,
        topic: j['topic'],
        note: j['note'],
        status: j['status'] ?? '',
        client: j['client'],
        email: j['email'],
      );
}

class BookingsPage {
  final List<BookingRow> bookings;
  final int pending;
  final int confirmed;
  BookingsPage({this.bookings = const [], this.pending = 0, this.confirmed = 0});

  factory BookingsPage.fromJson(Map<String, dynamic> j) {
    final c = (j['counts'] as Map?) ?? {};
    return BookingsPage(
      bookings: (j['bookings'] as List? ?? []).map((e) => BookingRow.fromJson(e)).toList(),
      pending: _asInt(c['pending']) ?? 0,
      confirmed: _asInt(c['confirmed']) ?? 0,
    );
  }
}

class DaySchedule {
  final int day;
  final String name;
  final bool isOpen;
  final String startTime;
  final String endTime;

  DaySchedule({
    required this.day,
    required this.name,
    required this.isOpen,
    required this.startTime,
    required this.endTime,
  });

  factory DaySchedule.fromJson(Map<String, dynamic> j) => DaySchedule(
        day: _asInt(j['day']) ?? 0,
        name: j['name'] ?? '',
        isOpen: j['is_open'] == true,
        // The API may send H:i or H:i:s; the pickers only need hours+minutes.
        startTime: (j['start_time'] ?? '09:00').toString().substring(0, 5),
        endTime: (j['end_time'] ?? '17:00').toString().substring(0, 5),
      );
}

class InboxMessage {
  final int id;
  final String name;
  final String email;
  final String? subject;
  final String body;
  final bool read;
  final String? createdAt;

  InboxMessage({
    required this.id,
    required this.name,
    required this.email,
    this.subject,
    required this.body,
    this.read = false,
    this.createdAt,
  });

  factory InboxMessage.fromJson(Map<String, dynamic> j) => InboxMessage(
        id: j['id'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        subject: j['subject'],
        body: j['body'] ?? '',
        read: j['read'] == true,
        createdAt: j['created_at'],
      );
}

class BlockedEntry {
  final int id;
  final String? category;
  final String? detectedBy;
  final String? content;
  final String? reason;
  final String? author;
  final String? createdAt;

  BlockedEntry({
    required this.id,
    this.category,
    this.detectedBy,
    this.content,
    this.reason,
    this.author,
    this.createdAt,
  });

  factory BlockedEntry.fromJson(Map<String, dynamic> j) => BlockedEntry(
        id: j['id'],
        category: j['category'],
        detectedBy: j['detected_by'],
        content: j['content'],
        reason: j['reason'],
        author: j['author'],
        createdAt: j['created_at'],
      );
}

class BlockedPage {
  final List<BlockedEntry> logs;
  final Map<String, int> stats;
  BlockedPage({this.logs = const [], this.stats = const {}});

  factory BlockedPage.fromJson(Map<String, dynamic> j) => BlockedPage(
        logs: (j['logs'] as List? ?? []).map((e) => BlockedEntry.fromJson(e)).toList(),
        stats: ((j['stats'] as Map?) ?? {}).map((k, v) => MapEntry(k.toString(), _asInt(v) ?? 0)),
      );
}

/// Counts of each CV section plus the editable profile header.
class CvOverview {
  final Map<String, String> profile;
  final Map<String, int> counts;
  CvOverview({this.profile = const {}, this.counts = const {}});

  factory CvOverview.fromJson(Map<String, dynamic> j) {
    final p = ((j['profile'] as Map?) ?? {})
        .map((k, v) => MapEntry(k.toString(), (v ?? '').toString()));
    const sections = ['skills', 'services', 'projects', 'diplomas', 'experiences', 'internships'];
    return CvOverview(
      profile: p,
      counts: {for (final s in sections) s: (j[s] as List? ?? []).length},
    );
  }
}

/// Daily / weekly / monthly buckets behind the activity chart.
class ChartSeries {
  final List<LabelCount> daily;
  final List<LabelCount> weekly;
  final List<LabelCount> monthly;

  ChartSeries({this.daily = const [], this.weekly = const [], this.monthly = const []});

  List<LabelCount> of(String range) => switch (range) {
        'weekly' => weekly,
        'monthly' => monthly,
        _ => daily,
      };

  bool get isEmpty => daily.isEmpty && weekly.isEmpty && monthly.isEmpty;

  /// The API sends `{label, value}`; [LabelCount] stores it as `count`.
  static List<LabelCount> _points(dynamic v) => (v as List? ?? [])
      .map((e) => LabelCount(
            label: e['label']?.toString() ?? '',
            count: _asInt(e['value']) ?? 0,
          ))
      .toList();

  factory ChartSeries.fromJson(Map<String, dynamic>? j) => ChartSeries(
        daily: _points(j?['daily']),
        weekly: _points(j?['weekly']),
        monthly: _points(j?['monthly']),
      );
}

/// Where the freelancer receives money. The enable flags show or hide each
/// method for clients while the credentials stay saved.
class PaymentSettings {
  final String paypalEmail;
  final String paypalClientId;
  final bool paypalEnabled;
  final String d17Number;
  final bool d17Enabled;
  final String? d17QrUrl;
  final bool envPaypalClientId;
  final String paypalMode;
  final String currency;

  PaymentSettings({
    this.paypalEmail = '',
    this.paypalClientId = '',
    this.paypalEnabled = false,
    this.d17Number = '',
    this.d17Enabled = false,
    this.d17QrUrl,
    this.envPaypalClientId = false,
    this.paypalMode = 'sandbox',
    this.currency = 'USD',
  });

  factory PaymentSettings.fromJson(Map<String, dynamic> j) {
    final s = (j['settings'] as Map?) ?? {};
    return PaymentSettings(
      paypalEmail: s['paypal_email']?.toString() ?? '',
      paypalClientId: s['paypal_client_id']?.toString() ?? '',
      paypalEnabled: s['paypal_enabled'] == true,
      d17Number: s['d17_number']?.toString() ?? '',
      d17Enabled: s['d17_enabled'] == true,
      d17QrUrl: mediaUrl(s['d17_qr_url']),
      envPaypalClientId: j['env_paypal_client_id'] == true,
      paypalMode: j['paypal_mode']?.toString() ?? 'sandbox',
      currency: j['currency']?.toString() ?? 'USD',
    );
  }
}
