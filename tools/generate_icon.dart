// Generates assets/icon.png — a 1024x1024 master launcher icon used by
// flutter_launcher_icons. Run via:
//   dart run tools/generate_icon.dart
//
// Design: solid AppColors.primary green background + chunky white check mark.
// Replace with a designer-made PNG when one's available; this is a placeholder
// that gets the launcher off the default Flutter icon.

import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  // Background: AppColors.primary (0xFF58CC02 = 88, 204, 2)
  img.fill(image, color: img.ColorRgb8(88, 204, 2));

  // Check mark: two thick white strokes meeting at the bottom-middle.
  // Coordinates tuned to feel centered and read cleanly at small sizes.
  const stroke = 90;
  final white = img.ColorRgb8(255, 255, 255);

  // Short stroke: bottom-left → mid-bottom
  // (drawLine's antialias mode renders as stripes — known image-package
  // quirk — so we keep it off and let the launcher's downscale soften edges.)
  img.drawLine(
    image,
    x1: 280, y1: 540,
    x2: 470, y2: 720,
    color: white,
    thickness: stroke,
  );

  // Long stroke: mid-bottom → upper-right
  img.drawLine(
    image,
    x1: 470, y1: 720,
    x2: 800, y2: 320,
    color: white,
    thickness: stroke,
  );

  final pngBytes = img.encodePng(image);
  final outPath = 'assets/icon.png';
  File(outPath).writeAsBytesSync(pngBytes);
  print('Wrote $outPath (${pngBytes.length} bytes)');
}
