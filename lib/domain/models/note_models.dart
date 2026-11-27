import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

String noteLocalId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class NotesFailure implements Exception {
  const NotesFailure(this.code, this.message);
  final String code, message;
  factory NotesFailure.fromCode(
    String? code,
  ) => NotesFailure(code ?? 'SERVICE_ERROR', switch (code) {
    'NOTE_CONFLICT' => 'This note changed elsewhere. Your draft is preserved. Reload the latest version before saving again.',
    'NOTE_NOT_FOUND' => 'This note, folder or attachment is unavailable. A deleted note will not be recreated.',
    'NOTES_FORBIDDEN' => 'My Notes requires a student or advisor account.',
    'PLAYGROUND_PROTECTED' => 'Playground cannot be renamed, moved or deleted.',
    'FOLDER_CYCLE' => 'Choose a destination outside this folder and its descendants (maximum 20 levels).',
    'ATTACHMENT_INVALID' => 'Choose a valid JPG, PNG, WebP or PDF up to 5 MiB.',
    'ATTACHMENT_IN_USE' =>
      'Remove the attachment from the document and save first.',
    'NOTES_LIMIT' =>
      'Limit reached: 1000 folders/notes, 10 attachments per note.',
    'VALIDATION_ERROR' => 'Check title (160 characters), folder name (80) and document limits (512 KiB / 100 blocks / 50,000 characters).',
    'RATE_LIMITED' => 'Too many requests. Wait briefly and retry.',
    'REQUEST_TOO_LARGE' => 'The file or document is too large.',
    'CANCELED' => 'Operation canceled. Your local draft is preserved.',
    _ =>
      'Notes could not connect or load. Your draft is preserved. Please retry.',
  });
}

Map<String, dynamic> noteMap(Object? v) {
  if (v is! Map<String, dynamic>) {
    throw const FormatException('Invalid note data');
  }
  return v;
}

class InkPoint {
  const InkPoint(this.x, this.y);
  final double x, y;
  Map<String, Object> toJson() => {'x': x, 'y': y};
  factory InkPoint.fromJson(Object? v) {
    final m = noteMap(v);
    final x = (m['x'] as num).toDouble(), y = (m['y'] as num).toDouble();
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      throw const FormatException('Invalid point');
    }
    return InkPoint(x, y);
  }
}

class InkStroke {
  const InkStroke({
    required this.color,
    required this.width,
    required this.points,
  });
  final int color;
  final double width;
  final List<InkPoint> points;
  Map<String, Object> toJson() => {
    'color': color,
    'width': width,
    'points': points.map((p) => p.toJson()).toList(),
  };
  factory InkStroke.fromJson(Object? v) {
    final m = noteMap(v);
    final c = m['color'] as int, w = (m['width'] as num).toDouble();
    if (c < 0 || c > 4 || ![.004, .008, .016].contains(w)) {
      throw const FormatException('Invalid pen');
    }
    return InkStroke(
      color: c,
      width: w,
      points: List.unmodifiable((m['points'] as List).map(InkPoint.fromJson)),
    );
  }
}

class NoteBlock {
  NoteBlock({
    String? id,
    this.type = 'paragraph',
    this.text = '',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strokes = const [],
    this.attachmentId,
    this.localId,
  }) : id = id ?? noteLocalId();
  final String id, type, text;
  final bool bold, italic, underline;
  final List<InkStroke> strokes;
  final String? attachmentId, localId;
  bool get isText =>
      ['paragraph', 'heading', 'bullet', 'numbered'].contains(type);
  NoteBlock copy({
    String? type,
    String? text,
    bool? bold,
    bool? italic,
    bool? underline,
    List<InkStroke>? strokes,
    String? attachmentId,
  }) => NoteBlock(
    id: id,
    type: type ?? this.type,
    text: text ?? this.text,
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    underline: underline ?? this.underline,
    strokes: strokes ?? this.strokes,
    attachmentId: attachmentId ?? this.attachmentId,
    localId: localId,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    if (isText) ...{
      'text': text,
      'bold': bold,
      'italic': italic,
      'underline': underline,
    },
    if (type == 'drawing') 'strokes': strokes.map((s) => s.toJson()).toList(),
    if (type == 'attachment') ...{
      if (attachmentId != null) 'attachmentId': attachmentId,
      if (localId != null) 'localId': localId,
    },
  };
  factory NoteBlock.fromJson(Object? v) {
    final m = noteMap(v);
    final b = NoteBlock(
      id: m['id'] as String,
      type: m['type'] as String,
      text: m['text'] as String? ?? '',
      bold: m['bold'] as bool? ?? false,
      italic: m['italic'] as bool? ?? false,
      underline: m['underline'] as bool? ?? false,
      strokes: List.unmodifiable(
        (m['strokes'] as List? ?? []).map(InkStroke.fromJson),
      ),
      attachmentId: m['attachmentId'] as String?,
      localId: m['localId'] as String?,
    );
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(b.id) ||
        (!b.isText && !['drawing', 'attachment'].contains(b.type))) {
      throw const FormatException('Invalid block');
    }
    return b;
  }
}

class NoteDocument {
  NoteDocument(Iterable<NoteBlock> blocks) : blocks = List.unmodifiable(blocks);
  final List<NoteBlock> blocks;
  Map<String, Object> toJson() => {
    'version': 1,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };
  Map<String, Object> toServerJson() => {
    'version': 1,
    'blocks': blocks.map((b) => b.toJson()..remove('localId')).toList(),
  };
  factory NoteDocument.fromJson(Object? v) {
    final m = noteMap(v);
    if (m['version'] != 1) throw const FormatException('Unsupported document');
    return NoteDocument((m['blocks'] as List).map(NoteBlock.fromJson));
  }
  String? get error {
    if (blocks.length > 100 ||
        utf8.encode(jsonEncode(toJson())).length > 524288) {
      return 'Document limit: 100 blocks and 512 KiB.';
    }
    if (blocks.fold<int>(0, (n, b) => n + b.text.runes.length) > 50000) {
      return 'Text limit: 50,000 characters.';
    }
    final strokes = blocks.expand((b) => b.strokes);
    if (strokes.length > 200 ||
        strokes.fold<int>(0, (n, s) => n + s.points.length) > 10000) {
      return 'Drawing limit: 200 strokes and 10,000 points.';
    }
    if (blocks.where((b) => b.type == 'attachment').length > 10) {
      return 'A note supports 10 attachments.';
    }
    if (blocks.any((b) => b.localId != null && b.attachmentId == null)) {
      return 'Upload or remove pending attachments before saving.';
    }
    return null;
  }
}

class NoteFolder {
  const NoteFolder(this.id, this.parentId, this.name, this.playground);
  final String id, name;
  final String? parentId;
  final bool playground;
  factory NoteFolder.fromJson(Object? v) {
    final m = noteMap(v);
    return NoteFolder(
      m['id'] as String,
      m['parentId'] as String?,
      m['name'] as String,
      m['playground'] as bool,
    );
  }
}

String noteFolderPath(List<NoteFolder> folders, String? id) {
  final parts = <String>[];
  var at = id;
  while (at != null && parts.length <= 20) {
    final f = folders.where((f) => f.id == at).firstOrNull;
    if (f == null) break;
    parts.insert(0, f.name);
    at = f.parentId;
  }
  return parts.isEmpty ? 'My Notes' : parts.join(' / ');
}

class NoteAttachment {
  const NoteAttachment(this.id, this.filename, this.mediaType, this.size);
  final String id, filename, mediaType;
  final int size;
  bool get image => mediaType == 'image/webp';
  factory NoteAttachment.fromJson(Object? v) {
    final m = noteMap(v);
    return NoteAttachment(
      m['id'] as String,
      m['filename'] as String,
      m['mediaType'] as String,
      m['size'] as int,
    );
  }
}

class PersonalNote {
  const PersonalNote({
    required this.id,
    required this.folderId,
    required this.title,
    required this.revision,
    required this.updatedAt,
    this.document,
    this.preview = '',
    this.attachments = const [],
  });
  final String id, folderId, title, preview;
  final int revision;
  final DateTime updatedAt;
  final NoteDocument? document;
  final List<NoteAttachment> attachments;
  factory PersonalNote.fromJson(Object? v) {
    final m = noteMap(v);
    return PersonalNote(
      id: m['id'] as String,
      folderId: m['folderId'] as String,
      title: m['title'] as String,
      revision: m['revision'] as int,
      updatedAt: DateTime.parse(m['updatedAt'] as String),
      document: m['document'] == null
          ? null
          : NoteDocument.fromJson(m['document']),
      preview: m['preview'] as String? ?? '',
      attachments: List.unmodifiable(
        (m['attachments'] as List? ?? []).map(NoteAttachment.fromJson),
      ),
    );
  }
}

class PickedNoteFile {
  const PickedNoteFile(this.name, this.type, this.bytes);
  final String name, type;
  final Uint8List bytes;
}

class NoteDraft {
  const NoteDraft({
    required this.noteId,
    required this.title,
    required this.folderId,
    required this.revision,
    required this.document,
  });
  final String noteId, title, folderId;
  final int revision;
  final NoteDocument document;
  Map<String, Object> toJson() => {
    'noteId': noteId,
    'title': title,
    'folderId': folderId,
    'revision': revision,
    'document': document.toJson(),
  };
  factory NoteDraft.fromJson(Object? v) {
    final m = noteMap(v);
    return NoteDraft(
      noteId: m['noteId'] as String,
      title: m['title'] as String,
      folderId: m['folderId'] as String,
      revision: m['revision'] as int,
      document: NoteDocument.fromJson(m['document']),
    );
  }
}
