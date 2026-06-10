import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

class ImageVectorizer {
  /// Extracts character SVG paths and their cropped image bytes from a raw image.
  static Future<ExtractionResult> extractBlobs(List<int> imageBytes) async {
    final decoded = img.decodeImage(Uint8List.fromList(imageBytes));
    if (decoded == null) throw Exception('Could not decode image');

    final img.Image image;
    if (decoded.width > 800 || decoded.height > 800) {
      int newWidth, newHeight;
      if (decoded.width > decoded.height) {
        newWidth = 800;
        newHeight = (decoded.height * 800 / decoded.width).round();
      } else {
        newHeight = 800;
        newWidth = (decoded.width * 800 / decoded.height).round();
      }
      image = img.copyResize(decoded, width: newWidth, height: newHeight);
    } else {
      image = decoded;
    }

    // Encode the resized image as high-quality JPG to send to Gemini
    final Uint8List resizedBytes = img.encodeJpg(image, quality: 85);

    // 1. Grayscale and Binarize (threshold)
    final binary = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Simple luminance calculation
        final lum = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
        // Threshold: pixels darker than 128 are ink (black)
        binary.setPixelRgba(x, y, lum < 128 ? 0 : 255, lum < 128 ? 0 : 255, lum < 128 ? 0 : 255, 255);
      }
    }

    // 2. Connected Component Labeling (simplified bounding boxes)
    // We will do a simple pass to find disconnected ink blobs.
    List<math.Rectangle<int>> bounds = [];
    final visited = List.generate(image.height, (_) => List.filled(image.width, false));

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        if (!visited[y][x] && binary.getPixel(x, y).r == 0) {
          // Found a new blob, explore it using BFS to find its bounds
          int minX = x, minY = y, maxX = x, maxY = y;
          List<math.Point<int>> queue = [math.Point(x, y)];
          visited[y][x] = true;

          while (queue.isNotEmpty) {
            final p = queue.removeLast();
            if (p.x < minX) minX = p.x;
            if (p.x > maxX) maxX = p.x;
            if (p.y < minY) minY = p.y;
            if (p.y > maxY) maxY = p.y;

            // Neighbors
            for (int dy = -1; dy <= 1; dy++) {
              for (int dx = -1; dx <= 1; dx++) {
                final nx = p.x + dx;
                final ny = p.y + dy;
                if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
                  if (!visited[ny][nx] && binary.getPixel(nx, ny).r == 0) {
                    visited[ny][nx] = true;
                    queue.add(math.Point(nx, ny));
                  }
                }
              }
            }
          }

          final width = maxX - minX + 1;
          final height = maxY - minY + 1;
          // Filter out tiny noise specks
          if (width > 5 && height > 5) {
            bounds.add(math.Rectangle<int>(minX, minY, width, height));
          }
        }
      }
    }

    // Sort bounds roughly top-to-bottom, left-to-right
    bounds.sort((a, b) {
      if ((a.top - b.top).abs() > 20) {
        return a.top.compareTo(b.top);
      }
      return a.left.compareTo(b.left);
    });

    // 3. For each bound, crop the original image and generate an SVG path
    List<ExtractedBlob> results = [];
    for (var b in bounds) {
      // Pad slightly
      final px = math.max(0, b.left - 5);
      final py = math.max(0, b.top - 5);
      final pw = math.min(image.width - px, b.width + 10);
      final ph = math.min(image.height - py, b.height + 10);

      final crop = img.copyCrop(binary, x: px, y: py, width: pw, height: ph);
      
      // Vectorize into horizontal rectangles
      StringBuffer path = StringBuffer();
      for (int y = 0; y < crop.height; y++) {
        int startX = -1;
        for (int x = 0; x < crop.width; x++) {
          if (crop.getPixel(x, y).r == 0) {
            if (startX == -1) startX = x;
          } else {
            if (startX != -1) {
              int len = x - startX;
              path.write('M $startX,$y L ${startX + len},$y L ${startX + len},${y + 1} L $startX,${y + 1} Z ');
              startX = -1;
            }
          }
        }
        if (startX != -1) {
          int len = crop.width - startX;
          path.write('M $startX,$y L ${startX + len},$y L ${startX + len},${y + 1} L $startX,${y + 1} Z ');
        }
      }

      // We will wrap the SVG path in an SVG string that handles the viewBox.
      final svgString = '<svg viewBox="0 0 ${crop.width} ${crop.height}" xmlns="http://www.w3.org/2000/svg"><path d="$path" fill="currentColor"/></svg>';

      final originalCrop = img.copyCrop(image, x: px, y: py, width: pw, height: ph);
      results.add(ExtractedBlob(
        bounds: b,
        svgContent: svgString,
        imageBytes: img.encodePng(originalCrop),
      ));
    }

    return ExtractionResult(
      blobs: results,
      imageWidth: image.width,
      imageHeight: image.height,
      resizedImageBytes: resizedBytes,
    );
  }
}

class ExtractedBlob {
  final math.Rectangle<int> bounds;
  final String svgContent;
  final List<int> imageBytes;

  ExtractedBlob({required this.bounds, required this.svgContent, required this.imageBytes});
}

class ExtractionResult {
  final List<ExtractedBlob> blobs;
  final int imageWidth;
  final int imageHeight;
  final List<int> resizedImageBytes;

  ExtractionResult({
    required this.blobs,
    required this.imageWidth,
    required this.imageHeight,
    required this.resizedImageBytes,
  });
}
