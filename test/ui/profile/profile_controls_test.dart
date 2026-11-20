import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/core/ui/backgrounds/app_branded_background.dart';
import 'package:balamandian/ui/core/ui/loading/skeleton.dart';
import 'package:balamandian/ui/profile/view_models/edit_profile_view_model.dart';
import 'package:balamandian/ui/profile/widgets/member_list_item.dart';
import 'package:balamandian/ui/profile/widgets/member_list_screen.dart';
import 'package:balamandian/ui/profile/widgets/account_information_sheet.dart';
import 'package:balamandian/ui/profile/widgets/profile_editor_form.dart';
import 'package:balamandian/ui/profile/widgets/edit_profile_screen.dart';
import 'package:balamandian/ui/auth/view_models/profile_view_model.dart';
import 'package:balamandian/domain/models/profile_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../profile_network_support.dart';
import '../../profile_test_support.dart';

void main() {
  testWidgets(
    'reduced-motion skeleton announces once and schedules no continuous frames',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(
              body: SkeletonGroup(
                label: 'Loading members',
                child: Column(
                  children: [SkeletonMemberRow(), SkeletonMemberRow()],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Loading members'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, false);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.hasScheduledFrame, false);
      semantics.dispose();
    },
  );

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('stable social button and long member row at x$scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 740);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      final state = ValueNotifier((false, false));
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: state,
              builder: (context, value, _) => MemberListItem(
                member: UserProfile.fromJson({
                  ...profileJson(id: otherId, own: false),
                  'displayName': 'A Very Long University Member Name',
                  'username': 'averylonguniversityusername2026',
                  'isFollowing': value.$1,
                }),
                loadAvatar: repo.avatar,
                pending: value.$2,
                onOpen: () {},
                onFollow: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(OutlinedButton));
      state.value = (true, false);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(OutlinedButton)), size);
      state.value = (true, true);
      await tester.pump();
      expect(tester.getSize(find.byType(OutlinedButton)), size);
      expect(tester.takeException(), isNull);
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('save feedback preserves values and prevents duplicate writes', (
    tester,
  ) async {
    final network = ProfileNetworkHarness();
    addTearDown(network.close);
    final model = EditProfileViewModel(repository: network.repository);
    addTearDown(model.dispose);
    await model.initialize();
    final gate = Completer<http.Response>();
    network.intercept = (r) async => r.method == 'PATCH' ? gate.future : null;
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileEditorForm(model: model, onSaved: () => saved = true),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Keep my edit');
    await tester.ensureVisible(find.text('Save changes'));
    final button = find.byType(FilledButton);
    final size = tester.getSize(button);
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(model.saving, true);
    expect(model.biography, 'Keep my edit');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(tester.getSize(button), size);
    await model.save();
    gate.complete(
      http.Response(
        jsonEncode({'data': profileJson(biography: 'Keep my edit')}),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(saved, true);
    expect(network.calls.where((r) => r.method == 'PATCH'), hasLength(1));
  });

  testWidgets('connection tabs swipe and retain independent searches', (
    tester,
  ) async {
    final repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.loadOwn();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MemberListScreen(
          repository: repo,
          kind: MemberListKind.followers,
          userId: ownId,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear search'), findsNothing);
    await tester.enterText(find.byType(TextField), 'maya');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.enterText(find.byType(TextField), 'different');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'maya',
    );
    expect(find.text('Maya Haddad'), findsOneWidget);
  });

  testWidgets(
    'editor asks before discarding a draft and keeps edits on dismissal',
    (tester) async {
      final repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EditProfileScreen(repository: repo),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Unsaved campus note');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved campus note'), findsOneWidget);
      expect(repo.saves, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(repo.saves, 0);
    },
  );

  testWidgets(
    'account sheet scrolls at large text and public data stays private',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: AccountInformationSheet(
              profile: UserProfile.fromJson(profileJson()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Academic information'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final publicWithAccidentalAccount = UserProfile.fromJson({
        ...profileJson(),
        'isSelf': false,
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: AccountInformationSheet(profile: publicWithAccidentalAccount),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('FICTION001'), findsNothing);
      expect(find.text('member@example.edu'), findsNothing);
    },
  );

  testWidgets(
    'large valid photo is resized below backend limit; cancellation keeps preview',
    (tester) async {
      XFile? selection;
      final model = ProfileViewModel(pickPhoto: () async => selection);
      addTearDown(model.dispose);
      await tester.runAsync(() async {
        const width = 1200, height = 800;
        final random = math.Random(42);
        final pixels = Uint8List.fromList(
          List<int>.generate(
            width * height * 4,
            (i) => i % 4 == 3 ? 255 : random.nextInt(256),
          ),
        );
        final decoded = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          pixels,
          width,
          height,
          ui.PixelFormat.rgba8888,
          decoded.complete,
        );
        final image = await decoded.future;
        final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        expect(encoded!.lengthInBytes, greaterThan(1000000));
        selection = XFile.fromData(
          encoded.buffer.asUint8List(),
          name: 'ordinary-photo.png',
        );
        await model.selectPhoto();
      });
      expect(model.photoError, isNull);
      expect(model.preview!.length, lessThanOrEqualTo(1000000));
      final preview = model.preview;
      selection = null;
      await model.selectPhoto();
      expect(model.preview, same(preview));
      model.removePhoto();
      expect(model.preview, isNull);
    },
  );

  testWidgets('photo permission error is actionable', (tester) async {
    final model = ProfileViewModel(
      pickPhoto: () async =>
          throw PlatformException(code: 'photo_access_denied'),
    );
    addTearDown(model.dispose);
    await model.selectPhoto();
    expect(model.photoError, contains('Android settings'));
    expect(model.readingPhoto, false);
  });

  testWidgets('background scope paints the original asset only once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: const AppBrandedBackground(
          child: AppBrandedBackground(
            child: Scaffold(body: Text('Branded content')),
          ),
        ),
      ),
    );
    final backgrounds = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((widget) {
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.image?.image ==
                  const AssetImage(AppBrandedBackground.asset);
        });
    expect(backgrounds, hasLength(1));
    expect(appTheme.scaffoldBackgroundColor, Colors.transparent);
  });
}
