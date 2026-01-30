import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  static const String _boxName = 'image_storage';

  Future<void> init() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(dir.path);
    } else {
      await Hive.initFlutter();
    }
    await Hive.openBox(_boxName);
  }

  Future<String> saveImage(String filename, Uint8List bytes) async {
    if (kIsWeb) {
      var box = Hive.box(_boxName);
      await box.put(filename, bytes);
      return filename;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, 'Photomosaic', 'images'));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final file = File(p.join(folder.path, filename));
      await file.writeAsBytes(bytes);
      return file.path;
    }
  }

  Future<Uint8List?> getImage(String ref) async {
    if (kIsWeb) {
      var box = Hive.box(_boxName);
      final data = box.get(ref);
      return data is Uint8List ? data : null;
    } else {
      final file = File(ref);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    }
  }

  Future<void> clearAll() async {
    var box = Hive.box(_boxName);
    await box.clear();
  }
}
