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
  final String? clientName;

  Task({
    required this.id,
    required this.title,
    required this.description,
    this.category,
    this.budget,
    this.deadline,
    required this.status,
    this.isPaid = false,
    this.clientName,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        category: j['category'],
        budget: j['budget']?.toString(),
        deadline: j['deadline'],
        status: j['status'] ?? 'open',
        isPaid: j['is_paid'] == true,
        clientName: j['client']?['name'],
      );
}

class ChatPartner {
  final int id;
  final String name;
  final String role;
  ChatPartner({required this.id, required this.name, required this.role});
  factory ChatPartner.fromJson(Map<String, dynamic> j) =>
      ChatPartner(id: j['id'], name: j['name'] ?? '', role: j['role'] ?? '');
}

class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String body;
  final String? createdAt;
  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    this.createdAt,
  });
  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'],
        senderId: j['sender_id'],
        receiverId: j['receiver_id'],
        body: j['body'] ?? '',
        createdAt: j['created_at'],
      );
}
