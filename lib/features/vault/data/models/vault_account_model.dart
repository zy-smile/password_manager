class VaultAccountModel {
  const VaultAccountModel({
    required this.id,
    required this.title,
    required this.website,
    this.username,
    this.usernameEncrypted,
    required this.passwordEncrypted,
    this.note,
    this.noteEncrypted,
    this.category = '其他',
    this.isFavorite = false,
    this.encryptionVersion = 2,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String website;
  final String? username;
  final String? usernameEncrypted;
  final String passwordEncrypted;
  final String? note;
  final String? noteEncrypted;
  final String category;
  final bool isFavorite;
  final int encryptionVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory VaultAccountModel.fromMap(Map<String, dynamic> map) {
    return VaultAccountModel(
      id: map['id'] as String,
      title: map['platform_name'] as String? ?? '',
      website: map['website'] as String? ?? '',
      username: map['username'] as String?,
      usernameEncrypted: map['username_encrypted'] as String?,
      passwordEncrypted: map['password_encrypted'] as String,
      note: map['note'] as String?,
      noteEncrypted: map['note_encrypted'] as String?,
      category: map['category'] as String? ?? '其他',
      isFavorite: map['is_favorite'] == 1,
      encryptionVersion: map['encryption_version'] as int? ?? 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platform_name': title,
      'website': website,
      'username': username ?? '',
      'username_encrypted': usernameEncrypted,
      'password_encrypted': passwordEncrypted,
      'note': note ?? '',
      'note_encrypted': noteEncrypted,
      'category': category,
      'is_favorite': isFavorite ? 1 : 0,
      'encryption_version': encryptionVersion,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}
