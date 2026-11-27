class NotesExitGuard {
  Future<bool> Function()? confirm;
  Future<bool> check() async => await confirm?.call() ?? true;
}
