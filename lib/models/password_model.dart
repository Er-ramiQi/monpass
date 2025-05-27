class PasswordModel {
  String id;
  String title;
  String username;
  String password;
  String website;
  String notes;
  DateTime createdAt;
  DateTime updatedAt;
  bool isFavorite;

  PasswordModel({
    required this.id,
    required this.title,
    required this.username,
    required this.password,
    this.website = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
  });

  // Convertir en Map pour le stockage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'username': username,
      'password': password,
      'website': website,
      'notes': notes,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'isFavorite': isFavorite,
    };
  }

  // Créer à partir d'un Map
  factory PasswordModel.fromMap(Map<String, dynamic> map) {
    return PasswordModel(
      id: map['id'],
      title: map['title'],
      username: map['username'],
      password: map['password'],
      website: map['website'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      isFavorite: map['isFavorite'] ?? false,
    );
  }

  // Copier avec de nouvelles valeurs
  PasswordModel copyWith({
    String? id,
    String? title,
    String? username,
    String? password,
    String? website,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return PasswordModel(
      id: id ?? this.id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}