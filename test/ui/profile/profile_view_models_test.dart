import 'dart:async';

import 'package:balamandian/domain/models/profile_models.dart';
import 'package:balamandian/ui/profile/view_models/user_profile_view_model.dart';
import 'package:balamandian/ui/profile/view_models/edit_profile_view_model.dart';
import 'package:balamandian/ui/profile/view_models/member_list_view_model.dart';
import 'package:balamandian/ui/profile/view_models/current_identity_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../profile_test_support.dart';

void main() {
  test(
    'own/public loading, retry and follow reflect authoritative identity state',
    () async {
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      final own = UserProfileViewModel(repository: repo),
          other = UserProfileViewModel(repository: repo, userId: otherId);
      addTearDown(own.dispose);
      addTearDown(other.dispose);
      repo.failure = 'Try again';
      await own.load();
      expect(own.error, 'Try again');
      repo.failure = null;
      await own.load();
      await other.load();
      await other.toggleFollow();
      expect(other.profile!.isFollowing, true);
      expect(own.profile!.followingCount, 1);
      await other.toggleFollow();
      expect(other.profile!.followersCount, 0);
    },
  );
  test(
    'editing persists only on save and duplicate saves are blocked',
    () async {
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      final model = EditProfileViewModel(repository: repo);
      addTearDown(model.dispose);
      await model.initialize();
      model.biography = 'A draft';
      expect(repo.saves, 0);
      model.biography = 'a' * 251;
      expect(await model.save(), false);
      expect(repo.saves, 0);
      model.biography = 'Saved biography';
      final first = model.save();
      expect(await model.save(), false);
      expect(await first, true);
      expect(repo.currentUser!.biography, 'Saved biography');
      expect(repo.saves, 1);
    },
  );
  test(
    'member pagination and stale search responses do not replace newer results',
    () async {
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      final first = Completer<MemberPage>(), second = Completer<MemberPage>();
      repo.memberRequest = (page, search) =>
          search == 'new' ? second.future : first.future;
      final model = MemberListViewModel(
        repository: repo,
        kind: MemberListKind.discover,
      );
      addTearDown(model.dispose);
      final old = model.load(refresh: true);
      model.search = 'new';
      final current = model.load(refresh: true);
      second.complete(
        MemberPage(
          items: [UserProfile.fromJson(profileJson(id: otherId, own: false))],
          page: 1,
          total: 1,
          hasMore: false,
        ),
      );
      await current;
      first.complete(
        const MemberPage(items: [], page: 1, total: 0, hasMore: false),
      );
      await old;
      expect(model.items.single.identity.id, otherId);
      expect(model.loading, false);
      repo.memberRequest = null;
      repo.moreMembers = true;
      model.search = '';
      await model.load(refresh: true);
      expect(model.hasMore, true);
      await model.load();
      expect(model.hasMore, false);
      expect(model.items.length, 1);
    },
  );
  test(
    'shared identity immediately updates after edits and clears on logout',
    () async {
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      final identity = CurrentIdentityViewModel(repository: repo);
      addTearDown(identity.dispose);
      await repo.loadOwn();
      expect(identity.profile!.identity.displayName, 'Ali Al Nabulsi');
      await repo.saveBiography('Updated');
      expect(identity.profile!.biography, 'Updated');
      repo.bindSession(null, null);
      expect(identity.profile, isNull);
    },
  );
}
