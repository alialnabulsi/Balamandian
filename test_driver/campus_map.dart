import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final snapshots = data['snapshots'] as Map<String, dynamic>? ?? {};
    final output = Directory('build/campus-map-verification/device');
    await output.create(recursive: true);
    for (final entry in snapshots.entries) {
      await File('${output.path}/${entry.key}.png')
          .writeAsBytes(base64Decode(entry.value as String));
    }
    await File('${output.path}/result.json').writeAsString(
      jsonEncode({
        'nativeSdk': data['nativeSdk'],
        'flutterSdk': data['flutterSdk'],
        'snapshots': snapshots.keys.toList(),
      }),
    );
  },
);
