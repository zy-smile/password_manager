class VaultAccount {
  const VaultAccount({
    required this.id,
    required this.title,
    required this.website,
    required this.username,
    required this.password,
    this.note = '',
    this.category = '其他',
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String website;
  final String username;
  final String password;
  final String note;
  final String category;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory VaultAccount.fromBackupMap(Map<String, dynamic> map) {
    return VaultAccount(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      website: map['website'] as String? ?? '',
      username: map['username'] as String? ?? '',
      password: map['password'] as String? ?? '',
      note: map['note'] as String? ?? '',
      category: map['category'] as String? ?? '其他',
      isFavorite: map['favorite'] as bool? ?? false,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toBackupMap() {
    return {
      'id': id,
      'title': title,
      'website': website,
      'username': username,
      'password': password,
      'note': note,
      'category': category,
      'favorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  VaultAccount copyWith({
    String? id,
    String? title,
    String? website,
    String? username,
    String? password,
    String? note,
    String? category,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VaultAccount(
      id: id ?? this.id,
      title: title ?? this.title,
      website: website ?? this.website,
      username: username ?? this.username,
      password: password ?? this.password,
      note: note ?? this.note,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
