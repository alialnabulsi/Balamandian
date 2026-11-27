import 'package:flutter/widgets.dart';

import '../../../data/repositories/profile_repository.dart';
import '../view_models/messaging_session.dart';

class MessagingScope extends InheritedNotifier<MessagingSession> {
  const MessagingScope({
    super.key,
    required MessagingSession session,
    required this.profiles,
    required super.child,
  }) : super(notifier: session);
  final ProfileRepository profiles;
  MessagingSession get session => notifier!;
  static MessagingScope? maybeOf(BuildContext context, {bool listen = true}) =>
      listen
      ? context.dependOnInheritedWidgetOfExactType<MessagingScope>()
      : context.getInheritedWidgetOfExactType<MessagingScope>();
  static MessagingScope of(BuildContext context, {bool listen = true}) =>
      maybeOf(context, listen: listen)!;
}
