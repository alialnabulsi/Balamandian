import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/themes/app_tokens.dart';
import '../view_models/guide_session.dart';
import 'guide_locale_picker.dart';

class GuideFrame extends StatelessWidget {
  const GuideFrame({
    super.key,
    required this.title,
    required this.session,
    required this.child,
    this.showLocale = true,
    this.onRefresh,
  });
  final String title;
  final GuideSession session;
  final Widget child;
  final bool showLocale;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      leading: BackButton(
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/');
          }
        },
      ),
      title: Text(title),
      actions: [
        if (showLocale)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppTokens.gutter),
            child: GuideLocalePicker(
              locale: session.locale,
              onChanged: session.selectLocale,
            ),
          ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: onRefresh == null
              ? child
              : RefreshIndicator(onRefresh: onRefresh!, child: child),
        ),
      ),
    ),
  );
}
