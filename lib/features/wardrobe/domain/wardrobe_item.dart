class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    this.category = '上衣',
    this.seasons = const [],
    this.color = '',
    this.brand = '',
    this.photoPath = '',
    this.note = '',
    this.isFavorite = false,
    this.purchaseDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final List<String> seasons;
  final String color;
  final String brand;
  final String photoPath;
  final String note;
  final bool isFavorite;
  final DateTime? purchaseDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  WardrobeItem copyWith({
    String? name,
    String? category,
    List<String>? seasons,
    String? color,
    String? brand,
    String? photoPath,
    String? note,
    bool? isFavorite,
    DateTime? purchaseDate,
    DateTime? updatedAt,
  }) {
    return WardrobeItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      seasons: seasons ?? this.seasons,
      color: color ?? this.color,
      brand: brand ?? this.brand,
      photoPath: photoPath ?? this.photoPath,
      note: note ?? this.note,
      isFavorite: isFavorite ?? this.isFavorite,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
