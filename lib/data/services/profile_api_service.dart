import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/auth_failure.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/models/academic_profile.dart';

class ProfileApiService {
  ProfileApiService({
    required this._client,
    required Uri baseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _baseUrl = baseUrl {
    if (!baseUrl.hasAuthority ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        (baseUrl.path.isNotEmpty && baseUrl.path != '/') ||
        (baseUrl.scheme != 'https' &&
            !(kDebugMode &&
                baseUrl.scheme == 'http' &&
                const {
                  'localhost',
                  '127.0.0.1',
                  '10.0.2.2',
                }.contains(baseUrl.host)))) {
      throw ArgumentError(
        'Profile API requires an HTTPS origin; local HTTP is debug-only.',
      );
    }
  }
  final http.Client _client;
  final Uri _baseUrl;
  final Duration timeout;
  Future<AcademicProfile> academics(String token) => _json(
    token,
    'GET',
    '/api/v1/profile/me/academics',
    AcademicProfile.fromJson,
  );
  Future<AcademicProfile> syncAcademics(String token)=>_json(token,'POST','/api/v1/profile/me/academics/sync',AcademicProfile.fromJson);
  Future<UserProfile> own(String token) =>
      _json(token, 'GET', '/api/v1/profile/me', UserProfile.fromJson);
  Future<UserProfile> profile(String token, String id) => _json(
    token,
    'GET',
    '/api/v1/users/${_id(id)}/profile',
    UserProfile.fromJson,
  );
  Future<UserProfile> biography(String token, String value) => _json(
    token,
    'PATCH',
    '/api/v1/profile/me',
    UserProfile.fromJson,
    body: {'biography': value},
  );
  Future<UserProfile> follow(String token, String id, bool value) => _json(
    token,
    value ? 'PUT' : 'DELETE',
    '/api/v1/users/${_id(id)}/follow',
    UserProfile.fromJson,
  );
  Future<UserProfile> removeAvatar(String token) =>
      _json(token, 'DELETE', '/api/v1/profile/me/avatar', UserProfile.fromJson);
  Future<UserProfile> upload(String token, Uint8List bytes) => _json(
    token,
    'PUT',
    '/api/v1/profile/me/avatar',
    UserProfile.fromJson,
    bytes: bytes,
    contentType: _imageType(bytes),
  );
  Future<MemberPage> members(
    String token, {
    required MemberListKind kind,
    String? userId,
    String search = '',
    int page = 1,
  }) => _json(
    token,
    'GET',
    kind == MemberListKind.discover
        ? '/api/v1/users'
        : '/api/v1/users/${_id(userId!)}/${kind.name}',
    MemberPage.fromJson,
    query: {'search': search, 'page': '$page', 'limit': '20'},
  );
  Future<Uint8List> avatar(String token, String path) async {
    // The API may only refer to this origin's fixed, authenticated avatar route.
    if (!RegExp(r'^/api/v1/users/[a-f0-9-]{36}/avatar\?v=[a-f0-9-]{36}$')
        .hasMatch(path)) {
      throw const FormatException('Invalid avatar reference.');
    }
    final uri = Uri.parse(path);
    final response = await _send(token, 'GET', _baseUrl.resolveUri(uri));
    if (response.headers['content-type']?.split(';').first != 'image/webp' ||
        response.bodyBytes.length > 1000000) {
      throw const FormatException('Invalid avatar content.');
    }
    return response.bodyBytes;
  }

  static String _id(String id) {
    if (!RegExp(
      r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
    ).hasMatch(id)) {
      throw const FormatException('Invalid member id.');
    }
    return id;
  }

  static String _imageType(Uint8List b) {
    if (b.length > 1000000) throw ProfileFailure.fromCode('REQUEST_TOO_LARGE');
    if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255) {
      return 'image/jpeg';
    }
    if (b.length >= 8 &&
        b[0] == 137 &&
        b[1] == 80 &&
        b[2] == 78 &&
        b[3] == 71) {
      return 'image/png';
    }
    if (b.length >= 12 &&
        ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    throw ProfileFailure.fromCode('AVATAR_INVALID');
  }

  Future<T> _json<T>(
    String token,
    String method,
    String path,
    T Function(Object?) parse, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    Uint8List? bytes,
    String? contentType,
  }) async {
    final response = await _send(
      token,
      method,
      _baseUrl.replace(path: path, queryParameters: query),
      body: body,
      bytes: bytes,
      contentType: contentType,
    );
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data case {'data': final value}) return parse(value);
      throw const FormatException('Missing profile data.');
    } on FormatException {
      throw ProfileFailure.fromCode(null);
    }
  }

  Future<http.Response> _send(
    String token,
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    Uint8List? bytes,
    String? contentType,
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest(method, uri, abortTrigger: abort.future)
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'application/json, image/webp',
          });
    if (bytes != null) {
      request.headers['Content-Type'] = contentType!;
      request.bodyBytes = bytes;
    } else if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Profile timeout');
            },
          );
      if (response.statusCode != 200) {
        String? code;
        try {
          final payload = jsonDecode(utf8.decode(response.bodyBytes));
          if (payload case {'error': {'code': String c}}) code = c;
        } on FormatException {
          /* Ignore untrusted proxy bodies. */
        }
        if (response.statusCode == 401 && code == 'UNAUTHENTICATED') {
          throw AuthFailure.fromApi(code, statusCode: 401);
        }
        throw ProfileFailure.fromCode(code);
      }
      return response;
    } on TimeoutException {
      throw ProfileFailure.fromCode('NETWORK_ERROR');
    } on SocketException {
      throw ProfileFailure.fromCode('NETWORK_ERROR');
    } on http.ClientException {
      throw ProfileFailure.fromCode('NETWORK_ERROR');
    }
  }

  void close() => _client.close();
}
