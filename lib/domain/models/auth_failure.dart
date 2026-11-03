class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message, {this.retryAfter});

  final String code, message;
  final Duration? retryAfter;

  static const messages = {
    'SIS_INVALID_CREDENTIALS': 'Your SIS ID/email or password is incorrect.',
    'ACCOUNT_EXISTS': 'An account already exists. Please log in.',
    'REGISTRATION_REQUIRED': 'Create an account before logging in.',
    'EMAIL_NOT_VERIFIED': 'Your account email has not been verified.',
    'ACCOUNT_DISABLED': 'Your account is disabled. Contact support.',
    'VALIDATION_ERROR': 'Check your details and try again.',
    'INVALID_JSON': 'The request could not be processed. Please try again.',
    'INVALID_REQUEST': 'The request could not be processed. Please try again.',
    'REGISTRATION_INVALID':
        'This registration is no longer valid. Start again.',
    'REGISTRATION_REPLACED': 'This registration was replaced. Start again.',
    'OTP_INVALID': 'That code is incorrect. Please try again.',
    'OTP_EXPIRED': 'Your code has expired. Request a new code.',
    'OTP_UNAVAILABLE': 'No code is available. Request a new code.',
    'OTP_ATTEMPT_LIMIT': 'Too many incorrect attempts. Request a new code.',
    'OTP_COOLDOWN': 'Please wait before requesting another code.',
    'OTP_RESEND_LIMIT':
        'The email limit was reached. Please wait before starting again.',
    'RATE_LIMITED': 'Too many requests. Please wait and try again.',
    'SIS_RATE_LIMITED': 'SIS is busy. Please wait and try again.',
    'SIS_UNAVAILABLE':
        'SIS is temporarily unavailable. Please try again later.',
    'SIS_INVALID_RESPONSE':
        'SIS is temporarily unavailable. Please try again later.',
    'EMAIL_UNAVAILABLE':
        'The email could not be sent. Please wait and try again.',
  };

  factory AuthFailure.fromApi(String? code, {Duration? retryAfter}) {
    return AuthFailure(
      messages.containsKey(code) ? code! : 'SERVICE_ERROR',
      messages[code] ?? 'The service is unavailable. Please try again later.',
      retryAfter: retryAfter,
    );
  }

  @override
  String toString() => 'AuthFailure($code)';
}
