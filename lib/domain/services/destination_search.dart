import '../models/campus/campus_data.dart';

class DestinationSearch {
  const DestinationSearch();
  List<CampusDestination> search(
    Iterable<CampusDestination> destinations,
    String query, {
    String? category,
  }) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    int score(CampusDestination d) {
      final name = d.name.toLowerCase(), code = d.code.toLowerCase();
      final fields = [
        name,
        code,
        d.category.toLowerCase(),
        ...d.aliases.map((s) => s.toLowerCase()),
      ];
      if (terms.any((term) => !fields.any((field) => field.contains(term)))) {
        return -1;
      }
      final q = terms.join(' ');
      return q.isEmpty
          ? 0
          : code == q
          ? 100
          : name == q
          ? 90
          : name.startsWith(q)
          ? 80
          : 50;
    }

    final matches = destinations
        .where(
          (d) => (category == null || category == d.category) && score(d) >= 0,
        )
        .toList();
    matches.sort((a, b) {
      final rank = score(b).compareTo(score(a));
      return rank == 0 ? a.name.compareTo(b.name) : rank;
    });
    return matches;
  }
}
