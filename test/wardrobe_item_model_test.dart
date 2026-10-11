import 'package:flutter_test/flutter_test.dart';

import 'package:password_manager/features/wardrobe/data/models/wardrobe_item_model.dart';
import 'package:password_manager/features/wardrobe/domain/wardrobe_item.dart';

void main() {
  group('WardrobeItemModel', () {
    final item = WardrobeItem(
      id: '123',
      name: '藏青色牛仔外套',
      category: '外套',
      seasons: const ['春', '秋'],
      color: '藏青',
      brand: 'Levis',
      photoPath: '/tmp/x.jpg',
      note: '百搭',
      isFavorite: true,
      purchaseDate: DateTime(2025, 6, 1),
      createdAt: DateTime(2025, 6, 2, 10),
      updatedAt: DateTime(2025, 6, 3, 12),
    );

    test('entity -> map -> entity round trip keeps all fields', () {
      final map = WardrobeItemModel.fromEntity(item).toMap();
      final restored = WardrobeItemModel.fromMap(map).toEntity();

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.category, item.category);
      expect(restored.seasons, item.seasons);
      expect(restored.color, item.color);
      expect(restored.brand, item.brand);
      expect(restored.photoPath, item.photoPath);
      expect(restored.note, item.note);
      expect(restored.isFavorite, item.isFavorite);
      expect(restored.purchaseDate, item.purchaseDate);
      expect(restored.createdAt, item.createdAt);
      expect(restored.updatedAt, item.updatedAt);
    });

    test('seasons without markers restore to empty list', () {
      final map = WardrobeItemModel.fromEntity(item).toMap()..['seasons'] = '';
      final restored = WardrobeItemModel.fromMap(map).toEntity();
      expect(restored.seasons, isEmpty);
    });

    test('missing optional fields fall back to defaults', () {
      final restored = WardrobeItemModel.fromMap(const {
        'id': '1',
        'name': 'T恤',
      }).toEntity();

      expect(restored.category, '上衣');
      expect(restored.seasons, isEmpty);
      expect(restored.isFavorite, isFalse);
      expect(restored.purchaseDate, isNull);
    });
  });
}
