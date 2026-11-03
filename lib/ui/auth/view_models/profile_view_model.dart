import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

typedef PhotoPicker = Future<XFile?> Function();

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({PhotoPicker? pickPhoto}) : _pickPhoto = pickPhoto ?? _pick;
  final PhotoPicker _pickPhoto;
  XFile? photo;
  Uint8List? preview;
  String? photoError;
  bool readingPhoto = false;
  bool _disposed = false;
  int _selection = 0;
  static Future<XFile?> _pick() => ImagePicker().pickImage(
    source: ImageSource.gallery,
    requestFullMetadata: false,
  );

  Future<void> selectPhoto() async {
    if (readingPhoto || _disposed) return;
    readingPhoto = true;
    photoError = null;
    notifyListeners();
    final selection = ++_selection;
    try {
      final file = await _pickPhoto();
      if (_disposed || selection != _selection || file == null) return;
      if (await file.length() > 1000000) {
        throw const FormatException(
          'Choose a JPG, PNG or WebP smaller than 1 MB.',
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
      if (bytes.length > 1000000 || !(png || jpg || webp)) {
        throw const FormatException(
          'Choose a JPG, PNG or WebP smaller than 1 MB.',
        );
      }
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (_disposed || selection != _selection) return;
      photo = file;
      preview = bytes;
    } on FormatException catch (error) {
      if (!_disposed) photoError = error.message;
    } catch (_) {
      if (!_disposed) {
        photoError = 'This image could not be opened. Please choose another.';
      }
    } finally {
      if (!_disposed && selection == _selection) {
        readingPhoto = false;
        notifyListeners();
      }
    }
  }

  void removePhoto() {
    if (readingPhoto) return;
    photo = null;
    preview = null;
    photoError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _selection++;
    preview = null;
    photo = null;
    super.dispose();
  }
}
