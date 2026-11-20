import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

/// Bounded avatar preparation after the platform picker's EXIF-preserving
/// resize. Backend validation remains authoritative.
class ProfilePhotoService {
  const ProfilePhotoService();
  Future<Uint8List> prepare(XFile file) async {
    if (await file.length() > 20000000) {
      throw const FormatException(
        'This image is too large to prepare. Choose another photo.',
      );
    }
    final bytes = await file.readAsBytes();
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final webp =
        bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!(png || jpg || webp)) {
      throw const FormatException('Choose a JPG, PNG or WebP photo.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final width = descriptor.width, height = descriptor.height;
        if (width > 16000 || height > 16000) {
          throw const FormatException(
            'This image has unusually large dimensions. Choose another photo.',
          );
        }
        final resize = bytes.length > 1000000 || width > 4096 || height > 4096;
        final factor = math.min(
          1.0,
          (resize ? 768 : 256) / math.max(width, height),
        );
        final codec = await descriptor.instantiateCodec(
          targetWidth: (width * factor).round().clamp(1, 768),
        );
        try {
          if (codec.frameCount != 1) {
            throw const FormatException(
              'Choose a still photo instead of an animated image.',
            );
          }
          final frame = await codec.getNextFrame();
          try {
            if (!resize) return bytes;
            final encoded = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (encoded != null && encoded.lengthInBytes <= 1000000) {
              return encoded.buffer.asUint8List();
            }
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
        // A noisy PNG can remain >1 MB. 384px bounds decoded memory and yields
        // a comfortably sized lossless fallback without an extra dependency.
        final small = await descriptor.instantiateCodec(
          targetWidth: (width * (384 / (width > height ? width : height)))
              .round()
              .clamp(1, 384),
        );
        try {
          final frame = await small.getNextFrame();
          try {
            final encoded = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (encoded == null || encoded.lengthInBytes > 1000000) {
              throw const FormatException(
                'This photo could not be resized. Choose another.',
              );
            }
            return encoded.buffer.asUint8List();
          } finally {
            frame.image.dispose();
          }
        } finally {
          small.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }
}
