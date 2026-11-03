import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

@immutable
class UniversityIdentity {
  const UniversityIdentity({this.name, this.major, this.faculty});
  final String? name, major, faculty;
}

@immutable
class ProfileDraft {
  const ProfileDraft({required this.bio, this.photo});
  final String bio;
  final XFile? photo;
}

// Shared navigation lock and deferred profile/guest UI callbacks.
class AuthUiController extends ChangeNotifier {
  AuthUiController({this.onGuest, this.onSetupSubmit});
  final VoidCallback? onGuest;
  final ValueChanged<ProfileDraft>? onSetupSubmit;
  bool _pending = false;
  String? _formError;
  UniversityIdentity? _identity;
  bool get pending => _pending;
  String? get formError => _formError;
  UniversityIdentity? get identity => _identity;
  set pending(bool value) {
    if (_pending == value) return;
    _pending = value;
    notifyListeners();
  }

  set formError(String? value) {
    final message = value?.trim().isEmpty == true ? null : value;
    if (_formError == message) return;
    _formError = message;
    notifyListeners();
  }

  set identity(UniversityIdentity? value) {
    _identity = value;
    notifyListeners();
  }

  void requestGuest() {
    if (!_pending) onGuest?.call();
  }

  void submitProfile(ProfileDraft values) {
    if (_pending) return;
    if (onSetupSubmit == null) {
      formError = 'No service is connected. No data was saved.';
    } else {
      onSetupSubmit!(values);
    }
  }

  void clearMessage() => formError = null;
}

class AuthUiScope extends InheritedNotifier<AuthUiController> {
  const AuthUiScope({
    super.key,
    required AuthUiController controller,
    required super.child,
  }) : super(notifier: controller);
  static AuthUiController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthUiScope>()!.notifier!;
}
