import 'package:flutter/material.dart';

import '../../core/themes/startup_tokens.dart';

/// Semantic map colors; UI surfaces and controls continue to use ColorScheme.
abstract final class CampusMapTokens {
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
  static final route = _hex(StartupTokens.blue);
  static final destination = _hex(StartupTokens.navy);
  static final selection = _hex(StartupTokens.yellow);
  static final start = _hex(StartupTokens.green);
  static const casing = '#FFFFFF';
  static const building = '#7A9DAE';
  static const simulation = '#9866BB';
}
