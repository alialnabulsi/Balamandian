import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';

class CommunityDraftImage {
  CommunityDraftImage.local(this.bytes, this.type);
  CommunityDraftImage.remote(this.uploaded) : bytes = null, type = null;
  final Uint8List? bytes;
  final String? type;
  CommunityImage? uploaded;
}

class CommunityComposerModel extends ChangeNotifier {
  CommunityComposerModel(
    this.repository, {
    required this.story,
    this.previous,
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker(),
       id = previous?.id ?? CommunityRepository.newId(),
       caption = previous?.caption ?? '',
       images = [
         for (final image in previous?.media ?? const <CommunityImage>[])
           CommunityDraftImage.remote(image),
       ];
  final CommunityRepository repository;
  final CommunityEntry? previous;
  final ImagePicker _picker;
  final String id;
  final bool story;
  final List<CommunityDraftImage> images;
  String caption;
  Object? error;
  bool busy = false, picking = false, _disposed = false;
  double progress = 0;
  int get limit => story ? 1 : 6;
  bool get dirty =>
      caption != (previous?.caption ?? '') ||
      !listEquals(
        images.map((v) => v.uploaded?.id).toList(),
        previous?.media.map((v) => v.id).toList() ?? [],
      );

  Future<void> pick({bool camera = false}) async {
    if (picking || busy || images.length >= limit) return;
    picking = true;
    error = null;
    _publish();
    try {
      final remaining = limit - images.length;
      final List<XFile> files;
      if (camera || remaining == 1) {
        final entry = await _picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 85,
          requestFullMetadata: false,
        );
        files = [?entry];
      } else {
        files = await _picker.pickMultiImage(
          limit: remaining,
          maxWidth: 1800,
          maxHeight: 1800,
          imageQuality: 85,
          requestFullMetadata: false,
        );
      }
      for (final file in files.take(remaining)) {
        if (_disposed) break;
        if (await file.length() > 8000000) {
          throw const CommunityFailure('Choose images below 8 MB each.');
        }
        final bytes = await file.readAsBytes();
        if (_disposed) break;
        final type = imageType(bytes);
        if (type == null) {
          throw const CommunityFailure('Choose a JPEG, PNG or WebP image.');
        }
        images.add(CommunityDraftImage.local(bytes, type));
      }
    } catch (e) {
      error = e is CommunityFailure
          ? e
          : const CommunityFailure('Could not open the camera or gallery.');
    } finally {
      picking = false;
      _publish();
    }
  }

  static String? imageType(Uint8List bytes) {
    if (bytes.length < 12) return null;
    if (bytes[0] == 255 && bytes[1] == 216 && bytes[2] == 255) {
      return 'image/jpeg';
    }
    if (bytes[0] == 137 && String.fromCharCodes(bytes.sublist(1, 4)) == 'PNG') {
      return 'image/png';
    }
    if (String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  void remove(int index) {
    if (busy) return;
    final image = images.removeAt(index);
    if (image.bytes != null && image.uploaded != null) {
      unawaited(_discard(image.uploaded!.id));
    }
    _publish();
  }

  void move(int index, int delta) {
    if (busy || index + delta < 0 || index + delta >= images.length) return;
    images.insert(index + delta, images.removeAt(index));
    _publish();
  }

  void edit(String text) {
    caption = text;
    _publish();
  }

  Future<bool> save() async {
    if (busy || picking || images.isEmpty) return false;
    busy = true;
    error = null;
    progress = 0;
    _publish();
    try {
      for (var index = 0; index < images.length; index++) {
        final image = images[index];
        image.uploaded ??= await repository.upload(image.bytes!, image.type!, (
          fraction,
        ) {
          progress = (index + fraction) / (images.length + 1);
          _publish();
        });
        if (_disposed) return false;
      }
      await repository.mutate(
        'entries/$id',
        method: previous == null ? 'PUT' : 'PATCH',
        data: {
          'kind': story ? 'story' : 'post',
          'caption': caption.trim(),
          'media': [for (final image in images) image.uploaded!.id],
        },
      );
      repository.invalidate();
      return true;
    } catch (e) {
      error = e;
      return false;
    } finally {
      busy = false;
      _publish();
    }
  }

  Future<void> discard() async {
    await Future.wait([
      for (final image in images)
        if (image.bytes != null && image.uploaded != null)
          _discard(image.uploaded!.id),
    ]);
  }

  Future<void> _discard(String id) async {
    try {
      await repository.mutate('media/$id', method: 'DELETE');
    } catch (_) {
      /* Server expires abandoned uploads. */
    }
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
