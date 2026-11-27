import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/auth_failure.dart';
import '../../domain/models/community.dart';

class CommunityApiService {
  CommunityApiService(this._client, this._origin, {this.area = 'community'}) {
    final local =
        kDebugMode &&
        _origin.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(_origin.host);
    if ((!local && _origin.scheme != 'https') ||
        _origin.host.isEmpty ||
        _origin.userInfo.isNotEmpty ||
        _origin.hasQuery ||
        _origin.hasFragment ||
        (_origin.path.isNotEmpty && _origin.path != '/')) {
      throw ArgumentError('Community API requires an HTTPS origin.');
    }
  }
  final http.Client _client;
  final Uri _origin;
  final String area;

  Future<Object?> json(
    String token,
    String method,
    String path, {
    Map<String, String>? query,
    CommunityJson? data,
    Future<void>? cancel,
  }) async {
    final response = await _request(
      token,
      method,
      path,
      query: query,
      data: data,
      cancel: cancel,
    );
    try {
      return (jsonDecode(utf8.decode(response)) as CommunityJson)['data'];
    } catch (_) {
      throw const CommunityFailure(
        'The server returned an unexpected response.',
      );
    }
  }

  Future<CommunityJson> upload(
    String token,
    Uint8List bytes,
    String type,
    void Function(double) progress,
  ) async {
    final response = await _request(
      token,
      'POST',
      'media',
      bytes: bytes,
      type: type,
      progress: progress,
    );
    return (jsonDecode(utf8.decode(response)) as CommunityJson)['data']
        as CommunityJson;
  }

  Future<Uint8List> image(
    String token,
    String id, {
    required bool full,
    Future<void>? cancel,
  }) => _request(
    token,
    'GET',
    'media/$id',
    query: full ? {'size': 'full'} : null,
    image: true,
    cancel: cancel,
  );

  Future<Uint8List> document(
    String token,
    String path, {
    Uint8List? bytes,
    String? type,
    Map<String, String>? query,
    void Function(double)? progress,
  }) => _request(
    token,
    bytes == null ? 'GET' : 'PUT',
    path,
    bytes: bytes,
    type: type,
    query: query,
    progress: progress,
    document: bytes == null,
  );

  Future<Uint8List> _request(
    String token,
    String method,
    String path, {
    Map<String, String>? query,
    CommunityJson? data,
    Uint8List? bytes,
    String? type,
    void Function(double)? progress,
    bool image = false,
    bool document = false,
    Future<void>? cancel,
  }) async {
    final abort = Completer<void>();
    final uri = _origin.replace(
      pathSegments: ['api', 'v1', area, ...path.split('/')],
      queryParameters: query,
    );
    final deadline = Timer(
      Duration(seconds: bytes == null ? 23 : 40),
      abort.complete,
    );
    final stop = cancel == null
        ? abort.future
        : Future.any([abort.future, cancel]);
    final http.BaseRequest request;
    if (bytes != null) {
      final upload = http.AbortableStreamedRequest(
        method,
        uri,
        abortTrigger: stop,
      )..contentLength = bytes.length;
      request = upload;
      request.headers['Content-Type'] = type!;
      final source = Stream<List<int>>.fromIterable(
        Iterable.generate((bytes.length + 65535) ~/ 65536, (i) {
          final end = ((i + 1) * 65536).clamp(0, bytes.length);
          progress?.call(end / bytes.length);
          return Uint8List.sublistView(bytes, i * 65536, end);
        }),
      );
      unawaited(
        upload.sink
            .addStream(source)
            .then((_) => upload.sink.close())
            .catchError((Object _) {}),
      );
    } else {
      final buffered = http.AbortableRequest(method, uri, abortTrigger: stop);
      if (data != null) {
        buffered.headers['Content-Type'] = 'application/json';
        buffered.body = jsonEncode(data);
      }
      request = buffered;
    }
    request.followRedirects = false;
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = document
        ? 'application/pdf, text/plain'
        : image
        ? 'image/webp'
        : 'application/json';
    try {
      final response = await _client.send(request);
      final result = BytesBuilder(copy: false);
      final limit = image || document ? 8000000 : 600000;
      await for (final chunk in response.stream) {
        if (result.length + chunk.length > limit) {
          throw const CommunityFailure('The server response was too large.');
        }
        result.add(chunk);
      }
      final output = result.takeBytes();
      if (response.statusCode != 200) {
        String? code;
        String? detail;
        try {
          code =
              (jsonDecode(utf8.decode(output))
                      as CommunityJson)['error']['code']
                  as String?;
          detail =
              (jsonDecode(utf8.decode(output))
                      as CommunityJson)['error']['message']
                  as String?;
        } catch (_) {
          /* Proxy error. */
        }
        if (response.statusCode == 401 && code == 'UNAUTHENTICATED') {
          throw AuthFailure.fromApi(code, statusCode: 401);
        }
        throw CommunityFailure(switch (code) {
          'INVALID_IMAGE' => 'Choose a still JPEG, PNG or WebP image.',
          'REQUEST_TOO_LARGE' => 'This image is larger than 8 MB.',
          'MEDIA_LIMIT' =>
            'Too many unfinished uploads. Finish or discard a draft.',
          'MEDIA_UNAVAILABLE' || 'MEDIA_BUSY' =>
            'Image storage is temporarily unavailable. Try again.',
          'STORY_LIMIT' => 'You can keep up to 12 active stories.',
          'INTERACTION_DISABLED' =>
            'The author has turned off this interaction.',
          'MESSAGING_RESTRICTED' =>
            detail ?? 'This conversation cannot accept that action.',
          'COMMUNITY_NOT_FOUND' ||
          'PROFILE_NOT_FOUND' => 'This content is unavailable.',
          'RATE_LIMITED' => 'Too many actions. Wait a moment and retry.',
          'VALIDATION_ERROR' =>
            path.startsWith('academic/') && detail != null
                ? detail
                : 'Check the input or refresh and try again.',
          _ =>
            area == 'messaging'
                ? 'Messaging is temporarily unavailable. Try again.'
                : 'Community is temporarily unavailable. Try again.',
        }, unavailable: response.statusCode == 404);
      }
      if (image &&
          response.headers['content-type']?.split(';').first != 'image/webp') {
        throw const CommunityFailure('This image is unavailable.');
      }
      return output;
    } on SocketException {
      throw const CommunityFailure(
        'Check your connection and try again.',
        offline: true,
      );
    } on http.ClientException {
      throw const CommunityFailure(
        'Check your connection and try again.',
        offline: true,
      );
    } finally {
      deadline.cancel();
    }
  }

  void close() => _client.close();
}
