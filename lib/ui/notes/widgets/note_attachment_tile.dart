import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/models/note_models.dart';
import '../../core/ui/app_surface.dart';

class NoteAttachmentTile extends StatelessWidget {
  const NoteAttachmentTile({
    super.key,
    required this.block,
    required this.attachment,
    required this.preview,
    required this.onOpen,
    required this.onRemove,
    required this.onRetry,
    required this.onCancel,
    this.progress,
    this.error,
  });
  final NoteBlock block;
  final NoteAttachment? attachment;
  final Future<Uint8List?>? preview;
  final VoidCallback onOpen, onRemove, onRetry, onCancel;
  final double? progress;
  final String? error;
  @override
  Widget build(BuildContext context) => AppSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (attachment?.image == true && preview != null)
          FutureBuilder<Uint8List?>(
            future: preview,
            builder: (context, s) => s.data == null
                ? const SizedBox(
                    height: 80,
                    child: Center(child: Icon(Icons.image_outlined)),
                  )
                : InkWell(
                    onTap: onOpen,
                    child: Image.memory(
                      s.data!,
                      height: 180,
                      fit: BoxFit.contain,
                      cacheWidth: 1024,
                      semanticLabel: attachment!.filename,
                    ),
                  ),
          ),
        Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              attachment?.image == true
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_outlined,
            ),
            title: Text(attachment?.filename ?? 'Pending attachment'),
            subtitle: Text(
              attachment?.mediaType ?? 'Stored in your private local draft',
            ),
            onTap: attachment == null ? null : onOpen,
            trailing: IconButton(
              tooltip: 'Remove attachment from note',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
        if (progress != null) ...[
          LinearProgressIndicator(
            value: progress,
            semanticsLabel: 'Attachment upload',
          ),
          Text(
            '${(progress! * 100).round()}% · awaiting server acknowledgment',
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancel upload')),
        ],
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (progress == null && block.localId != null)
          TextButton(
            onPressed: onRetry,
            child: Text(
              error != null || attachment == null
                  ? 'Retry attachment upload'
                  : 'Retry retained file if needed',
            ),
          ),
      ],
    ),
  );
}
