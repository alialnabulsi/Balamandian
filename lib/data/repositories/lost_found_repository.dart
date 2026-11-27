import 'dart:typed_data';

import '../../domain/models/lost_found_models.dart';
import '../../domain/models/note_models.dart';
import '../services/tools_api_service.dart';

abstract interface class LostFoundRepository {
  Future<List<LostFoundReport>> list();
  Future<LostFoundReport> read(String id);
  Future<LostFoundReport> submit({
    required String key,
    required String type,
    required String title,
    String? description,
    required List<String> uploads,
  });
  Future<LostFoundReport> withdraw(String id);
  Future<ReportUpload> upload(PickedNoteFile file, String key);
  Future<Uint8List> download(String id);
  Future<void> discard(String id);
  void cancelPending();
}

class ApiLostFoundRepository implements LostFoundRepository {
  ApiLostFoundRepository(this.api, this.withSession);
  final ToolsApiService api;
  final ToolSessionRequest withSession;
  Future<Object?> _req(
    String method,
    String path, {
    Object? body,
    int status = 200,
    Map<String, String>? query,
  }) => withSession(
    (t) =>
        api.request(t, method, path, body: body, status: status, query: query),
  );
  @override
  Future<List<LostFoundReport>> list() async {
    final out = <LostFoundReport>[];
    for (var page = 1; page <= 200; page++) {
      final j = await _req('GET', '', query: {'page': '$page'}) as Map;
      out.addAll((j['items'] as List).map(LostFoundReport.fromJson));
      if (j['hasMore'] != true) return out;
    }
    throw const FormatException('Too many reports');
  }

  @override
  Future<LostFoundReport> read(String id) async =>
      LostFoundReport.fromJson(await _req('GET', '/$id'));
  @override
  Future<LostFoundReport> submit({
    required String key,
    required String type,
    required String title,
    String? description,
    required List<String> uploads,
  }) async => LostFoundReport.fromJson(
    await _req(
      'POST',
      '',
      status: 201,
      body: {
        'submissionKey': key,
        'type': type,
        'title': title,
        'description': description,
        'uploadIds': uploads,
      },
    ),
  );
  @override
  Future<LostFoundReport> withdraw(String id) async =>
      LostFoundReport.fromJson(await _req('POST', '/$id/withdraw'));
  @override
  Future<ReportUpload> upload(PickedNoteFile file, String key) => withSession(
    (t) async => ReportUpload.fromJson(
      await api.request(
        t,
        'POST',
        '/uploads',
        upload: file,
        status: 201,
        headers: {'Idempotency-Key': key},
      ),
    ),
  );
  @override
  Future<Uint8List> download(String id) => withSession(
    (t) async =>
        await api.request(t, 'GET', '/uploads/$id', binary: true) as Uint8List,
  );
  @override
  Future<void> discard(String id) async {
    await _req('DELETE', '/uploads/$id', status: 204);
  }

  @override
  void cancelPending() => api.cancel();
}
