import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../community/widgets/community_actions.dart';
import 'messaging_scope.dart';

Future<void> openDirectChat(
  BuildContext context,
  String member, {
  String? story,
}) async {
  final scope = MessagingScope.maybeOf(context, listen: false);
  if (scope == null) return;
  await communityCommand(context, () async {
    final id = await scope.session.repository.direct(member);
    if (!context.mounted) return;
    await context.push<void>(
      Uri(path: '/messages/$id', queryParameters: {'story': ?story}).toString(),
    );
  });
}
