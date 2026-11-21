import 'package:flutter/widgets.dart';

import 'app.dart';
import 'ui/map/mapbox/campus_map_configuration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CampusMapConfiguration.initialize();
  runApp(const MainApp());
}
