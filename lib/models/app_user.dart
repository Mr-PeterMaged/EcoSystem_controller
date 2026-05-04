import 'dart:convert';

class AppUser {
  final String username;
  final String fullName;
  final String passwordHash;
  final String role;
  final DateTime createdAt;

  const AppUser({
    required this.username,
    required this.fullName,
    required this.passwordHash,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  String get displayName => fullName.isNotEmpty ? fullName : username;

  Map<String, dynamic> toJson() => {
    'username': username,
    'fullName': fullName,
    'passwordHash': passwordHash,
    'role': role,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static List<AppUser> listFromJson(String source) {
    if (source.trim().isEmpty) return [];
    final decoded = jsonDecode(source);
    final list = decoded is Map<String, dynamic> ? decoded['users'] : decoded;
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .where((user) => user.username.isNotEmpty)
        .toList();
  }

  static String listToJson(List<AppUser> users) {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert({'users': users.map((user) => user.toJson()).toList()});
  }
}
