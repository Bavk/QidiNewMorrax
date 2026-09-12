import 'dart:math' as math;
import 'dart:typed_data';

import 'source_boost_voronoi_structures.dart';
import 'source_geometry.dart';

enum BoostOrientation2 { right, collinear, left }
enum BoostUlpResult2 { less, equal, more }
enum _BoostFastDistanceResult2 { less, undefined, more }

class _ComparisonY2 {
  const _ComparisonY2(this.y, this.direction);
  final int y;
  final int direction;
}

/// Predicate layer from Boost.Polygon 1.83
/// `detail/voronoi_predicates.hpp` for QIDI's int32 `coord_t` builder.
///
/// This file intentionally retains Boost's uint64 wraparound in
/// `robust_cross_product`, its ULP comparator direction, and the experimentally
/// chosen beach-line node tie-breakers rather than replacing them with cleaner
/// mathematical comparisons.
class BoostVoronoiPredicates2 {
  const BoostVoronoiPredicates2._();

  static const int ulps = 64;
  static const int ulpsX2 = 128;
  static final BigInt _uint64Mask = (BigInt.one << 64) - BigInt.one;

  static bool isVerticalPoints(SourcePoint2 a, SourcePoint2 b) => a.x == b.x;
  static bool isVertical(BoostSiteEvent2 site) =>
      isVerticalPoints(site.point0, site.point1);

  /// Literal arithmetic shape of Boost 1.83 `robust_cross_product`.
  ///
  /// Boost performs these products and sums in `uint64_t`. Dart native `int`
  /// is signed 64-bit, so values crossing bit 63 must be represented with
  /// [BigInt] here before applying modulo 2^64.
  static double robustCrossProduct(
    int a1Signed,
    int b1Signed,
    int a2Signed,
    int b2Signed,
  ) {
    final a1 = BigInt.from(a1Signed).abs();
    final b1 = BigInt.from(b1Signed).abs();
    final a2 = BigInt.from(a2Signed).abs();
    final b2 = BigInt.from(b2Signed).abs();

    final l = (a1 * b2) & _uint64Mask;
    final r = (b1 * a2) & _uint64Mask;
    final lhsNegative = (a1Signed < 0) != (b2Signed < 0);
    final rhsNegative = (a2Signed < 0) != (b1Signed < 0);

    if (lhsNegative) {
      if (rhsNegative) {
        return l > r ? -(l - r).toDouble() : (r - l).toDouble();
      }
      return -((l + r) & _uint64Mask).toDouble();
    }
    if (rhsNegative) {
      return ((l + r) & _uint64Mask).toDouble();
    }
    return l < r ? -(r - l).toDouble() : (l - r).toDouble();
  }

  static BoostOrientation2 orientationValue(num value) {
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

  static bool distanceLess(
    BoostSiteEvent2 leftSite,
    BoostSiteEvent2 rightSite,
    SourcePoint2 newPoint,
  ) {
    if (!leftSite.isSegment) {
      return !rightSite.isSegment
          ? _pointPointDistance(leftSite, rightSite, newPoint)
          : _pointSegmentDistance(
              leftSite,
              rightSite,
              newPoint,
              false,
            );
    }
    return !rightSite.isSegment
        ? _pointSegmentDistance(rightSite, leftSite, newPoint, true)
        : _segmentSegmentDistance(leftSite, rightSite, newPoint);
  }

  static bool nodeLess(
    BoostBeachLineNodeKey2 node1,
    BoostBeachLineNodeKey2 node2,
  ) {
    final site1 = _comparisonSite(node1);
    final site2 = _comparisonSite(node2);
    final point1 = _comparisonPoint(site1);
    final point2 = _comparisonPoint(site2);

    if (point1.x < point2.x) {
      return distanceLess(node1.leftSite, node1.rightSite, point2);
    }
    if (point1.x > point2.x) {
      return !distanceLess(node2.leftSite, node2.rightSite, point1);
    }

    if (site1.sortedIndex == site2.sortedIndex) {
      return _comparisonYLess(_comparisonY(node1), _comparisonY(node2));
    }
    if (site1.sortedIndex < site2.sortedIndex) {
      final y1 = _comparisonY(node1, isNewNode: false);
      final y2 = _comparisonY(node2, isNewNode: true);
      if (y1.y != y2.y) return y1.y < y2.y;
      return !site1.isSegment ? y1.direction < 0 : false;
    }

    final y1 = _comparisonY(node1, isNewNode: true);
    final y2 = _comparisonY(node2, isNewNode: false);
    if (y1.y != y2.y) return y1.y < y2.y;
    return !site2.isSegment ? y2.direction > 0 : true;
  }

  static bool circleExistsPpp(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
  ) =>
      orientation(site1.point0, site2.point0, site3.point0) ==
      BoostOrientation2.right;

  static bool circleExistsPps(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    int segmentIndex,
  ) {
    if (segmentIndex != 2) {
      final orient1 = orientation(site1.point0, site2.point0, site3.point0);
      final orient2 = orientation(site1.point0, site2.point0, site3.point1);
      if (segmentIndex == 1 && site1.x0 >= site2.x0) {
        if (orient1 != BoostOrientation2.right) return false;
      } else if (segmentIndex == 3 && site2.x0 >= site1.x0) {
        if (orient2 != BoostOrientation2.right) return false;
      } else if (orient1 != BoostOrientation2.right &&
          orient2 != BoostOrientation2.right) {
        return false;
      }
    } else {
      return site3.point0 != site1.point0 || site3.point1 != site2.point0;
    }
    return true;
  }

  static bool circleExistsPss(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    int pointIndex,
  ) {
    if (site2.sortedIndex == site3.sortedIndex) return false;
    if (pointIndex == 2) {
      if (!site2.isInverse && site3.isInverse) return false;
      if (site2.isInverse == site3.isInverse &&
          orientation(site2.point0, site1.point0, site3.point1) !=
              BoostOrientation2.right) {
        return false;
      }
    }
    return true;
  }

  static bool circleExistsSss(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
  ) =>
      site1.sortedIndex != site2.sortedIndex &&
      site2.sortedIndex != site3.sortedIndex;

  static bool _pointPointDistance(
    BoostSiteEvent2 leftSite,
    BoostSiteEvent2 rightSite,
    SourcePoint2 newPoint,
  ) {
    final leftPoint = leftSite.point0;
    final rightPoint = rightSite.point0;
    if (leftPoint.x > rightPoint.x) {
      if (newPoint.y <= leftPoint.y) return false;
    } else if (leftPoint.x < rightPoint.x) {
      if (newPoint.y >= rightPoint.y) return true;
    } else {
      return leftPoint.y + rightPoint.y < newPoint.y * 2;
    }

    final dist1 = _distanceToPointArc(leftSite, newPoint);
    final dist2 = _distanceToPointArc(rightSite, newPoint);
    return dist1 < dist2;
  }

  static bool _pointSegmentDistance(
    BoostSiteEvent2 leftSite,
    BoostSiteEvent2 rightSite,
    SourcePoint2 newPoint,
    bool reverseOrder,
  ) {
    final fast = _fastPointSegment(
      leftSite,
      rightSite,
      newPoint,
      reverseOrder,
    );
    if (fast != _BoostFastDistanceResult2.undefined) {
      return fast == _BoostFastDistanceResult2.less;
    }

    final dist1 = _distanceToPointArc(leftSite, newPoint);
    final dist2 = _distanceToSegmentArc(rightSite, newPoint);
    return reverseOrder != (dist1 < dist2);
  }

  static bool _segmentSegmentDistance(
    BoostSiteEvent2 leftSite,
    BoostSiteEvent2 rightSite,
    SourcePoint2 newPoint,
  ) {
    if (leftSite.sortedIndex == rightSite.sortedIndex) {
      return orientation(leftSite.point0, leftSite.point1, newPoint) ==
          BoostOrientation2.left;
    }
    final dist1 = _distanceToSegmentArc(leftSite, newPoint);
    final dist2 = _distanceToSegmentArc(rightSite, newPoint);
    return dist1 < dist2;
  }

  static double _distanceToPointArc(
    BoostSiteEvent2 site,
    SourcePoint2 point,
  ) {
    final dx = site.x.toDouble() - point.x.toDouble();
    final dy = site.y.toDouble() - point.y.toDouble();
    return (dx * dx + dy * dy) / (2.0 * dx);
  }

  static double _distanceToSegmentArc(
    BoostSiteEvent2 site,
    SourcePoint2 point,
  ) {
    if (isVertical(site)) {
      return (site.x.toDouble() - point.x.toDouble()) * 0.5;
    }
    final segment0 = site.point0;
    final segment1 = site.point1;
    final a1 = segment1.x.toDouble() - segment0.x.toDouble();
    final b1 = segment1.y.toDouble() - segment0.y.toDouble();
    var k = math.sqrt(a1 * a1 + b1 * b1);
    if (b1 >= 0) {
      k = 1.0 / (b1 + k);
    } else {
      k = (k - b1) / (a1 * a1);
    }
    return k *
        robustCrossProduct(
          segment1.x - segment0.x,
          segment1.y - segment0.y,
          point.x - segment0.x,
          point.y - segment0.y,
        );
  }

  static _BoostFastDistanceResult2 _fastPointSegment(
    BoostSiteEvent2 leftSite,
    BoostSiteEvent2 rightSite,
    SourcePoint2 newPoint,
    bool reverseOrder,
  ) {
    final sitePoint = leftSite.point0;
    final segmentStart = rightSite.point0;
    final segmentEnd = rightSite.point1;

    if (orientation(segmentStart, segmentEnd, newPoint) !=
        BoostOrientation2.right) {
      return !rightSite.isInverse
          ? _BoostFastDistanceResult2.less
          : _BoostFastDistanceResult2.more;
    }

    final difX = newPoint.x.toDouble() - sitePoint.x.toDouble();
    final difY = newPoint.y.toDouble() - sitePoint.y.toDouble();
    final a = segmentEnd.x.toDouble() - segmentStart.x.toDouble();
    final b = segmentEnd.y.toDouble() - segmentStart.y.toDouble();

    if (isVertical(rightSite)) {
      if (newPoint.y < sitePoint.y && !reverseOrder) {
        return _BoostFastDistanceResult2.more;
      }
      if (newPoint.y > sitePoint.y && reverseOrder) {
        return _BoostFastDistanceResult2.less;
      }
      return _BoostFastDistanceResult2.undefined;
    }

    final orient = orientationVectors(
      segmentEnd.x - segmentStart.x,
      segmentEnd.y - segmentStart.y,
      newPoint.x - sitePoint.x,
      newPoint.y - sitePoint.y,
    );
    if (orient == BoostOrientation2.left) {
      if (!rightSite.isInverse) {
        return reverseOrder
            ? _BoostFastDistanceResult2.less
            : _BoostFastDistanceResult2.undefined;
      }
      return reverseOrder
          ? _BoostFastDistanceResult2.undefined
          : _BoostFastDistanceResult2.more;
    }

    final fastLeftExpr = a * (difY + difX) * (difY - difX);
    final fastRightExpr = (2.0 * b) * difX * difY;
    final exprCmp = ulpCompare(fastLeftExpr, fastRightExpr, 4);
    if (exprCmp != BoostUlpResult2.equal) {
      if ((exprCmp == BoostUlpResult2.more) != reverseOrder) {
        return reverseOrder
            ? _BoostFastDistanceResult2.less
            : _BoostFastDistanceResult2.more;
      }
      return _BoostFastDistanceResult2.undefined;
    }
    return _BoostFastDistanceResult2.undefined;
  }

  static BoostSiteEvent2 _comparisonSite(BoostBeachLineNodeKey2 node) =>
      node.leftSite.sortedIndex > node.rightSite.sortedIndex
          ? node.leftSite
          : node.rightSite;

  static SourcePoint2 _comparisonPoint(BoostSiteEvent2 site) =>
      pointLess(site.point0, site.point1) ? site.point0 : site.point1;

  static _ComparisonY2 _comparisonY(
    BoostBeachLineNodeKey2 node, {
    bool isNewNode = true,
  }) {
    if (node.leftSite.sortedIndex == node.rightSite.sortedIndex) {
      return _ComparisonY2(node.leftSite.y0, 0);
    }
    if (node.leftSite.sortedIndex > node.rightSite.sortedIndex) {
      if (!isNewNode &&
          node.leftSite.isSegment &&
          isVertical(node.leftSite)) {
        return _ComparisonY2(node.leftSite.y0, 1);
      }
      return _ComparisonY2(node.leftSite.y1, 1);
    }
    return _ComparisonY2(node.rightSite.y0, -1);
  }

  static bool _comparisonYLess(_ComparisonY2 a, _ComparisonY2 b) =>
      a.y == b.y ? a.direction < b.direction : a.y < b.y;

  static BoostUlpResult2 ulpCompare(double a, double b, int maxUlps) {
    var llA = _doubleBits(a);
    var llB = _doubleBits(b);
    final signBit = BigInt.one << 63;
    if (llA < signBit) llA = signBit - llA;
    if (llB < signBit) llB = signBit - llB;

    final max = BigInt.from(maxUlps);
    if (llA > llB) {
      return llA - llB <= max ? BoostUlpResult2.equal : BoostUlpResult2.less;
    }
    return llB - llA <= max ? BoostUlpResult2.equal : BoostUlpResult2.more;
  }

  static BigInt _doubleBits(double value) {
    final data = ByteData(8)..setFloat64(0, value, Endian.big);
    final high = BigInt.from(data.getUint32(0, Endian.big));
    final low = BigInt.from(data.getUint32(4, Endian.big));
    return (high << 32) | low;
  }
}
