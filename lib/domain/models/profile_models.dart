import 'package:flutter/foundation.dart';

Map<String, dynamic> _object(Object? v) {
  if (v is! Map<String, dynamic>) {
    throw const FormatException('Invalid profile.');
  }
  return v;
}

String _text(Object? v) {
  if (v is! String) throw const FormatException('Invalid profile text.');
  return v;
}

int _count(Object? v) {
  if (v is! int || v < 0) throw const FormatException('Invalid profile count.');
  return v;
}

bool _flag(Object? v) {
  if (v is! bool) throw const FormatException('Invalid profile flag.');
  return v;
}

List<String> _strings(Object? v) {
  if (v is! List) throw const FormatException('Invalid profile roles.');
  return List.unmodifiable(v.map(_text));
}

/// The shared public identity for posts, comments, member lists and the shell.
@immutable
class PublicUserIdentity {
  const PublicUserIdentity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarPath,
    required this.verified,
    required this.roles,
  });
  final String id, username, displayName;
  final String? avatarPath;
  final bool verified;
  final List<String> roles;
  factory PublicUserIdentity.fromJson(Object? value) {
    final j = _object(value);
    return PublicUserIdentity(
      id: _text(j['id']),
      username: _text(j['username']),
      displayName: _text(j['displayName']),
      avatarPath: j['avatarPath'] == null ? null : _text(j['avatarPath']),
      verified: _flag(j['verified']),
      roles: _strings(j['roles']),
    );
  }
}

@immutable
class AcademicProgram {
  const AcademicProgram(this.name, this.department, this.faculty);
  final String name, department, faculty;
}

@immutable
class AcademicDepartment {
  const AcademicDepartment(this.name, this.faculty);
  final String name, faculty;
}

@immutable
class AccountInformation {
  const AccountInformation({
    required this.firstName,
    required this.lastName,
    required this.sisId,
    required this.institutionalEmail,
    required this.createdAt,
    required this.emailVerifiedAt,
    required this.roles,
    required this.campus,
    required this.admissionYear,
    required this.programs,
    required this.departments,
  });
  final String firstName, lastName, sisId, institutionalEmail;
  final DateTime createdAt, emailVerifiedAt;
  final List<String> roles;
  final String? campus;
  final int? admissionYear;
  final List<AcademicProgram> programs;
  final List<AcademicDepartment> departments;
  factory AccountInformation.fromJson(Object? value) {
    final j = _object(value), a = _object(j['academic']);
    if (a['programs'] is! List || a['departments'] is! List) {
      throw const FormatException('Invalid academics.');
    }
    return AccountInformation(
      firstName: _text(j['firstName']),
      lastName: _text(j['lastName']),
      sisId: _text(j['sisId']),
      institutionalEmail: _text(j['institutionalEmail']),
      createdAt: DateTime.parse(_text(j['createdAt'])),
      emailVerifiedAt: DateTime.parse(_text(j['emailVerifiedAt'])),
      roles: _strings(j['institutionalRoles']),
      campus: a['campus'] == null ? null : _text(a['campus']),
      admissionYear: a['admissionYear'] == null
          ? null
          : _count(a['admissionYear']),
      programs: List.unmodifiable(
        (a['programs'] as List).map((v) {
          final p = _object(v);
          return AcademicProgram(
            _text(p['name']),
            _text(p['department']),
            _text(p['faculty']),
          );
        }),
      ),
      departments: List.unmodifiable(
        (a['departments'] as List).map((v) {
          final d = _object(v);
          return AcademicDepartment(_text(d['name']), _text(d['faculty']));
        }),
      ),
    );
  }
}

@immutable
class UserProfile {
  const UserProfile({
    required this.identity,
    required this.biography,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.isFollowing,
    required this.isSelf,
    this.privateAccount = false,
    this.followRequested = false,
    this.account,
  });
  final PublicUserIdentity identity;
  final String biography;
  final int postsCount, followersCount, followingCount;
  final bool isFollowing, isSelf;
  final bool privateAccount, followRequested;
  final AccountInformation? account;
  factory UserProfile.fromJson(Object? value) {
    final j = _object(value);
    return UserProfile(
      identity: PublicUserIdentity.fromJson(j),
      biography: _text(j['biography']),
      postsCount: _count(j['postsCount']),
      followersCount: _count(j['followersCount']),
      followingCount: _count(j['followingCount']),
      isFollowing: _flag(j['isFollowing']),
      isSelf: _flag(j['isSelf']),
      privateAccount: j['privateAccount'] == true,
      followRequested: j['followRequested'] == true,
      account: j['account'] == null
          ? null
          : AccountInformation.fromJson(j['account']),
    );
  }
}

@immutable
class MemberPage {
  const MemberPage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });
  final List<UserProfile> items;
  final int page, total;
  final bool hasMore;
  factory MemberPage.fromJson(Object? value) {
    final j = _object(value);
    if (j['items'] is! List) throw const FormatException('Invalid members.');
    return MemberPage(
      items: List.unmodifiable((j['items'] as List).map(UserProfile.fromJson)),
      page: _count(j['page']),
      total: _count(j['total']),
      hasMore: _flag(j['hasMore']),
    );
  }
}

enum MemberListKind { discover, followers, following }

class ProfileFailure implements Exception {
  const ProfileFailure(this.code, this.message);
  final String code, message;
  static const messages = {
    'PROFILE_UNAVAILABLE': 'Your university identity is temporarily unavailable. Your session is still valid. Please retry.',
    'PROFILE_NOT_FOUND': 'This university profile is unavailable.',
    'AVATAR_INVALID': 'Choose a single-frame JPG, PNG or WebP up to 1 MB and 4096 pixels per side.',
    'REQUEST_TOO_LARGE': 'Choose a photo smaller than 1 MB.',
    'SELF_FOLLOW': 'You cannot follow yourself.',
    'RATE_LIMITED': 'Too many requests. Please wait before trying again.',
    'VALIDATION_ERROR': 'Check your biography and try again.',
    'NETWORK_ERROR': 'Could not connect. Check your connection and try again.',
    'SESSION_CHANGED': 'Your session changed. Please try again.',
  };
  factory ProfileFailure.fromCode(String? code) => ProfileFailure(
    code ?? 'SERVICE_ERROR',
    messages[code] ?? 'Profiles are unavailable. Please try again.',
  );
}
