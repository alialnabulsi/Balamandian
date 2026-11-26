import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/models/community.dart';
import '../services/community_api_service.dart';
import 'auth_repository.dart';

class CommunityRepository extends ChangeNotifier {
  CommunityRepository(this._api, this._auth);
  final CommunityApiService _api;
  final AuthRepository _auth;
  Completer<void> _cancel = Completer<void>();
  String? get userId => _auth.user?.id;
  int _revision = 0;
  int get revision => _revision;

  void invalidate() {
    _cancel.complete();
    _cancel = Completer<void>();
    _revision++;
    notifyListeners();
  }

  Future<Object?> _json(
    String path, {
    String method = 'GET',
    CommunityJson? data,
    Map<String, String>? query,
  }) => _auth.withSession(
    (token) => _api.json(
      token,
      method,
      path,
      data: data,
      query: query,
      cancel: method == 'GET' ? _cancel.future : null,
    ),
  );

  Future<CommunityJson> object(
    String path, {
    String method = 'GET',
    CommunityJson? data,
    Map<String, String>? query,
  }) async =>
      await _json(path, method: method, data: data, query: query)
          as CommunityJson;

  Future<CommunityPage<T>> page<T>(
    String path,
    T Function(CommunityJson) parse, {
    String? cursor,
    Map<String, String>? query,
  }) async => CommunityPage.fromJson(
    await object(path, query: {...?query, 'cursor': ?cursor}),
    parse,
  );

  Future<CommunityPage<CommunityEntry>> entries(
    String path, {
    String? cursor,
    Map<String, String>? query,
  }) => page(path, CommunityEntry.fromJson, cursor: cursor, query: query);
  Future<CommunityEntry> entry(String id) async =>
      CommunityEntry.fromJson(await object('entries/$id'));
  Future<List<CommunityEntry>> stories({String? author}) async =>
      List.unmodifiable(
        (await _json(
          author == null ? 'stories' : 'profiles/$author/stories',
        ) as List).cast<CommunityJson>().map(CommunityEntry.fromJson),
      );
  Future<Uint8List> image(String id, {bool full = false}) => _auth.withSession(
    (t) => _api.image(t, id, full: full, cancel: _cancel.future),
  );
  Future<CommunityImage> upload(
    Uint8List bytes,
    String type,
    void Function(double) progress,
  ) async => CommunityImage.fromJson(
    await _auth.withSession((t) => _api.upload(t, bytes, type, progress)),
  );

  Future<void> mutate(
    String path, {
    String method = 'PUT',
    CommunityJson? data,
  }) async {
    await object(path, method: method, data: data);
  }

  Future<CommunityInbox> inbox({String? cursor, String? revision}) async =>
      CommunityInbox.fromJson(
        await object(
          revision == null ? 'notifications' : 'notifications/sync',
          query: {'cursor': ?cursor, 'revision': ?revision},
        ),
      );

  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  void dispose() {
    _cancel.complete();
    _api.close();
    super.dispose();
  }
}
