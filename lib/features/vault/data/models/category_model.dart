class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    this.icon = 'folder',
    this.sortOrder = 0,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      name: map['name'],
      icon: map['icon'] ?? 'folder',
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
    };
  }
}
