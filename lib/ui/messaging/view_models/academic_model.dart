import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../data/repositories/messaging_repository.dart';
import '../../../domain/models/academic.dart';
import '../../../domain/models/community.dart';

class AcademicListModel<T> extends ChangeNotifier {
  AcademicListModel(this.fetch);

  final Future<CommunityPage<T>> Function(String? cursor, String query) fetch;
  List<T> items = [];
  Object? error;
  String? next;
  String query = '';
  Timer? _debounce;
  bool loading = true, loadingMore = false, _disposed = false;
  int _request = 0;

  void search(String value) {
    query = value.trim();
    _debounce?.cancel();
    _request++;
    _debounce = Timer(const Duration(milliseconds: 240), load);
  }

  Future<void> load({bool more = false}) async {
    if (more && (loading || loadingMore || next == null)) return;
    final request = ++_request;
    loading = !more;
    loadingMore = more;
    error = null;
    notifyListeners();
    try {
      final result = await fetch(more ? next : null, query);
      if (_disposed || request != _request) return;
      items = [if (more) ...items, ...result.items];
      next = result.next;
    } catch (e) {
      if (!_disposed && request == _request) error = e;
    } finally {
      if (!_disposed && request == _request) {
        loading = loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}

class AcademicModel {
  AcademicModel(this.repository);
  final MessagingRepository repository;

  Future<bool> canCreate() async =>
      (await repository.object('academic/capabilities'))['canCreateRoom'] ==
      true;

  AcademicListModel<AcademicSpace> spaces(String kind) => AcademicListModel(
    (cursor, query) async => CommunityPage.fromJson(
      await repository.object(
        'academic/spaces',
        query: {'kind': kind, 'q': query, 'after': ?cursor},
      ),
      AcademicSpace.new,
    ),
  );

  AcademicListModel<AcademicCourse> courses() => AcademicListModel(
    (cursor, query) async => CommunityPage.fromJson(
      await repository.object(
        'academic/courses',
        query: {'q': query, 'after': ?cursor},
      ),
      AcademicCourse.new,
    ),
  );

  AcademicListModel<AcademicItem> items(
    String thread,
    String kind, {
    String? question,
  }) => AcademicListModel(
    (cursor, _) async => CommunityPage.fromJson(
      await repository.object(
        'academic/rooms/$thread/items',
        query: {'kind': kind, 'after': ?cursor, 'question': ?question},
      ),
      AcademicItem.new,
    ),
  );

  Future<void> join(String id) async =>
      repository.object('academic/spaces/$id/join', method: 'PUT');

  Future<void> create(
    String id,
    AcademicCourse course,
    String title,
    String description,
    String? image,
  ) async => repository.object(
    'academic/rooms/$id',
    method: 'PUT',
    data: {
      'course': course.code,
      'title': title,
      'description': description,
      'image': image,
    },
  );

  Future<void> publish(
    String thread,
    String id,
    String kind,
    String title,
    String body, {
    String? parent,
    DateTime? startsAt,
    String? location,
  }) async => repository.object(
    'academic/rooms/$thread/items/$id',
    method: 'PUT',
    data: {
      'kind': kind,
      'title': title,
      'body': body,
      'parent': parent,
      'startsAt': startsAt?.toUtc().toIso8601String(),
      'location': location,
    },
  );

  Future<void> change(
    String thread,
    String id,
    String action,
    Object? value,
  ) async => repository.object(
    'academic/rooms/$thread/items/$id',
    method: 'PATCH',
    data: {'action': action, 'value': value},
  );

  Future<void> upload(
    String thread,
    String id,
    String filename,
    String title,
    Uint8List bytes,
    void Function(double) progress,
  ) async => repository.academicDocument(
    thread,
    id,
    bytes: bytes,
    name: filename,
    title: title,
    type: filename.toLowerCase().endsWith('.pdf')
        ? 'application/pdf'
        : 'text/plain',
    progress: progress,
  );

  Future<Uint8List> download(String thread, String id) =>
      repository.academicDocument(thread, id);

  static String newId() => CommunityRepository.newId();
}
