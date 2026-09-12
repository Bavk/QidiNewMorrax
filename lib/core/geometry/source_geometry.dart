import 'dart:math' as math;

/// Core numeric constants from `libslic3r/libslic3r.h`.
class Slic3rUnits {
  const Slic3rUnits._();

  static const double scalingFactor = 0.00001;
  static const double epsilon = 1e-4;
  static const int scaledEpsilon = 10;

  static double unscale(int value) => value * scalingFactor;
  static int scaleTruncated(double millimeters) =>
      (millimeters / scalingFactor).truncate();
}

/// Integer `coord_t` point domain used by the original slicer.
///
/// The existing Flutter scene/import layers use millimeter doubles for UI
/// convenience. Algorithms whose source semantics depend on integer rounding
/// must use this type (or an equivalent integer-coordinate type) internally.
class SourcePoint2 {
  const SourcePoint2(this.x, this.y);

  final int x;
  final int y;

  factory SourcePoint2.fromMm(double x, double y) => SourcePoint2(
        Slic3rUnits.scaleTruncated(x),
        Slic3rUnits.scaleTruncated(y),
      );

  double get xMm => Slic3rUnits.unscale(x);
  double get yMm => Slic3rUnits.unscale(y);

  SourcePoint2 operator +(SourcePoint2 other) =>
      SourcePoint2(x + other.x, y + other.y);
  SourcePoint2 operator -(SourcePoint2 other) =>
      SourcePoint2(x - other.x, y - other.y);

  double dot(SourcePoint2 other) =>
      x.toDouble() * other.x + y.toDouble() * other.y;
  double cross(SourcePoint2 other) =>
      x.toDouble() * other.y - y.toDouble() * other.x;

  double get squaredLength => x.toDouble() * x + y.toDouble() * y;
  double get length => math.sqrt(squaredLength);

  SourcePoint2 rotated(double angle, {SourcePoint2 center = const SourcePoint2(0, 0)}) {
    final s = math.sin(angle);
    final c = math.cos(angle);
    final dx = x.toDouble() - center.x;
    final dy = y.toDouble() - center.y;
    return SourcePoint2(
      _cppRound(center.x + c * dx - s * dy),
      _cppRound(center.y + c * dy + s * dx),
    );
  }

  static int _cppRound(double value) =>
      value >= 0 ? (value + 0.5).floor() : (value - 0.5).ceil();

  @override
  bool operator ==(Object other) =>
      other is SourcePoint2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'SourcePoint2($x, $y)';
}

/// Integer-coordinate port of the `Line` math used throughout libslic3r.
class SourceLine2 {
  const SourceLine2(this.a, this.b);

  final SourcePoint2 a;
  final SourcePoint2 b;

  SourcePoint2 get vector => b - a;
  double get length => vector.length;

  SourceLine2 translated(SourcePoint2 offset) =>
      SourceLine2(a + offset, b + offset);

  SourceLine2 rotated(
    double angle, {
    SourcePoint2 center = const SourcePoint2(0, 0),
  }) =>
      SourceLine2(
        a.rotated(angle, center: center),
        b.rotated(angle, center: center),
      );

  SourceLine2 reversed() => SourceLine2(b, a);

  double get orientation {
    var angle = math.atan2(b.y - a.y, b.x - a.x);
    if (angle < 0) angle = 2 * math.pi + angle;
    return angle;
  }

  double get direction {
    final angle = math.atan2(b.y - a.y, b.x - a.x);
    if ((angle - math.pi).abs() < Slic3rUnits.epsilon) return 0;
    return angle < 0 ? angle + math.pi : angle;
  }

  double distanceTo(SourcePoint2 point) {
    final v = vector;
    final va = point - a;
    final lengthSquared = v.squaredLength;
    if (lengthSquared == 0) return va.length;
    final t = va.dot(v) / lengthSquared;
    if (t <= 0) return va.length;
    if (t >= 1) return (point - b).length;
    final closestX = a.x + t * v.x;
    final closestY = a.y + t * v.y;
    final dx = closestX - point.x;
    final dy = closestY - point.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double perpDistanceTo(SourcePoint2 point) {
    final v = vector;
    final va = point - a;
    if (a == b) return va.length;
    return v.cross(va).abs() / v.length;
  }

  bool parallelTo(SourceLine2 other) {
    final v1 = vector;
    final v2 = other.vector;
    final cross = v1.cross(v2);
    final epsilonSquared = Slic3rUnits.epsilon * Slic3rUnits.epsilon;
    return cross * cross <
        epsilonSquared * v1.squaredLength * v2.squaredLength;
  }

  bool perpendicularTo(SourceLine2 other) {
    final v1 = vector;
    final v2 = other.vector;
    final dot = v1.dot(v2);
    final epsilonSquared = Slic3rUnits.epsilon * Slic3rUnits.epsilon;
    return dot * dot < epsilonSquared * v1.squaredLength * v2.squaredLength;
  }

  /// Port of `line_alg::intersection()` for integer `coord_t` lines.
  SourcePoint2? intersection(SourceLine2 other) {
    final v1 = vector;
    final v2 = other.vector;
    final denominator = v1.cross(v2);
    if (denominator.abs() < Slic3rUnits.epsilon) return null;

    final v12 = a - other.a;
    final numeratorA = v2.cross(v12);
    final numeratorB = v1.cross(v12);
    final t1 = numeratorA / denominator;
    final t2 = numeratorB / denominator;
    if (t1 < 0 || t1 > 1 || t2 < 0 || t2 > 1) return null;

    return SourcePoint2(
      (a.x + t1 * v1.x).truncate(),
      (a.y + t1 * v1.y).truncate(),
    );
  }

  /// Port of `Line::intersection_infinite()` excluding the C++ integer overflow
  /// guard; Dart integers do not overflow, while source coordinate-range guards
  /// are tracked separately at Clipper/Voronoi boundaries.
  SourcePoint2? intersectionInfinite(SourceLine2 other) {
    final v12 = other.a - a;
    final v1 = vector;
    final v2 = other.vector;
    final denominator = v1.cross(v2);
    if (denominator.abs() < Slic3rUnits.epsilon) return null;
    final t1 = v12.cross(v2) / denominator;
    return SourcePoint2(
      (a.x + t1 * v1.x).truncate(),
      (a.y + t1 * v1.y).truncate(),
    );
  }
}
