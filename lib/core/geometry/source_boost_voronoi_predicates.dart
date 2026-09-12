import 'dart:typed_data';

import 'source_boost_voronoi_structures.dart';
import 'source_geometry.dart';

enum BoostOrientation2 { right, collinear, left }
enum BoostUlpResult2 { less, equal, more }

/// First exact predicate layer from Boost.Polygon 1.83
/// `detail/voronoi_predicates.hpp` for QIDI's int32 `coord_t` builder.
class BoostVoronoiPredicates2 {
  const BoostVoronoiPredicates2._();

  static const int ulps = 64;
  static const int ulpsX2 = 128;

  static bool isVerticalPoints(SourcePoint2 a, SourcePoint2 b) => a.x == b.x;
  static bool isVertical(BoostSiteEvent2 site) =>
      isVerticalPoints(site.point0, site.point1);

  /// Exact sign of Boost's robust cross product. For the orientation predicate
  /// only the sign is observable; Dart integers avoid the int64/uint64 overflow
  /// concerns that motivated Boost's floating conversion while preserving that
  /// sign exactly for QIDI int32 inputs.
  static int robustCrossProduct(int a1, int b1, int a2, int b2) =>
      a1 * b2 - b1 * a2;

  static BoostOrientation2 orientationValue(int value) {
    if (value == 0) return BoostOrientation2.collinear;
    return value < 0 ? BoostOrientation2.right : BoostOrientation2.left;
  }

  static BoostOrientation2 orientationVectors(
    int dx1,
    int dy1,
    int dx2,
    int dy2,
  ) =>
      orientationValue(robustCrossProduct(dx1, dy1, dx2, dy2));

  static BoostOrientation2 orientation(
    SourcePoint2 point1,
    SourcePoint2 point2,
    SourcePoint2 point3,
  ) {
    final dx1 = point1.x - point2.x;
    final dx2 = point2.x - point3.x;
    final dy1 = point1.y - point2.y;
    final dy2 = point2.y - point3.y;
    return orientationVectors(dx1, dy1, dx2, dy2);
  }

  static bool pointLess(SourcePoint2 lhs, SourcePoint2 rhs) =>
      lhs.x == rhs.x ? lhs.y < rhs.y : lhs.x < rhs.x;

  /// Boost `event_comparison_predicate(site, site)`.
  static bool siteLess(BoostSiteEvent2 lhs, BoostSiteEvent2 rhs) {
    if (lhs.x0 != rhs.x0) return lhs.x0 < rhs.x0;

    if (!lhs.isSegment) {
      if (!rhs.isSegment) return lhs.y0 < rhs.y0;
      if (isVertical(rhs)) return lhs.y0 <= rhs.y0;
      return true;
    }

    if (isVertical(rhs)) {
      if (isVertical(lhs)) return lhs.y0 < rhs.y0;
      return false;
    }
    if (isVertical(lhs)) return true;
    if (lhs.y0 != rhs.y0) return lhs.y0 < rhs.y0;
    return orientation(lhs.point1, lhs.point0, rhs.point1) ==
        BoostOrientation2.left;
  }

  static bool siteCircleLess(
    BoostSiteEvent2 lhs,
    BoostCircleEvent2 rhs,
  ) =>
      ulpCompare(lhs.x0.toDouble(), rhs.lowerX, ulps) ==
      BoostUlpResult2.less;

  static bool circleSiteLess(
    BoostCircleEvent2 lhs,
    BoostSiteEvent2 rhs,
  ) =>
      ulpCompare(lhs.lowerX, rhs.x0.toDouble(), ulps) ==
      BoostUlpResult2.less;

  static bool circleLess(
    BoostCircleEvent2 lhs,
    BoostCircleEvent2 rhs,
  ) {
    if (lhs.lowerX != rhs.lowerX) return lhs.lowerX < rhs.lowerX;
    return lhs.y < rhs.y;
  }

  /// Literal Boost 1.83 `ulp_comparison<fpt64>` ordering. Note that its mapped
  /// integer order is reversed, hence `llA > llB` returns LESS.
  static BoostUlpResult2 ulpCompare(double a, double b, int maxUlps) {
    var llA = _doubleBits(a);
    var llB = _doubleBits(b);
    const signBit = 0x8000000000000000;
    if (llA < signBit) llA = signBit - llA;
    if (llB < signBit) llB = signBit - llB;

    if (llA > llB) {
      return llA - llB <= maxUlps
          ? BoostUlpResult2.equal
          : BoostUlpResult2.less;
    }
    return llB - llA <= maxUlps
        ? BoostUlpResult2.equal
        : BoostUlpResult2.more;
  }

  static int _doubleBits(double value) {
    final data = ByteData(8)..setFloat64(0, value, Endian.host);
    return data.getUint64(0, Endian.host);
  }
}
