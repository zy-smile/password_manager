import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:password_manager/core/constants/app_constants.dart';
import 'package:password_manager/features/wardrobe/domain/wardrobe_item.dart';
import 'package:password_manager/features/wardrobe/presentation/wardrobe_provider.dart';

class WardrobeEditScreen extends StatefulWidget {
  const WardrobeEditScreen({super.key, this.item});

  final WardrobeItem? item;

  bool get isEditing => item != null;

  @override
  State<WardrobeEditScreen> createState() => _WardrobeEditScreenState();
}

class _WardrobeEditScreenState extends State<WardrobeEditScreen> {
  static final bool _canUseCamera =
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  late final TextEditingController _nameController;
  late final TextEditingController _colorController;
  late final TextEditingController _brandController;
  late final TextEditingController _noteController;

  late String _category;
  late Set<String> _seasons;
  DateTime? _purchaseDate;

  /// 已存在于本地的图片路径（编辑时沿用）
  String _savedPhotoPath = '';

  /// 本次新选择、尚未入库的临时图片路径
  String? _pickedPhotoPath;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _colorController = TextEditingController(text: item?.color ?? '');
    _brandController = TextEditingController(text: item?.brand ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');
    _category = item?.category ?? AppConstants.wardrobeCategories.first;
    _seasons = {...?item?.seasons};
    _purchaseDate = item?.purchaseDate;
    _savedPhotoPath = item?.photoPath ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String? get _displayPhotoPath => _pickedPhotoPath ?? _savedPhotoPath;

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (!mounted || file == null) return;
      setState(() => _pickedPhotoPath = file.path);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败：$error')),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: now,
    );
    if (mounted && picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写衣服名称')),
      );
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final item = WardrobeItem(
      id: widget.item?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      category: _category,
      seasons: AppConstants.wardrobeSeasons
          .where(_seasons.contains)
          .toList(growable: false),
      color: _colorController.text.trim(),
      brand: _brandController.text.trim(),
      photoPath: _savedPhotoPath,
      note: _noteController.text.trim(),
      isFavorite: widget.item?.isFavorite ?? false,
      purchaseDate: _purchaseDate,
      createdAt: widget.item?.createdAt ?? now,
      updatedAt: now,
    );

    final wardrobe = Provider.of<WardrobeProvider>(context, listen: false);
    try {
      if (widget.isEditing) {
        await wardrobe.updateItem(item, pickedPhotoPath: _pickedPhotoPath);
      } else {
        await wardrobe.addItem(item, pickedPhotoPath: _pickedPhotoPath);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildPhotoSection() {
    const size = 140.0;
    final path = _displayPhotoPath;

    final preview = path != null && path.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(size),
            ),
          )
        : _buildPhotoPlaceholder(size);

    return Row(
      children: [
        preview,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_canUseCamera) ...[
                OutlinedButton.icon(
                  onPressed:
                      _saving ? null : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍照'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed:
                    _saving ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('从相册选择'),
              ),
              if (_displayPhotoPath != null &&
                  _displayPhotoPath!.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _pickedPhotoPath = null;
                      _savedPhotoPath = '';
                    });
                  },
                  child: const Text('移除照片'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.checkroom_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '编辑衣服' : '添加衣服')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPhotoSection(),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '名称 *',
              hintText: '例如：藏青色牛仔外套',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: '分类'),
            items: [
              for (final category in AppConstants.wardrobeCategories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 16),
          Text('季节', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final season in AppConstants.wardrobeSeasons)
                FilterChip(
                  label: Text(season),
                  selected: _seasons.contains(season),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _seasons.add(season);
                      } else {
                        _seasons.remove(season);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _colorController,
                  decoration: const InputDecoration(labelText: '颜色'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: '品牌'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('购买日期'),
            subtitle: Text(
              _purchaseDate == null
                  ? '未设置'
                  : '${_purchaseDate!.year}-${_purchaseDate!.month.toString().padLeft(2, '0')}-${_purchaseDate!.day.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.event_outlined),
            onTap: _pickDate,
          ),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '备注',
              hintText: '搭配心得、洗涤注意事项等',
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(widget.isEditing ? '保存修改' : '添加'),
          ),
        ],
      ),
    );
  }
}
