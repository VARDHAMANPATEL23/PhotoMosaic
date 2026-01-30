import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessorResult {
  final Uint8List compressedBytes;
  final int r;
  final int g;
  final int b;

  ImageProcessorResult(this.compressedBytes, this.r, this.g, this.b);
}

class ImageProcessor {
  // 1. Process the image: Resize to 100px (thumbnail) to save space & Calc Color
  static Future<ImageProcessorResult> processImage(Uint8List rawBytes) async {
    // Decode the image
    final cmd = img.Command()
      ..decodeImage(rawBytes)
      ..copyResize(width: 100);

    await cmd.executeThread();
    img.Image? resized = cmd.outputImage;

    if (resized == null) throw Exception("Could not process image");

    // Encode back to JPG for storage
    Uint8List finalBytes = img.encodeJpg(resized, quality: 70);

    // Calculate Average Color
    // We resize to 1x1 pixel to get the mathematical average!
    img.Image singlePixel = img.copyResize(resized, width: 1, height: 1);

    // In v4, getPixel returns a Pixel object, not an int.
    // We access r, g, b directly from it.
    final pixel = singlePixel.getPixel(0, 0);

    return ImageProcessorResult(
      finalBytes,
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    );
  }
}
