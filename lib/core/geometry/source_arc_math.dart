import 'dart:math' as math;
import 'dart:typed_data';

/// Float32 vector domain used by QIDI `Circle::calc_tangential_vector()` and
/// `ArcSegment::calc_arc_{radian,radius,length}()`.
///
/// These source helpers operate on unscaled `Vec3f`, unlike the integer
/// `coord_t` fitting geometry in `source_circle.dart`. Values are explicitly
/// quantized to IEEE-754 float32 at source-visible assignment boundaries.
class SourceVec3f {
  SourceVec3f(double x, double y, double z)
      : x = f32(x),
        y = f32(y),
        z = f32(z);

  final double x;
  final double y;
  final double z;

  SourceVec3f operator -(SourceVec3f other) => SourceVec3f(
        f32(x - other.x),
        f32(y - other.y),
        f32(z - other.z),
      );

  double get norm {
    final xx = f32(x * x);
    final yy = f32(y * y);
    final zz = f32(z * z);
    final sum = f32(f32(xx + yy) + zz);
    return f32(math.sqrt(sum));
  }

  double dot(SourceVec3f other) {
    final xx = f32(x * other.x);
    final yy = f32(y * other.y);
    final zz = f32(z * other.z);
    return f32(f32(xx + yy) + zz);
  }

  SourceVec3f normalized() {
    final length = norm;
    if (length == 0) return SourceVec3f(0, 0, 0);
    return SourceVec3f(
      f32(x / length),
      f32(y / length),
      f32(z / length),
    );
  }

  static double f32(double value) {
    final data = Float32List(1);
    data[0] = value;
    return data[0];
  }

  @override
  String toString() => 'SourceVec3f($x, $y, $z)';
}

/// Exact source formulas from the unscaled-vector section of `Circle.cpp`.
class SourceArcMath3 {
  const SourceArcMath3._();

  /// Port of `Circle::calc_tangential_vector()`.
  static SourceVec3f tangentialVector(
    SourceVec3f position,
    SourceVec3f center,
    bool isCcw,
  ) {
    final raw = center - position;
    final direction = SourceVec3f(raw.x, raw.y, 0).normalized();
    return isCcw
        ? SourceVec3f(direction.y, -direction.x, 0)
        : SourceVec3f(-direction.y, direction.x, 0);
  }

  /// Port of `ArcSegment::calc_arc_radian()` in the X-Y plane.
  static double arcRadian(
    SourceVec3f start,
    SourceVec3f end,
    SourceVec3f center,
    bool isCcw,
  ) {
    final d1Raw = center - start;
    final d2Raw = center - end;
    final delta1 = SourceVec3f(d1Raw.x, d1Raw.y, 0);
    final delta2 = SourceVec3f(d2Raw.x, d2Raw.y, 0);

    double radian;
    if ((delta1 - delta2).norm < 1e-6) {
      // C++ assigns `2 * M_PI` into a float.
      radian = SourceVec3f.f32(2 * math.pi);
    } else {
      // `Vec3f::dot()` returns float and is promoted to double by the source.
      final dot = delta1.dot(delta2);
      // The source explicitly casts components to double for the cross term.
      final cross = delta1.x.toDouble() * delta2.y.toDouble() -
          delta1.y.toDouble() * delta2.x.toDouble();
      radian = SourceVec3f.f32(math.atan2(cross, dot));
      if (isCcw) {
        radian = SourceVec3f.f32(
          radian < 0 ? 2 * math.pi + radian : radian,
        );
      } else {
        radian = SourceVec3f.f32(
          radian < 0 ? radian.abs() : 2 * math.pi - radian,
        );
      }
    }
    return radian;
  }

  /// Port of `ArcSegment::calc_arc_radius()`.
  static double arcRadius(SourceVec3f start, SourceVec3f center) {
    final raw = center - start;
    return SourceVec3f(raw.x, raw.y, 0).norm;
  }

  /// Port of `ArcSegment::calc_arc_length()`.
  static double arcLength(
    SourceVec3f start,
    SourceVec3f end,
    SourceVec3f center,
    bool isCcw,
  ) {
    return SourceVec3f.f32(
      arcRadius(start, center) * arcRadian(start, end, center, isCcw),
    );
  }
}
