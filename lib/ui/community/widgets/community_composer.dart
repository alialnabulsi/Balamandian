import 'package:flutter/material.dart';

import '../../../data/repositories/community_repository.dart';
import '../../../domain/models/community.dart';
import '../../core/ui/buttons/async_action_button.dart';
import '../../core/ui/form_message.dart';
import '../view_models/community_composer_model.dart';
import 'community_media.dart';

class CommunityComposer extends StatefulWidget {
  const CommunityComposer({
    super.key,
    required this.repository,
    required this.story,
    this.previous,
  });
  final CommunityRepository repository;
  final bool story;
  final CommunityEntry? previous;
  @override
  State<CommunityComposer> createState() => _CommunityComposerState();
}

class _CommunityComposerState extends State<CommunityComposer> {
  late final model = CommunityComposerModel(
    widget.repository,
    story: widget.story,
    previous: widget.previous,
  );
  late final caption = TextEditingController(text: model.caption);
  bool _allow = false, _confirming = false;
  int _selected = 0;

  void _remove(int index) {
    model.remove(index);
    setState(() => _selected = index == 0 ? 0 : index - 1);
  }

  void _move(int index, int direction) {
    model.move(index, direction);
    setState(() => _selected = index + direction);
  }

  @override
  void dispose() {
    caption.dispose();
    model.dispose();
    super.dispose();
  }

  void _pop() {
    setState(() => _allow = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _close() async {
    if (model.busy || _confirming) return;
    if (!model.dirty) {
      _pop();
      return;
    }
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (confirmed == true && mounted) {
      await model.discard();
      if (mounted) _pop();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final theme = Theme.of(context);
      return PopScope(
        canPop: _allow || (!model.dirty && !model.busy),
        onPopInvokedWithResult: (popped, _) {
          if (!popped) _close();
        },
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Close editor',
              onPressed: model.busy ? null : _close,
              icon: const Icon(Icons.close),
            ),
            title: Text(
              widget.story
                  ? 'New story'
                  : widget.previous == null
                  ? 'New post'
                  : 'Edit post',
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                        children: [
                          if (model.images.isEmpty)
                            CommunityPickerPlaceholder(
                              story: widget.story,
                              onPick: model.picking ? null : () => model.pick(),
                            )
                          else
                            CommunityDraftPreview(
                              model: model,
                              index: _selected,
                            ),
                          const SizedBox(height: 12),
                          if (model.images.isNotEmpty && !widget.story)
                            CommunityMediaTray(
                              model: model,
                              selected: _selected,
                              onSelect: (index) =>
                                  setState(() => _selected = index),
                              onMove: (direction) =>
                                  _move(_selected, direction),
                              onRemove: () => _remove(_selected),
                            )
                          else
                            CommunityMediaControls(
                              model: model,
                              onRemove: () => _remove(_selected),
                            ),
                          const SizedBox(height: 18),
                          CommunityDraftCaption(
                            controller: caption,
                            story: widget.story,
                            readOnly: model.busy,
                            onChanged: model.edit,
                          ),
                        ],
                      ),
                    ),
                    CommunityPublishBar(
                      label: widget.previous != null
                          ? 'Save changes'
                          : widget.story
                          ? 'Publish story'
                          : 'Publish post',
                      model: model,
                      onPublish: () async {
                        FocusScope.of(context).unfocus();
                        if (await model.save() && mounted) _pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class CommunityPickerPlaceholder extends StatelessWidget {
  const CommunityPickerPlaceholder({
    super.key,
    required this.story,
    required this.onPick,
  });
  final bool story;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPick,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: story ? 92 : 48,
            horizontal: 16,
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Icon(
                  story
                      ? Icons.auto_awesome_outlined
                      : Icons.add_photo_alternate_outlined,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                story ? 'Choose a story photo' : 'Add photos',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (!story)
                Text('Up to six photos', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityDraftPreview extends StatelessWidget {
  const CommunityDraftPreview({
    super.key,
    required this.model,
    required this.index,
  });
  final CommunityComposerModel model;
  final int index;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: model.story ? 264 : 560),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: model.story ? 9 / 16 : 1.5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              CommunityDraftPhoto(
                model: model,
                index: index,
                fit: model.story ? BoxFit.cover : BoxFit.contain,
              ),
              if (model.story && model.caption.trim().isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: StoryOverlay(text: model.caption),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class CommunityDraftPhoto extends StatelessWidget {
  const CommunityDraftPhoto({
    super.key,
    required this.model,
    required this.index,
    required this.fit,
    this.thumbnail = false,
  });
  final CommunityComposerModel model;
  final int index;
  final BoxFit fit;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    final image = model.images[index];
    return switch (image.bytes) {
      final bytes? => Image.memory(
        bytes,
        fit: fit,
        cacheWidth: thumbnail ? 144 : 900,
        semanticLabel: thumbnail ? null : 'Selected photo ${index + 1}',
        excludeFromSemantics: thumbnail,
      ),
      null => CommunityMedia(
        repository: model.repository,
        image: image.uploaded!,
        full: !thumbnail,
        fit: fit,
      ),
    };
  }
}

class CommunityMediaTray extends StatelessWidget {
  const CommunityMediaTray({
    super.key,
    required this.model,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onRemove,
  });

  final CommunityComposerModel model;
  final int selected;
  final ValueChanged<int> onSelect, onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final available = !model.busy && !model.picking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Photos', style: theme.textTheme.titleSmall)),
            Text(
              '${model.images.length} of ${model.limit}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 61,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: model.images.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) => Semantics(
              selected: index == selected,
              child: Tooltip(
                message: 'Preview photo ${index + 1}',
                child: InkWell(
                  onTap: available ? () => onSelect(index) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 61,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: index == selected
                            ? colors.primary
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CommunityDraftPhoto(
                        model: model,
                        index: index,
                        fit: BoxFit.cover,
                        thumbnail: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        CommunityMediaControls(
          model: model,
          onRemove: onRemove,
          onMove: onMove,
          selected: selected,
        ),
      ],
    );
  }
}

class CommunityMediaControls extends StatelessWidget {
  const CommunityMediaControls({
    super.key,
    required this.model,
    required this.onRemove,
    this.onMove,
    this.selected = 0,
  });

  final CommunityComposerModel model;
  final VoidCallback onRemove;
  final ValueChanged<int>? onMove;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final available = !model.busy && !model.picking;
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [
        if (model.images.length < model.limit) ...[
          TextButton.icon(
            onPressed: available ? () => model.pick() : null,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Gallery'),
          ),
          TextButton.icon(
            onPressed: available ? () => model.pick(camera: true) : null,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Camera'),
          ),
        ],
        if (onMove != null && model.images.length > 1) ...[
          IconButton(
            tooltip: 'Move photo earlier',
            onPressed: available && selected > 0 ? () => onMove!(-1) : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 19),
          ),
          IconButton(
            tooltip: 'Move photo later',
            onPressed: available && selected + 1 < model.images.length
                ? () => onMove!(1)
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),
          ),
        ],
        if (model.images.isNotEmpty)
          IconButton(
            tooltip: 'Remove photo ${selected + 1}',
            onPressed: available ? onRemove : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
      ],
    );
  }
}

class CommunityDraftCaption extends StatelessWidget {
  const CommunityDraftCaption({
    super.key,
    required this.controller,
    required this.story,
    required this.readOnly,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool story, readOnly;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          story ? 'Story text' : 'Caption',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: readOnly,
          maxLength: story ? 160 : 2200,
          minLines: story ? 1 : 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLow,
            border: const OutlineInputBorder(borderSide: BorderSide.none),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide.none,
            ),
            hintText: story
                ? 'Add text to the photo'
                : 'Write a caption or mention @username',
            counterText: '',
          ),
        ),
      ],
    );
  }
}

class CommunityPublishBar extends StatelessWidget {
  const CommunityPublishBar({
    super.key,
    required this.model,
    required this.label,
    required this.onPublish,
  });

  final CommunityComposerModel model;
  final String label;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FormMessage(model.error.toString()),
          ),
        if (model.busy) ...[
          LinearProgressIndicator(
            value: model.progress,
            semanticsLabel: 'Publishing progress',
          ),
          const SizedBox(height: 8),
        ],
        AsyncActionButton(
          label: label,
          running: model.busy,
          runningLabel: 'Publishing…',
          onPressed: model.images.isEmpty || model.picking ? null : onPublish,
        ),
      ],
    ),
  );
}

class StoryOverlay extends StatelessWidget {
  const StoryOverlay({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(18),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: Colors.white),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
