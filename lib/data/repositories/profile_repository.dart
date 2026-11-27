import 'package:flutter/foundation.dart';

import '../../domain/models/profile_models.dart';

abstract class ProfileRepository extends ChangeNotifier {
  void invalidatePublic() {}
  UserProfile? get currentUser;
  String? get currentUserId;
  String? get error;
  bool get loading;
  void bindSession(String? userId, Object? sessionIdentity);
  Future<UserProfile> loadOwn({bool refresh = false});
  Future<UserProfile> profile(String id, {bool refresh = false});
  Future<UserProfile> saveBiography(String biography);
  Future<UserProfile> uploadAvatar(Uint8List bytes);
  Future<UserProfile> removeAvatar();
  Future<UserProfile> follow(String id, bool value);
  Future<MemberPage> members({
    required MemberListKind kind,
    String? userId,
    String search = '',
    int page = 1,
  });
  Future<Uint8List> avatar(String path);
  UserProfile? cached(String id);
}
