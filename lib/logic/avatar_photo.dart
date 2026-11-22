/// Turns a picked photo into a Crew profile photo, on the device: the
/// middle square, 256 px, JPEG, small enough for the server (64 KB).
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

const kAvatarPhotoSize = 256;
const kAvatarPhotoMaxBytes = 64 * 1024;

/// The square JPEG, or null when [input] isn't an image this can read.
///
/// Phones rotate photos with an EXIF tag; that is applied first so the
/// photo isn't sideways. The quality steps down until it fits.
Uint8List? squareAvatarJpeg(Uint8List input, {int size = kAvatarPhotoSize}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    return null;
  }
  if (decoded == null || decoded.width < 1 || decoded.height < 1) return null;
  var image = img.bakeOrientation(decoded);
  final side = image.width < image.height ? image.width : image.height;
  image = img.copyCrop(
    image,
    x: (image.width - side) ~/ 2,
    y: (image.height - side) ~/ 2,
    width: side,
    height: side,
  );
  image = img.copyResize(
    image,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );
  // JPEG has no transparency: put see-through photos on black, the stage.
  if (image.hasAlpha) {
    final flat = img.Image(width: size, height: size);
    img.fill(flat, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(flat, image);
    image = flat;
  }
  for (final quality in const [86, 76, 64, 50, 36]) {
    final jpeg = img.encodeJpg(image, quality: quality);
    if (jpeg.length <= kAvatarPhotoMaxBytes) return jpeg;
  }
  return null;
}

/// Runs [squareAvatarJpeg] on a list of bytes (for `compute`).
Uint8List? squareAvatarJpegOf(Uint8List input) => squareAvatarJpeg(input);
