import 'package:password_manager/features/wardrobe/domain/wardrobe_item.dart';

class WardrobeItemModel {
  const WardrobeItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.seasons,
    required this.color,
    required this.brand,
    required this.photoPath,
    required this.note,
    required this.isFavorite,
    required this.purchaseDate,
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
  final int? purchaseDate;
  final int createdAt;
  final int updatedAt;

  factory WardrobeItemModel.fromMap(Map<String, dynamic> map) {
    return WardrobeItemModel(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? '上衣',
      seasons: (map['seasons'] as String? ?? '')
          .split(';')
          .where((season) => season.isNotEmpty)
          .toList(),
      color: map['color'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      photoPath: map['photo_path'] as String? ?? '',
      note: map['note'] as String? ?? '',
      isFavorite: map['is_favorite'] == 1,
      purchaseDate: map['purchase_date'] as int?,
      createdAt: map['created_at'] as int? ?? 0,
      updatedAt: map['updated_at'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'seasons': seasons.join(';'),
      'color': color,
      'brand': brand,
      'photo_path': photoPath,
      'note': note,
      'is_favorite': isFavorite ? 1 : 0,
      'purchase_date': purchaseDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory WardrobeItemModel.fromEntity(WardrobeItem item) {
    return WardrobeItemModel(
      id: item.id,
      name: item.name,
      category: item.category,
      seasons: item.seasons,
      color: item.color,
      brand: item.brand,
      photoPath: item.photoPath,
      note: item.note,
      isFavorite: item.isFavorite,
      purchaseDate: item.purchaseDate?.millisecondsSinceEpoch,
      createdAt: item.createdAt.millisecondsSinceEpoch,
      updatedAt: item.updatedAt.millisecondsSinceEpoch,
    );
  }

  WardrobeItem toEntity() {
    return WardrobeItem(
      id: id,
      name: name,
      category: category,
      seasons: seasons,
      color: color,
      brand: brand,
      photoPath: photoPath,
      note: note,
      isFavorite: isFavorite,
      purchaseDate: purchaseDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(purchaseDate!),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }
}
