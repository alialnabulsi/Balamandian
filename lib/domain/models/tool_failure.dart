class ToolFailure implements Exception {
  const ToolFailure(this.code, this.message);
  final String? code;
  final String message;
  factory ToolFailure.fromCode(String? c) => ToolFailure(c, switch (c) {
    'TOOLS_FORBIDDEN' => 'This tool requires a student or advisor account.',
    'VALIDATION_ERROR' =>
      'Check the required fields, lengths, dates and attachment selections.',
    'CONFLICT' => 'This record changed or this retry has different content. Refresh and try again.',
    'RECORD_NOT_FOUND' => 'This record is unavailable.',
    'ATTACHMENT_INVALID' => 'Choose a valid JPG, PNG, WebP or PDF up to 5 MiB.',
    'RATE_LIMITED' => 'Too many changes. Please wait before retrying.',
    'SOURCE_UNAVAILABLE' || 'ACADEMICS_UNAVAILABLE' =>
      'University academic information could not be refreshed. Please retry.',
    'CANCELED' => 'Request cancelled.',
    _ => 'Unable to complete the request. Your changes have not been saved. Please retry.',
  });
}
