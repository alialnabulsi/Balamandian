import 'package:flutter/material.dart';

import 'ui/core/themes/app_theme.dart';
import 'ui/home/widgets/home_screen.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(theme: appTheme, home: const HomeScreen());
  }
}
