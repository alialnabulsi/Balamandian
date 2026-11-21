import 'dart:io';

import 'package:balamandian/data/services/campus_dataset_service.dart';

void main(List<String> arguments) {
  final directory = arguments.isEmpty ? 'assets/maps/campus' : arguments.single;
  try {
    final data = CampusDatasetService().parse({
      'campus': File('$directory/campus.json').readAsStringSync(),
      for (final name in CampusDatasetService.files)
        name: File('$directory/$name.geojson').readAsStringSync(),
    });
    final remaining = data.nodes.keys.toSet();
    var components = 0;
    while (remaining.isNotEmpty) {
      components++;
      final pending = [remaining.first];
      while (pending.isNotEmpty) {
        final id = pending.removeLast();
        if (!remaining.remove(id)) continue;
        for (final edge in data.edges.values.where((e) => !e.restricted)) {
          if (edge.from == id && remaining.contains(edge.to)) {
            pending.add(edge.to);
          }
          if (edge.to == id && remaining.contains(edge.from)) {
            pending.add(edge.from);
          }
        }
      }
    }
    stdout.writeln(
      '${data.id} (${data.revision}) VALID${data.fixture ? ' — SYNTHETIC FIXTURE' : ''}',
    );
    stdout.writeln(
      '${data.destinations.length} destinations, ${data.entrances.length} entrances, '
      '${data.nodes.length} nodes, ${data.edges.length} edges, $components weak components (restricted edges excluded).',
    );
    if (components > 1) {
      stdout.writeln(
        'Review disconnected components; directed reachability is checked by route tests.',
      );
    }
    if (data.provisionalBounds) {
      stdout.writeln(
        'Camera envelope is provisional; it is not a surveyed boundary.',
      );
    }
    if (!data.routingAvailable) {
      stdout.writeln(
        'Walking directions unavailable: supply verified paths and entrances.',
      );
    }
    stdout.writeln(
      'Run QGIS Check Validity and topology/field review before approving data for use.',
    );
  } on Object catch (error) {
    stderr.writeln('INVALID campus dataset: $error');
    exitCode = 1;
  }
}
