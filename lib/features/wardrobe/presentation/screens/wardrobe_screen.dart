import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:password_manager/core/constants/app_constants.dart';
import 'package:password_manager/features/wardrobe/domain/wardrobe_item.dart';
import 'package:password_manager/features/wardrobe/presentation/screens/wardrobe_edit_screen.dart';
import 'package:password_manager/features/wardrobe/presentation/wardrobe_provider.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WardrobeProvider>(context, listen: false).loadItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('衣服管理'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '列表'),
              Tab(text: '统计'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListTab(context),
            _buildStatsTab(context),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WardrobeEditScreen()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('添加衣服'),
        ),
      ),
    );
  }

  Widget _buildListTab(BuildContext context) {
    return Consumer<WardrobeProvider>(
      builder: (context, wardrobe, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '搜索名称、颜色、品牌或备注',
                ),
                onChanged: wardrobe.setSearchQuery,
              ),
            ),
            _buildFilterRow(
              label: '分类',
              options: AppConstants.wardrobeCategories,
              selected: wardrobe.selectedCategory,
              onSelected: (value) {
                wardrobe.setSelectedCategory(
                  wardrobe.selectedCategory == value ? null : value,
                );
              },
            ),
            _buildFilterRow(
              label: '季节',
              options: AppConstants.wardrobeSeasons,
              selected: wardrobe.selectedSeason,
              onSelected: (value) {
                wardrobe.setSelectedSeason(
                  wardrobe.selectedSeason == value ? null : value,
                );
              },
            ),
            Expanded(
              child: wardrobe.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : wardrobe.filteredItems.isEmpty
                      ? _buildEmptyState(wardrobe.items.isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: wardrobe.filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = wardrobe.filteredItems[index];
                            return _buildItemCard(context, wardrobe, item);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterRow({
    required String label,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelected,
  }) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(option),
                selected: selected == option,
                onSelected: (_) => onSelected(option),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    WardrobeProvider wardrobe,
    WardrobeItem item,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: _buildThumbnail(item),
        title: Text(item.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_buildSubtitle(item)),
        ),
        isThreeLine: false,
        trailing: IconButton(
          onPressed: () => wardrobe.toggleFavorite(item),
          icon: Icon(
            item.isFavorite ? Icons.star_rounded : Icons.star_outline,
            color: item.isFavorite ? const Color(0xFFF59E0B) : null,
          ),
        ),
        onTap: () => _showItemDetail(context, wardrobe, item),
      ),
    );
  }

  Widget _buildThumbnail(WardrobeItem item) {
    if (item.photoPath.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.checkroom_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(item.photoPath),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  String _buildSubtitle(WardrobeItem item) {
    final parts = <String>[
      item.category,
      if (item.seasons.isNotEmpty) item.seasons.join('/'),
      if (item.color.isNotEmpty) item.color,
      if (item.brand.isNotEmpty) item.brand,
    ];
    return parts.join(' · ');
  }

  void _showItemDetail(
    BuildContext context,
    WardrobeProvider wardrobe,
    WardrobeItem item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.photoPath.isNotEmpty) ...[
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(item.photoPath),
                          height: 220,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(context, '分类', item.category),
                  _buildDetailRow(
                    context,
                    '季节',
                    item.seasons.isEmpty ? '未标记' : item.seasons.join(' / '),
                  ),
                  if (item.color.isNotEmpty)
                    _buildDetailRow(context, '颜色', item.color),
                  if (item.brand.isNotEmpty)
                    _buildDetailRow(context, '品牌', item.brand),
                  if (item.purchaseDate != null)
                    _buildDetailRow(
                      context,
                      '购买日期',
                      '${item.purchaseDate!.year}-${item.purchaseDate!.month.toString().padLeft(2, '0')}-${item.purchaseDate!.day.toString().padLeft(2, '0')}',
                    ),
                  if (item.note.isNotEmpty)
                    _buildDetailRow(context, '备注', item.note),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WardrobeEditScreen(item: item),
                              ),
                            );
                          },
                          child: const Text('编辑'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('确认删除'),
                                content: Text(
                                  '确定删除「${item.name}」吗？照片也会一并移除。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !sheetContext.mounted) {
                              return;
                            }
                            Navigator.pop(sheetContext);
                            await wardrobe.deleteItem(item);
                          },
                          child: const Text('删除'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatsTab(BuildContext context) {
    return Consumer<WardrobeProvider>(
      builder: (context, wardrobe, _) {
        final total = wardrobe.items.length;
        final favoriteCount =
            wardrobe.items.where((item) => item.isFavorite).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatNumber('$total', '衣服总数'),
                    ),
                    Expanded(
                      child: _buildStatNumber('$favoriteCount', '收藏'),
                    ),
                    Expanded(
                      child: _buildStatNumber(
                        '${wardrobe.categoryCounts.length}',
                        '涉及分类',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildStatsCard(
              title: '按分类统计',
              counts: _orderedCounts(
                wardrobe.categoryCounts,
                AppConstants.wardrobeCategories,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatsCard(
              title: '按季节统计',
              counts: _orderedCounts(
                wardrobe.seasonCounts,
                AppConstants.wardrobeSeasons,
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, int> _orderedCounts(Map<String, int> counts, List<String> order) {
    final result = <String, int>{};
    for (final key in order) {
      result[key] = counts[key] ?? 0;
    }
    for (final entry in counts.entries) {
      result.putIfAbsent(entry.key, () => entry.value);
    }
    return result;
  }

  Widget _buildStatNumber(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildStatsCard({
    required String title,
    required Map<String, int> counts,
  }) {
    final maxCount =
        counts.values.fold(0, (max, value) => value > max ? value : max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (maxCount == 0)
              Text(
                '暂无数据，先去列表添加衣服吧',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              )
            else
              for (final entry in counts.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(entry.key),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: entry.value / maxCount,
                            minHeight: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36,
                        child: Text(
                          '${entry.value}',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool hasItems) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checkroom_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            hasItems ? '没有符合条件的衣服' : '还没有记录任何衣服',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            hasItems ? '试试调整搜索或筛选条件' : '点击下方「添加衣服」开始归纳你的衣橱',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
