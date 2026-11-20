import 'package:flutter/foundation.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';
import '../../auth/view_models/profile_view_model.dart';

class EditProfileViewModel extends ChangeNotifier {
  EditProfileViewModel({required this._repository, PhotoPicker? pickPhoto})
    : photo = ProfileViewModel(pickPhoto: pickPhoto) {
    photo.addListener(_changed);
  }
  final ProfileRepository _repository;
  final ProfileViewModel photo;
  UserProfile? profile;
  String _biography = '';
  String get biography => _biography;
  set biography(String value) {
    _biography = value;
    _changed();
  }

  bool get hasChanges =>
      profile != null &&
      (biography.trim() != profile!.biography ||
          photo.preview != null ||
          removeExisting);
  String get savingLabel => photo.preview != null
      ? 'Uploading photo…'
      : removeExisting
      ? 'Removing photo…'
      : 'Saving…';
  bool loading = false,
      saving = false,
      removeExisting = false,
      _disposed = false;
  String? error;
  Future<Uint8List> avatar(String path) => _repository.avatar(path);
  bool get busy => loading || saving || photo.readingPhoto;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    _changed();
    try {
      final loaded = await _repository.loadOwn();
      if (_disposed) return;
      profile = loaded;
      _biography = loaded.biography;
    } on ProfileFailure catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Profile could not be loaded. Please retry or skip.';
    } finally {
      loading = false;
      _changed();
    }
  }

  void removePhoto() {
    removeExisting = true;
    photo.removePhoto();
    _changed();
  }

  Future<bool> save() async {
    if (busy || _disposed || profile == null) return false;
    if (biography.runes.length > 250) {
      error = 'Keep your biography within 250 characters.';
      _changed();
      return false;
    }
    saving = true;
    error = null;
    _changed();
    var avatarSaved = false;
    try {
      if (photo.preview != null) {
        profile = await _repository.uploadAvatar(photo.preview!);
        avatarSaved = true;
        if (_disposed) return false;
        photo.removePhoto();
        removeExisting = false;
      } else if (removeExisting) {
        profile = await _repository.removeAvatar();
        avatarSaved = true;
        removeExisting = false;
      }
      if (_disposed) return false;
      profile = await _repository.saveBiography(biography.trim());
      if (_disposed) return false;
      _biography = profile!.biography;
      return true;
    } on ProfileFailure catch (e) {
      error = avatarSaved
          ? 'Your photo change was saved. ${e.message}'
          : e.message;
      return false;
    } catch (_) {
      error = avatarSaved
          ? 'Your photo change was saved. The biography could not be saved. Retry to finish.'
          : 'Changes could not be saved. Please retry.';
      return false;
    } finally {
      saving = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    photo.removeListener(_changed);
    photo.dispose();
    super.dispose();
  }
}
