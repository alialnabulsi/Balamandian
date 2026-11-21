import 'dart:ui' as ui;

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../widgets/campus_map_tokens.dart';

/// Screen-facing pins anchor at the catalog coordinate; GPS remains a circle.
abstract final class CampusMarkerImages {
  static Future<void> install(mb.MapboxMap map) async {
    for (final entry in {
      'campus-pin': CampusMapTokens.destination,
      'campus-pin-selected': CampusMapTokens.selection,
    }.entries) {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder)..scale(2);
      final path = ui.Path()
        ..moveTo(20, 44)
        ..cubicTo(16, 38, 4, 26, 4, 18)
        ..cubicTo(4, -2, 36, -2, 36, 18)
        ..cubicTo(36, 26, 24, 38, 20, 44)
        ..close();
      canvas.drawShadow(path, const ui.Color(0x55000000), 2, false);
      canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xffffffff));
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = ui.Color(
            int.parse(entry.value.replaceFirst('#', 'ff'), radix: 16),
          )
          ..style = ui.PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        ui.Paint()
          ..color = const ui.Color(0xffffffff)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        const ui.Offset(20, 18),
        5,
        ui.Paint()..color = const ui.Color(0xffffffff),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(80, 92);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      await map.addImage(
        entry.key,
        2,
        mb.StyleImage.rgba(
          width: 80,
          height: 92,
          pixels: bytes!.buffer.asUint8List(),
        ),
      );
      image.dispose();
      picture.dispose();
    }
  }
}
