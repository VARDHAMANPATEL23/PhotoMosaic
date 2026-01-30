import 'dart:io';
// Essential for Uint8List
import 'package:flutter/foundation.dart'; // for compute & kIsWeb
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/tile_image.dart';
import '../core/storage/storage_service.dart';
import '../core/image_processor.dart';
import '../core/mosaic_generator.dart';

class GalleryProvider extends ChangeNotifier {
  // --- State Variables ---
  List<TileImage> _tiles = [];
  bool _isProcessing = false;

  // Progress Bar Variable (0.0 to 1.0)
  double _progress = 0.0;

  final StorageService _storage = StorageService();

  // --- Getters ---
  List<TileImage> get tiles => _tiles;
  bool get isProcessing => _isProcessing;
  int get count => _tiles.length;
  double get progress => _progress;

  Uint8List? _generatedMosaic;
  Uint8List? get generatedMosaic => _generatedMosaic;

  // --- Initialization ---
  Future<void> init() async {
    await _storage.init();
    var box = await Hive.openBox<TileImage>('tile_box');
    _tiles = box.values.toList();
    notifyListeners();
  }

  Future<Uint8List?> getImageFromStorage(String path) {
    return _storage.getImage(path);
  }

  // --- Upload & Process Images (With Progress Bar) ---
  Future<void> pickAndProcessImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: kIsWeb,
    );

    if (result != null) {
      _isProcessing = true;
      _progress = 0.0; // Reset progress
      notifyListeners();

      var box = await Hive.openBox<TileImage>('tile_box');
      int total = result.files.length;
      int current = 0;

      for (var file in result.files) {
        Uint8List? fileBytes;

        // Get file bytes based on platform
        if (kIsWeb) {
          fileBytes = file.bytes;
        } else if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        }

        if (fileBytes != null) {
          try {
            // 1. Resize & Calculate Color
            var processed = await ImageProcessor.processImage(fileBytes);

            // 2. Save to Storage (Disk or IDB)
            String savedPath =
                await _storage.saveImage(file.name, processed.compressedBytes);

            // 3. Save Metadata to Hive
            final tile = TileImage(
              id: file.name,
              path: savedPath,
              r: processed.r,
              g: processed.g,
              b: processed.b,
            );

            await box.add(tile);
            _tiles.add(tile);
          } catch (e) {
            print("Error processing ${file.name}: $e");
          }
        }

        // Update Progress Bar
        current++;
        _progress = current / total;
        notifyListeners();
      }

      _isProcessing = false;
      _progress = 0.0;
      notifyListeners();
    }
  }

  // --- Clear Everything ---
  Future<void> clearGallery() async {
    var box = await Hive.openBox<TileImage>('tile_box');
    await box.clear();
    await _storage.clearAll();
    _tiles.clear();
    _generatedMosaic = null;
    notifyListeners();
  }

  // --- Generate Mosaic (Phase 4 Logic) ---
  Future<void> generateMosaic(Uint8List targetImageBytes) async {
    if (_tiles.isEmpty) return;

    _isProcessing = true;
    notifyListeners();

    try {
      // 1. Prepare Images (Load from Disk)
      List<Uint8List> tileBytesList = [];
      for (var tile in _tiles) {
        Uint8List? bytes = await _storage.getImage(tile.path);
        if (bytes != null) {
          tileBytesList.add(bytes);
        } else {
          tileBytesList.add(Uint8List(0));
        }
      }

      // 2. Prepare Data (Convert HiveObject to Plain Data)
      // This is the FIX: We create a new list of "dumb" objects that don't touch the database
      final simpleTiles = _tiles.map((t) => TileColor(t.r, t.g, t.b)).toList();

      // 3. Run Generator
      final result = await compute(
          MosaicGenerator.generate,
          MosaicInput(
            targetBytes: targetImageBytes,
            tiles: simpleTiles, // Sending the safe list
            tileImagesBytes: tileBytesList,
          ));

      _generatedMosaic = result;
    } catch (e) {
      print("Generation Error: $e");
      // Rethrow so the UI knows it failed
      rethrow;
    }

    _isProcessing = false;
    notifyListeners();
  }
}
