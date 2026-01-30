import 'package:hive/hive.dart';

part 'tile_image.g.dart'; // Hive generator file (we will generate this later)

@HiveType(typeId: 0)
class TileImage extends HiveObject {
  @HiveField(0)
  final String id; // Unique ID (usually filename)

  @HiveField(1)
  final String
      path; // Where is it stored? (Hive key for Web, File path for Linux)

  @HiveField(2)
  final int r;

  @HiveField(3)
  final int g;

  @HiveField(4)
  final int b;

  TileImage({
    required this.id,
    required this.path,
    required this.r,
    required this.g,
    required this.b,
  });
}
