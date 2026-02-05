import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;

// 1. Simple Class for Color Matching
class TileColor {
  final int r, g, b;
  TileColor(this.r, this.g, this.b);
}

class MosaicInput {
  final Uint8List targetBytes;
  final List<TileColor> tiles; 
  final List<Uint8List> tileImagesBytes;
  final int tilesPerRow;
  final double rotationAmount;
  final double quality; // interpreted as tint/blend strength or detail
  final int seed;

  MosaicInput(
      {required this.targetBytes,
      required this.tiles,
      required this.tileImagesBytes,
      this.tilesPerRow = 50,
      this.rotationAmount = 30.0,
      this.quality = 0.5,
      this.seed = 0});
}

class _TileStats {
  final img.Image image;
  final int r, g, b;
  final double variance; 

  _TileStats(this.image, this.r, this.g, this.b, this.variance);
}

class MosaicGenerator {
  static Future<Uint8List> generate(MosaicInput input) async {
    final img.Image? target = img.decodeImage(input.targetBytes);
    if (target == null) throw Exception("Invalid Target Image");

    final Random random = Random(input.seed);

    // 1. Preprocess Tiles
    List<_TileStats> tileLibrary = [];
    
    for (var bytes in input.tileImagesBytes) {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        var stats = _analyzeTile(decoded);
        tileLibrary.add(stats);
      }
    }
    
    if (tileLibrary.isEmpty) {
        // Fallback
        tileLibrary.add(_TileStats(img.Image(width: 50, height: 50), 128, 128, 128, 0));
    }

    // 2. Base Canvas
    // Use a higher quality resize for the base to ensure legible background
    img.Image background = img.copyResize(target, width: target.width ~/ 10, height: target.height ~/ 10);
    background = img.copyResize(background, width: target.width, height: target.height, interpolation: img.Interpolation.cubic);
    
    final resultImage = background;

    // 3. Configuration
    // We increase density capability for text handling
    double baseSize = target.width / input.tilesPerRow; 
    
    // Allow much smaller tiles for details (down to 1/4th of base)
    double minSize = baseSize * 0.25; 
    double maxSize = baseSize * 2.0; 
    
    // Ensure absolute minimums
    if (minSize < 2) minSize = 2;

    // Density Calculation
    // We need more tiles since minSize is smaller
    double avgTileArea = pow(baseSize * 0.8, 2).toDouble();
    int tileCount = ((target.width * target.height) / avgTileArea * 2.5).toInt();
    
    // Dynamic cap based on image size, but allow more for detail
    int maxTiles = (target.width * target.height) ~/ 100; // e.g. 1MP image -> 10k tiles
    if (tileCount > 8000) tileCount = 8000; // Hard cap for performance, increased from 3k
    if (tileCount < 1000) tileCount = 1000;

    // 4. Generate & Place Tiles
    List<_Particle> particles = [];

    for (int i = 0; i < tileCount; i++) {
        int cx = random.nextInt(target.width);
        int cy = random.nextInt(target.height);

        // Adaptive Sizing driven by Local Variance
        // Use a smaller window for variance to catch thin text strokes
        double localVar = _calculateLocalVariance(target, cx, cy, (baseSize).toInt());
         
        // Non-linear scaling: Extremely sensitive to edges
        double sizeFactor = 1.0 - sqrt((localVar / 80.0).clamp(0.0, 1.0)); 
        
        double finalSize = minSize + (maxSize - minSize) * sizeFactor;
        
        // Less random jitter on small tiles to preserve form
        if (finalSize > minSize * 2) {
             finalSize *= (0.8 + random.nextDouble() * 0.4);
        }

        particles.add(_Particle(cx, cy, finalSize));
    }

    // Sort: Largest first, smallest last
    particles.sort((a, b) => b.size.compareTo(a.size));

    // Render Loop
    for (var p in particles) {
        int size = p.size.toInt();
        if (size <= 0) continue;

        // Draw center
        int x = p.x - size ~/ 2;
        int y = p.y - size ~/ 2;
        
        int safeX = x.clamp(0, target.width - 1);
        int safeY = y.clamp(0, target.height - 1);
        int safeW = size.clamp(1, target.width - safeX);
        int safeH = size.clamp(1, target.height - safeY);

        var avgColor = _calculateAverageColor(target, safeX, safeY, safeW, safeH);
        
        // Find Best Match
        int bestIndex = _findBestWeightedMatch(avgColor, tileLibrary);
        var selectedTile = tileLibrary[bestIndex];

        // Process Tile
        img.Image drawnTile = img.copyResize(selectedTile.image, width: size, height: size);
        
        // Rotation: Only rotate larger tiles. 
        // Small tiles (detail) should probably be aligned to avoid aliasing artifacts or noise?
        // Actually random rotation helps "natural" look, but for text, too much rotation might be bad.
        // Let's reduce rotation range.
        double angle = (random.nextDouble() - 0.5) * input.rotationAmount; 
        drawnTile = img.copyRotate(drawnTile, angle: angle);

        // TINTING Logic
        // Calculate how "bad" the match is
        double colorDist = sqrt(
            pow(selectedTile.r - avgColor.r, 2) + 
            pow(selectedTile.g - avgColor.g, 2) + 
            pow(selectedTile.b - avgColor.b, 2)
        );
        
        // Dynamic Tint:
        // If match is good (dist low), low contrast.
        // If match is bad (dist high), increase tint to "force" the color.
        // Base tint 30%. Max tint 60% if terrible match.
        // Quality controls the baseline tint. higher quality = more tint (closer to target)
        // input.quality is 0.0 to 1.0.
        // Base tint ranges from 0.0 to 0.8
        double tintBase = input.quality * 0.8;
        double tintStrength = tintBase + (colorDist / 442.0 * 0.2); 
        if(tintStrength > 0.7) tintStrength = 0.7;

        _tintImage(drawnTile, avgColor.r, avgColor.g, avgColor.b, tintStrength);

        // Composite
        int drawX = p.x - (drawnTile.width ~/ 2);
        int drawY = p.y - (drawnTile.height ~/ 2);
        
        img.compositeImage(resultImage, drawnTile, dstX: drawX, dstY: drawY);
    }

    return Uint8List.fromList(img.encodePng(resultImage));
  }

  // --- Tile Analysis ---

  static _TileStats _analyzeTile(img.Image image) {
      // Resize to small for fast processing
      var small = img.copyResize(image, width: 20, height: 20);
      
      double sumR = 0, sumG = 0, sumB = 0;
      int count = 0;
      for (final p in small) {
          sumR += p.r;
          sumG += p.g;
          sumB += p.b;
          count++;
      }
      double meanR = sumR / count;
      double meanG = sumG / count;
      double meanB = sumB / count;
      
      double sumSqDiff = 0;
      for (final p in small) {
          sumSqDiff += pow(p.r - meanR, 2) + pow(p.g - meanG, 2) + pow(p.b - meanB, 2);
      }
      double variance = sqrt(sumSqDiff / count);

      return _TileStats(image, meanR.toInt(), meanG.toInt(), meanB.toInt(), variance);
  }

  // --- Matching Logic ---

  static int _findBestWeightedMatch(_RGB target, List<_TileStats> library) {
      int bestIndex = 0;
      double minScore = double.infinity;

      for (int i = 0; i < library.length; i++) {
          var tile = library[i];
          
          double colorDist = sqrt(
              pow(tile.r - target.r, 2) + 
              pow(tile.g - target.g, 2) + 
              pow(tile.b - target.b, 2)
          );
          
          // Weighting: 
          // We want to favor LOW VARIANCE (solid color) tiles for matching mostly.
          // Especially if target is Solid color (text).
          // How do we know if target is solid? We don't passed it here.
          // But general rule: Solid tiles are more versatile.
          // Penalty: 0.5 * Variance.
          double score = colorDist + (tile.variance * 0.8); 

          if (score < minScore) {
              minScore = score;
              bestIndex = i;
          }
      }
      return bestIndex;
  }

  static void _tintImage(img.Image image, int r, int g, int b, double strength) {
      // Pre-calculate
      int ir = r;
      int ig = g;
      int ib = b;
      
      for (final pixel in image) {
          // pixel.r = pixel.r + (target - pixel.r) * strength
          pixel.r = (pixel.r + (ir - pixel.r) * strength).toInt();
          pixel.g = (pixel.g + (ig - pixel.g) * strength).toInt();
          pixel.b = (pixel.b + (ib - pixel.b) * strength).toInt();
      }
  }

  // --- Other Helpers ---

  static double _calculateLocalVariance(img.Image image, int cx, int cy, int size) {
    if (size < 2) return 0;
    int half = size ~/ 2;
    
    // Use 5 points sample
    var pM = _getSafePixel(image, cx, cy);
    var pTL = _getSafePixel(image, cx - half, cy - half);
    var pTR = _getSafePixel(image, cx + half, cy - half);
    var pBL = _getSafePixel(image, cx - half, cy + half);
    var pBR = _getSafePixel(image, cx + half, cy + half);
    
    double diff = 0;
    diff += _dist(pM, pTL);
    diff += _dist(pM, pTR);
    diff += _dist(pM, pBL);
    diff += _dist(pM, pBR);
    
    return diff / 4.0; 
  }
  
  static img.Pixel _getSafePixel(img.Image image, int x, int y) {
      return image.getPixel(x.clamp(0, image.width-1), y.clamp(0, image.height-1));
  }
  
  static double _dist(img.Pixel p1, img.Pixel p2) {
      return (p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs().toDouble();
  }

  static _RGB _calculateAverageColor(img.Image image, int x, int y, int w, int h) {
    if (w <= 0 || h <= 0) return _RGB(0,0,0);
    
    // Use a strided sample for performance
    double r = 0, g = 0, b = 0;
    int c = 0;
    
    int step = 1;
    if (w > 10 || h > 10) step = 2;
    if (w > 50 || h > 50) step = 4;
    
    for (int j = y; j < y + h; j += step) {
        for (int i = x; i < x + w; i += step) {
            var p = image.getPixel(i, j);
            r += p.r;
            g += p.g;
            b += p.b;
            c++;
        }
    }
    if (c == 0) return _RGB(0,0,0);
    return _RGB((r/c).toInt(), (g/c).toInt(), (b/c).toInt());
  }
}

class _RGB {
  final int r, g, b;
  _RGB(this.r, this.g, this.b);
}

class _Particle {
    final int x, y;
    final double size;
    _Particle(this.x, this.y, this.size);
}
