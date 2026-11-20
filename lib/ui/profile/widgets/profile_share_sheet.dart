import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/profile_models.dart';
import '../../core/ui/buttons/async_action_button.dart';
import 'profile_share_card.dart';

class ProfileShareSheet extends StatefulWidget {
  const ProfileShareSheet({
    super.key,
    required this.username,
    this.identity,
    this.loadAvatar,
  });
  final String username;
  final PublicUserIdentity? identity;
  final Future<Uint8List> Function(String)? loadAvatar;
  @override
  State<ProfileShareSheet> createState() => _ProfileShareSheetState();
}

class _ProfileShareSheetState extends State<ProfileShareSheet> {
  bool _copying = false, _copied = false;
  String? _error;
  Future<void> _copy() async {
    if (_copying) return;
    setState(() {
      _copying = true;
      _error = null;
    });
    try {
      await Clipboard.setData(ClipboardData(text: '@${widget.username}'));
      if (mounted) setState(() => _copied = true);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Could not copy. Select the username above to copy it.',
        );
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Share profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close share profile',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ProfileShareCard(
              username: widget.username,
              identity: widget.identity,
              loadAvatar: widget.loadAvatar,
            ),
            const SizedBox(height: 20),
            Text(
              'Your people, one search away.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Share your username. Other Balamandian members can find you in Discover members.',
            ),
            const SizedBox(height: 20),
            AsyncActionButton(
              label: _copied ? 'Username copied' : 'Copy username',
              running: _copying,
              runningLabel: 'Copying…',
              onPressed: _copy,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
