import 'package:balamandian/ui/auth/view_models/auth_ui_controller.dart';
import 'package:balamandian/ui/auth/view_models/profile_view_model.dart';
import 'package:balamandian/ui/auth/widgets/account_setup_screen.dart';
import 'package:balamandian/ui/core/themes/app_theme.dart';
import 'package:balamandian/ui/onboarding/widgets/startup_flow.dart';
import 'package:balamandian/routing/startup_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets(
    'Profile validates photos, supports removal and submits optional bio',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      final asset = await rootBundle.load(
        'assets/onboarding/images/onboarding-main-campus.png',
      );
      final valid = XFile.fromData(
        asset.buffer.asUint8List(),
        name: 'campus.png',
        mimeType: 'image/png',
      );
      XFile? selected = XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'invalid.txt',
      );
      ProfileDraft? submitted;
      final host = AuthUiController(
        onSetupSubmit: (value) => submitted = value,
      );
      addTearDown(host.dispose);
      await tester.pumpWidget(
        AuthUiScope(
          controller: host,
          child: MaterialApp(
            theme: appTheme,
            home: StartupNavigation(
              busy: false,
              screen: StartupDestination.accountSetup,
              navigate: (_) {},
              back: () {},
              child: AccountSetupScreen(pickPhoto: () async => selected),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Provided by SIS'), findsNWidgets(3));
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('Add a photo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose a JPG'), findsOneWidget);
      selected = valid;
      await tester.tap(find.text('Add a photo'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsOneWidget);
      await tester.tap(find.text('Remove photo'));
      await tester.pump();
      expect(find.text('Remove photo'), findsNothing);
      await tester.enterText(find.byType(TextField), '  A personal bio  ');
      await tester.pump();
      expect(find.text('18 / 240'), findsOneWidget);
      await tester.ensureVisible(find.text('Finish setup'));
      await tester.tap(find.text('Finish setup'));
      await tester.pump();
      expect(submitted?.bio, 'A personal bio');
      expect(submitted?.photo, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Oversized, corrupt and canceled photo selections are safe', (
    tester,
  ) async {
    var selected = XFile.fromData(Uint8List(1000001), name: 'large.png');
    final model = ProfileViewModel(pickPhoto: () async => selected);
    await tester.runAsync(model.selectPhoto);
    expect(model.photoError, contains('smaller than 1 MB'));
    selected = XFile.fromData(
      Uint8List.fromList([137, 80, 78, 71, 0, 0, 0, 0]),
      name: 'broken.png',
    );
    await tester.runAsync(model.selectPhoto);
    expect(model.photoError, contains('could not be opened'));
    model.dispose();
    final canceled = ProfileViewModel(pickPhoto: () async => null);
    await canceled.selectPhoto();
    expect(canceled.preview, isNull);
    expect(canceled.readingPhoto, isFalse);
    canceled.dispose();
  });
}
