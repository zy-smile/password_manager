import 'package:flutter/foundation.dart';

import 'package:password_manager/core/database/app_database.dart';
import 'package:password_manager/features/wardrobe/data/models/wardrobe_item_model.dart';
import 'package:password_manager/features/wardrobe/data/wardrobe_dao.dart';
import 'package:password_manager/features/wardrobe/data/wardrobe_photo_store.dart';
import 'package:password_manager/features/wardrobe/domain/wardrobe_item.dart';

class WardrobeProvider extends ChangeNotifier {
  WardrobeProvider()
      : _dao = WardrobeDao(AppDatabase()),
        _photoStore = WardrobePhotoStore();

  final WardrobeDao _dao;
  final WardrobePhotoStore _photoStore;

  List<WardrobeItem> _items = [];
  String? _searchQuery;
  String? _selectedCategory;
  String? _selectedSeason;
  bool _isLoading = false;

  List<WardrobeItem> get items => _items;
  String? get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSeason => _selectedSeason;
  bool get isLoading => _isLoading;

  List<WardrobeItem> get filteredItems {
    var result = _items;

    if (_selectedCategory != null) {
      result =
          result.where((item) => item.category == _selectedCategory).toList();
    }
    if (_selectedSeason != null) {
      result = result
          .where((item) => item.seasons.contains(_selectedSeason))
          .toList();
    }
    final query = _searchQuery?.trim().toLowerCase();
    if (query != null && query.isNotEmpty) {
      result = result.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.brand.toLowerCase().contains(query) ||
            item.color.toLowerCase().contains(query) ||
            item.note.toLowerCase().contains(query);
      }).toList();
    }
    return result;
  }

  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final item in _items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get seasonCounts {
    final counts = <String, int>{};
    for (final item in _items) {
      for (final season in item.seasons) {
        counts[season] = (counts[season] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    try {
      final maps = await _dao.getAllItems();
      _items =
          maps.map((map) => WardrobeItemModel.fromMap(map).toEntity()).toList();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addItem(WardrobeItem item, {String? pickedPhotoPath}) async {
    var storedItem = item;
    if (pickedPhotoPath != null && pickedPhotoPath.isNotEmpty) {
      final savedPath = await _photoStore.saveImage(pickedPhotoPath);
      storedItem = item.copyWith(photoPath: savedPath);
    }
    try {
      await _dao.insertItem(WardrobeItemModel.fromEntity(storedItem).toMap());
    } catch (_) {
      if (storedItem.photoPath != item.photoPath) {
        await _photoStore.deleteImage(storedItem.photoPath);
      }
      rethrow;
    }
    await loadItems();
  }

  Future<void> updateItem(WardrobeItem item, {String? pickedPhotoPath}) async {
    var storedItem = item;
    if (pickedPhotoPath != null && pickedPhotoPath.isNotEmpty) {
      final savedPath = await _photoStore.saveImage(pickedPhotoPath);
      storedItem = item.copyWith(photoPath: savedPath);
    }
    try {
      await _dao.updateItem(WardrobeItemModel.fromEntity(storedItem).toMap());
    } catch (_) {
      if (storedItem.photoPath != item.photoPath) {
        await _photoStore.deleteImage(storedItem.photoPath);
      }
      rethrow;
    }
    if (storedItem.photoPath != item.photoPath && item.photoPath.isNotEmpty) {
      await _photoStore.deleteImage(item.photoPath);
    }
    await loadItems();
  }

  Future<void> deleteItem(WardrobeItem item) async {
    await _dao.deleteItem(item.id);
    await _photoStore.deleteImage(item.photoPath);
    await loadItems();
  }

  Future<void> toggleFavorite(WardrobeItem item) async {
    final updated = item.copyWith(
      isFavorite: !item.isFavorite,
      updatedAt: DateTime.now(),
    );
    await _dao.updateItem(WardrobeItemModel.fromEntity(updated).toMap());
    await loadItems();
  }

  Future<void> clearAllItems() async {
    await _dao.clearAllItems();
    await _photoStore.deleteAllImages();
    await loadItems();
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSelectedSeason(String? season) {
    _selectedSeason = season;
    notifyListeners();
  }
}
