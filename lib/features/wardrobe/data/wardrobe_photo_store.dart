import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class WardrobePhotoStore {
  Future<String> _directoryPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'wardrobe_photos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<String> saveImage(String sourcePath) async {
    final dirPath = await _directoryPath();
    final ext = p.extension(sourcePath);
    final fileName =
        'wardrobe_${DateTime.now().microsecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}';
    final targetPath = p.join(dirPath, fileName);
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  Future<void> deleteImage(String path) async {
    if (path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteAllImages() async {
    final dirPath = await _directoryPath();
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
