import 'package:flutter/foundation.dart';

import '../../../data/repositories/profile_repository.dart';
import '../../../domain/models/profile_models.dart';

class CurrentIdentityViewModel extends ChangeNotifier {
  CurrentIdentityViewModel({required this._repository}) {
    _repository.addListener(notifyListeners);
  }
  final ProfileRepository _repository;
  UserProfile? get profile => _repository.currentUser;
  Future<Uint8List> avatar(String path) => _repository.avatar(path);
  @override
  void dispose() {
    _repository.removeListener(notifyListeners);
    super.dispose();
  }
}
