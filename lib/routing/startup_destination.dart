enum StartupDestination {
  splash('splash'),
  campus('campus'),
  community('community'),
  assistant('assistant'),
  gettingStarted('getting-started'),
  signUp('sign-up'),
  signIn('sign-in'),
  accountSetup('account-setup'),
  verifyEmail('verify-email');

  const StartupDestination(this.segment);
  final String segment;
  String get path => '/welcome/$segment';
  int get tourIndex => switch (this) {
    campus => 0,
    community => 1,
    assistant => 2,
    _ => -1,
  };
  static StartupDestination fromPath(String path) =>
      values.firstWhere((screen) => screen.path == path, orElse: () => splash);
}
