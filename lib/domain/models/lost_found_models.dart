class ReportUpload {
  const ReportUpload(this.id, this.filename, this.mediaType, this.size);
  final String id, filename, mediaType;
  final int size;
  factory ReportUpload.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    return ReportUpload(
      j['id'] as String,
      j['filename'] as String,
      j['mediaType'] as String,
      j['size'] as int,
    );
  }
}

class LostFoundReport {
  const LostFoundReport({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.createdAt,
    this.description,
    this.uploads = const [],
  });
  final String id, type, title, status;
  final String? description;
  final DateTime createdAt;
  final List<ReportUpload> uploads;
  bool get active => status == 'submitted' || status == 'under_review';
  String get statusLabel => switch (status) {
    'under_review' => 'Under review',
    'resolved' => 'Resolved',
    'withdrawn' => 'Withdrawn',
    _ => 'Submitted',
  };
  factory LostFoundReport.fromJson(Object? value) {
    final j = value as Map<String, dynamic>;
    return LostFoundReport(
      id: j['id'] as String,
      type: j['type'] as String,
      title: j['title'] as String,
      status: j['status'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      description: j['description'] as String?,
      uploads: ((j['uploads'] as List?) ?? [])
          .map(ReportUpload.fromJson)
          .toList(),
    );
  }
}
