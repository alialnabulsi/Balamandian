import '../../domain/models/campus/campus_data.dart';
import '../services/campus_dataset_service.dart';

abstract class CampusRepository {
  Future<CampusData> load();
}

class AssetCampusRepository implements CampusRepository {
  AssetCampusRepository({required this.read, this.fixture = false});
  final Future<String> Function(String path) read;
  final bool fixture;
  Future<CampusData>? _cached;
  @override
  Future<CampusData> load() => _cached ??= _load().catchError((Object error) {
    _cached = null;
    throw error;
  });
  Future<CampusData> _load() async {
    final path = fixture ? 'assets/maps/fixtures' : 'assets/maps/campus';
    final documents = await Future.wait([
      read('$path/campus.json'),
      for (final name in CampusDatasetService.files)
        read('$path/$name.geojson'),
    ]);
    return CampusDatasetService().parse(
      Map.fromIterables(['campus', ...CampusDatasetService.files], documents),
    );
  }
}
