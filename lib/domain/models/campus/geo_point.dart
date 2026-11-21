import 'dart:math' as math;

/// WGS84 longitude/latitude. Heights elsewhere in the dataset are metres AGL.
class GeoPoint {
  const GeoPoint(this.longitude, this.latitude);
  final double longitude, latitude;

  factory GeoPoint.parse(Object? value) {
    if (value is! List ||
        value.length != 2 ||
        value.any((v) => v is! num || !v.isFinite)) {
      throw const FormatException('Expected a finite [longitude, latitude].');
    }
    final point = GeoPoint(
      (value[0] as num).toDouble(),
      (value[1] as num).toDouble(),
    );
    if (point.longitude.abs() > 180 || point.latitude.abs() > 90) {
      throw const FormatException('Coordinate outside WGS84 bounds.');
    }
    return point;
  }

  List<double> toJson() => [longitude, latitude];
  double distanceTo(GeoPoint other) {
    final a = latitude * math.pi / 180, b = other.latitude * math.pi / 180;
    final dl = (other.longitude - longitude) * math.pi / 180;
    final dp = b - a;
    final h =
        math.pow(math.sin(dp / 2), 2) +
        math.cos(a) * math.cos(b) * math.pow(math.sin(dl / 2), 2);
    return 6371008.8 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  }

  double bearingTo(GeoPoint other) {
    final a = latitude * math.pi / 180, b = other.latitude * math.pi / 180;
    final dl = (other.longitude - longitude) * math.pi / 180;
    return (math.atan2(
                  math.sin(dl) * math.cos(b),
                  math.cos(a) * math.sin(b) -
                      math.sin(a) * math.cos(b) * math.cos(dl),
                ) *
                180 /
                math.pi +
            360) %
        360;
  }

  GeoPoint interpolate(GeoPoint other, double t) => GeoPoint(
    longitude + (other.longitude - longitude) * t,
    latitude + (other.latitude - latitude) * t,
  );
}

double lineLength(List<GeoPoint> points) {
  var length = 0.0;
  for (var i = 1; i < points.length; i++) {
    length += points[i - 1].distanceTo(points[i]);
  }
  return length;
}

class LineProjection {
  const LineProjection(this.point, this.distance, this.along, this.segment);
  final GeoPoint point;
  final double distance, along;
  final int segment;
}

/// Local tangent-plane projection; intended for campus-sized WGS84 datasets.
LineProjection projectOnLine(GeoPoint point, List<GeoPoint> line) {
  if (line.length < 2) throw ArgumentError('A line needs two coordinates.');
  LineProjection? best;
  var along = 0.0;
  final scale = math.cos(point.latitude * math.pi / 180);
  for (var i = 0; i < line.length - 1; i++) {
    final a = line[i], b = line[i + 1];
    final dx = (b.longitude - a.longitude) * scale;
    final dy = b.latitude - a.latitude;
    final square = dx * dx + dy * dy;
    final t = square == 0
        ? 0.0
        : (((point.longitude - a.longitude) * scale * dx +
                      (point.latitude - a.latitude) * dy) /
                  square)
              .clamp(0.0, 1.0);
    final projected = a.interpolate(b, t);
    final distance = point.distanceTo(projected);
    final length = a.distanceTo(b);
    if (best == null || distance < best.distance) {
      best = LineProjection(projected, distance, along + length * t, i);
    }
    along += length;
  }
  return best!;
}

List<GeoPoint> sliceLine(List<GeoPoint> line, double from, double to) {
  final total = lineLength(line);
  from = from.clamp(0, total);
  to = to.clamp(from, total);
  final result = <GeoPoint>[];
  var walked = 0.0;
  for (var i = 1; i < line.length; i++) {
    final length = line[i - 1].distanceTo(line[i]);
    final end = walked + length;
    if (end >= from && walked <= to && length > 0) {
      if (result.isEmpty) {
        result.add(
          line[i - 1].interpolate(
            line[i],
            ((from - walked) / length).clamp(0, 1),
          ),
        );
      }
      result.add(
        line[i - 1].interpolate(line[i], ((to - walked) / length).clamp(0, 1)),
      );
    }
    walked = end;
    if (walked >= to) break;
  }
  return result.isEmpty ? [line.first, line.first] : result;
}
