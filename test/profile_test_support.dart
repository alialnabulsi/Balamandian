import 'dart:typed_data';

import 'package:balamandian/data/repositories/profile_repository.dart';
import 'package:balamandian/domain/models/profile_models.dart';

const ownId = '11111111-1111-4111-8111-111111111111';
const otherId = '22222222-2222-4222-8222-222222222222';
Map<String, Object?> profileJson({
  String id = ownId,
  bool own = true,
  String biography = 'Computing, campus life and good coffee.',
  String? avatarPath,
}) => {
  'id': id,
  'username': own ? 'ali.alnabulsi' : 'maya.haddad',
  'displayName': own ? 'Ali Al Nabulsi' : 'Maya Haddad',
  'biography': biography,
  'avatarPath': avatarPath,
  'roles': ['student'],
  'verified': true,
  'postsCount': 0,
  'followersCount': 0,
  'followingCount': 0,
  'isFollowing': false,
  'isSelf': own,
  if (own)
    'account': {
      'firstName': 'Ali',
      'lastName': 'Al Nabulsi',
      'sisId': 'FICTION001',
      'institutionalEmail': 'member@example.edu',
      'createdAt': '2026-11-02T10:02:00.000Z',
      'emailVerifiedAt': '2026-11-02T10:02:00.000Z',
      'institutionalRoles': ['student'],
      'academic': {
        'campus': 'Main campus',
        'admissionYear': 2023,
        'programs': [
          {
            'name': 'Computer Science',
            'department': 'Computing',
            'faculty': 'Science',
          },
        ],
        'departments': [],
      },
    },
};

class FakeProfileRepository extends ProfileRepository {
  Map<String, Object?> ownData = profileJson(),
      otherData = profileJson(id: otherId, own: false);
  UserProfile? _current;
  String? _id = ownId;
  String? failure;
  int ownLoads = 0, saves = 0, uploads = 0, removals = 0, memberLoads = 0;
  bool moreMembers = false;
  Future<MemberPage> Function(int page, String search)? memberRequest;
  Future<UserProfile> Function()? ownRequest;
  @override
  UserProfile? get currentUser => _current;
  @override
  String? get currentUserId => _id;
  @override
  String? get error => failure;
  @override
  bool get loading => false;
  @override
  void bindSession(String? userId, Object? sessionIdentity) {
    _id = userId;
    if (userId == null) {
      _current = null;
      notifyListeners();
    }
  }

  @override
  Future<UserProfile> loadOwn({bool refresh = false}) async {
    ownLoads++;
    if (failure != null) throw ProfileFailure('PROFILE_UNAVAILABLE', failure!);
    _current = ownRequest == null
        ? UserProfile.fromJson(ownData)
        : await ownRequest!();
    notifyListeners();
    return _current!;
  }

  @override
  UserProfile? cached(String id) =>
      id == _id ? _current : UserProfile.fromJson(otherData);
  @override
  Future<UserProfile> profile(String id, {bool refresh = false}) async =>
      id == _id ? loadOwn(refresh: refresh) : UserProfile.fromJson(otherData);
  @override
  Future<UserProfile> saveBiography(String biography) async {
    saves++;
    ownData = {...ownData, 'biography': biography};
    return loadOwn();
  }

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes) async {
    uploads++;
    ownData = {
      ...ownData,
      'avatarPath':
          '/api/v1/users/$ownId/avatar?v=33333333-3333-4333-8333-333333333333',
    };
    return loadOwn();
  }

  @override
  Future<UserProfile> removeAvatar() async {
    removals++;
    ownData = {...ownData, 'avatarPath': null};
    return loadOwn();
  }

  @override
  Future<UserProfile> follow(String id, bool value) async {
    otherData = {
      ...otherData,
      'isFollowing': value,
      'followersCount': value ? 1 : 0,
    };
    ownData = {...ownData, 'followingCount': value ? 1 : 0};
    await loadOwn();
    notifyListeners();
    return UserProfile.fromJson(otherData);
  }

  @override
  Future<MemberPage> members({
    required MemberListKind kind,
    String? userId,
    String search = '',
    int page = 1,
  }) async {
    memberLoads++;
    if (failure != null) throw ProfileFailure('PROFILE_UNAVAILABLE', failure!);
    if (memberRequest != null) return memberRequest!(page, search);
    return MemberPage(
      items: page == 1 && (search.isEmpty || 'maya.haddad'.contains(search))
          ? [UserProfile.fromJson(otherData)]
          : [],
      page: page,
      total: 1,
      hasMore: moreMembers && page == 1,
    );
  }

  @override
  Future<Uint8List> avatar(String path) async =>
      throw const ProfileFailure('AVATAR_MISSING', 'No image.');
}
