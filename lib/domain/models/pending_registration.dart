class PendingRegistration {
  const PendingRegistration({
    required this.id,
    required this.otpExpiresAt,
    required this.resendAvailableAt,
  });

  final String id;
  final DateTime otpExpiresAt;
  final DateTime resendAvailableAt;

  factory PendingRegistration.fromJson(Map<String, dynamic> json) {
    if (json case {
      'pendingRegistrationId': String id,
      'otpExpiresAt': String expires,
      'resendAvailableAt': String resend,
    }) {
      if (RegExp(
        r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        caseSensitive: false,
      ).hasMatch(id)) {
        return PendingRegistration(
          id: id,
          otpExpiresAt: DateTime.parse(expires).toUtc(),
          resendAvailableAt: DateTime.parse(resend).toUtc(),
        );
      }
    }
    throw const FormatException('Invalid pending registration.');
  }
}
