import '../../../data/services/profile_photo_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 82,
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
      final bytes = await const ProfilePhotoService().prepare(file);
      if (_disposed || selection != _selection) return;
      photo = file;
      preview = bytes;
    } on PlatformException catch (error) {
      if (!_disposed) {
        photoError =
            error.code.contains('denied') || error.code.contains('restricted')
            ? 'Photo access is unavailable. Allow photo access in Android settings and try again.'
            : 'This photo could not be prepared. Please choose another.';
      }
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
