import 'package:go_router/go_router.dart';

import '../ui/home/widgets/home_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    ],
  );
}
