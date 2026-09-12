import 'dart:math' as math;

import 'source_boost_extended_numeric.dart';
import 'source_boost_robust_fpt.dart';
import 'source_boost_voronoi_predicates.dart';
import 'source_boost_voronoi_structures.dart';

/// Exact normalized `(point, segment, segment)` branch of Boost.Polygon 1.83
/// lazy + multiprecision circle formation.
class BoostPssCircleFormation2 {
  const BoostPssCircleFormation2();

  void form(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    int pointIndex,
    BoostCircleEvent2 circle,
  ) {
    final start1 = site2.point1;
    final end1 = site2.point0;
    final start2 = site3.point0;
    final end2 = site3.point1;
    final a1 = end1.x.toDouble() - start1.x.toDouble();
    final b1 = end1.y.toDouble() - start1.y.toDouble();
    final a2 = end2.x.toDouble() - start2.x.toDouble();
    final b2 = end2.y.toDouble() - start2.y.toDouble();

    final orientation = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        end1.y - start1.y,
        end1.x - start1.x,
        end2.y - start2.y,
        end2.x - start2.x,
      ),
      1,
    );

    late bool recomputeX;
    late bool recomputeY;
    late bool recomputeLowerX;

    if (orientation.fpv == 0) {
      final a = BoostRobustFpt2(a1 * a1 + b1 * b1, 2);
      final c = BoostRobustFpt2(
        BoostVoronoiPredicates2.robustCrossProduct(
          end1.y - start1.y,
          end1.x - start1.x,
          start2.y - start1.y,
          start2.x - start1.x,
        ),
        1,
      );
      final det = BoostRobustFpt2(
        BoostVoronoiPredicates2.robustCrossProduct(
              end1.x - start1.x,
              end1.y - start1.y,
              site1.x - start1.x,
              site1.y - start1.y,
            ) *
            BoostVoronoiPredicates2.robustCrossProduct(
              end1.y - start1.y,
              end1.x - start1.x,
              site1.y - start2.y,
              site1.x - start2.x,
            ),
        3,
      );

      final t = BoostRobustDif2()
        ..subtractValue(
          BoostRobustFpt2(a1) *
              BoostRobustFpt2(
                (start1.x.toDouble() + start2.x.toDouble()) * 0.5 -
                    site1.x.toDouble(),
              ),
        )
        ..subtractValue(
          BoostRobustFpt2(b1) *
              BoostRobustFpt2(
                (start1.y.toDouble() + start2.y.toDouble()) * 0.5 -
                    site1.y.toDouble(),
              ),
        );
      if (pointIndex == 2) {
        t.addValue(det.sqrt());
      } else {
        t.subtractValue(det.sqrt());
      }
      t.divideValue(a);

      final cx = BoostRobustDif2()
        ..addValue(BoostRobustFpt2(
          0.5 * (start1.x.toDouble() + start2.x.toDouble()),
        ))
        ..addDif(
          BoostRobustDif2.multiplyByValue(t, BoostRobustFpt2(a1)),
        );
      final cy = BoostRobustDif2()
        ..addValue(BoostRobustFpt2(
          0.5 * (start1.y.toDouble() + start2.y.toDouble()),
        ))
        ..addDif(
          BoostRobustDif2.multiplyByValue(t, BoostRobustFpt2(b1)),
        );
      final lowerX = cx.copy();
      final radiusX = BoostRobustDif2.fromValue(
        const BoostRobustFpt2(0.5) * c / a.sqrt(),
      );
      if (c.isNegative) {
        lowerX.subtractDif(radiusX);
      } else {
        lowerX.addDif(radiusX);
      }

      recomputeX = cx.difference.ulp > BoostVoronoiPredicates2.ulps;
      recomputeY = cy.difference.ulp > BoostVoronoiPredicates2.ulps;
      recomputeLowerX =
          lowerX.difference.ulp > BoostVoronoiPredicates2.ulps;
      circle
        ..setX(cx.difference.fpv)
        ..setY(cy.difference.fpv)
        ..setLowerX(lowerX.difference.fpv);
    } else {
      final length1 = BoostRobustFpt2(math.sqrt(a1 * a1 + b1 * b1), 2);
      final length2 = BoostRobustFpt2(math.sqrt(a2 * a2 + b2 * b2), 2);
      var a = BoostRobustFpt2(
        BoostVoronoiPredicates2.robustCrossProduct(
          end1.x - start1.x,
          end1.y - start1.y,
          start2.y - end2.y,
          end2.x - start2.x,
        ),
        1,
      );
      if (!a.isNegative) {
        a = a + length1 * length2;
      } else {
        a = (orientation * orientation) / (length1 * length2 - a);
      }

      final or1 = BoostRobustFpt2(
        BoostVoronoiPredicates2.robustCrossProduct(
          end1.y - start1.y,
          end1.x - start1.x,
          end1.y - site1.y,
          end1.x - site1.x,
        ),
        1,
      );
      final or2 = BoostRobustFpt2(
        BoostVoronoiPredicates2.robustCrossProduct(
          end2.x - start2.x,
          end2.y - start2.y,
          end2.x - site1.x,
          end2.y - site1.y,
        ),
        1,
      );
      final det = const BoostRobustFpt2(2) * a * or1 * or2;
      final c1 = BoostRobustFpt2(
        BoostVoronoiPredicates2.robustCrossProduct(
          end1.y - start1.y,
          end1.x - start1.x,
          end1.y,
          end1.x,
        ),
        1,
      );
      final c2 = BoostRobustFpt2(
        BoostVoronoiPredicates2.robustCrossProduct(
          end2.x - start2.x,
          end2.y - start2.y,
          end2.x,
          end2.y,
        ),
        1,
      );
      final inverseOrientation = const BoostRobustFpt2(1) / orientation;

      final ix = BoostRobustDif2()
        ..addValue(BoostRobustFpt2(a2) * c1 * inverseOrientation)
        ..addValue(BoostRobustFpt2(a1) * c2 * inverseOrientation);
      final iy = BoostRobustDif2()
        ..addValue(BoostRobustFpt2(b1) * c2 * inverseOrientation)
        ..addValue(BoostRobustFpt2(b2) * c1 * inverseOrientation);

      final b = BoostRobustDif2()
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            ix,
            BoostRobustFpt2(a1) * length2,
          ),
        )
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            ix,
            BoostRobustFpt2(a2) * length1,
          ),
        )
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            iy,
            BoostRobustFpt2(b1) * length2,
          ),
        )
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            iy,
            BoostRobustFpt2(b2) * length1,
          ),
        )
        ..subtractValue(
          length1 *
              BoostRobustFpt2(
                BoostVoronoiPredicates2.robustCrossProduct(
                  end2.x - start2.x,
                  end2.y - start2.y,
                  -site1.y,
                  site1.x,
                ),
                1,
              ),
        )
        ..subtractValue(
          length2 *
              BoostRobustFpt2(
                BoostVoronoiPredicates2.robustCrossProduct(
                  end1.x - start1.x,
                  end1.y - start1.y,
                  -site1.y,
                  site1.x,
                ),
                1,
              ),
        );

      var t = b.negated();
      if (pointIndex == 2) {
        t.addValue(det.sqrt());
      } else {
        t.subtractValue(det.sqrt());
      }
      t.divideValue(a * a);

      final cx = ix.copy()
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            t,
            BoostRobustFpt2(a1) * length2,
          ),
        )
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            t,
            BoostRobustFpt2(a2) * length1,
          ),
        );
      final cy = iy.copy()
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            t,
            BoostRobustFpt2(b1) * length2,
          ),
        )
        ..addDif(
          BoostRobustDif2.multiplyByValue(
            t,
            BoostRobustFpt2(b2) * length1,
          ),
        );

      if (t.positive.fpv < t.negative.fpv) t = t.negated();
      final lowerX = cx.copy();
      final orientationRadius =
          BoostRobustDif2.multiplyByValue(t, orientation);
      if (orientation.isNegative) {
        lowerX.subtractDif(orientationRadius);
      } else {
        lowerX.addDif(orientationRadius);
      }

      recomputeX = cx.difference.ulp > BoostVoronoiPredicates2.ulps;
      recomputeY = cy.difference.ulp > BoostVoronoiPredicates2.ulps;
      recomputeLowerX =
          lowerX.difference.ulp > BoostVoronoiPredicates2.ulps;
      circle
        ..setX(cx.difference.fpv)
        ..setY(cy.difference.fpv)
        ..setLowerX(lowerX.difference.fpv);
    }

    if (recomputeX || recomputeY || recomputeLowerX) {
      _exact(
        site1,
        site2,
        site3,
        pointIndex,
        circle,
        recomputeX: recomputeX,
        recomputeY: recomputeY,
        recomputeLowerX: recomputeLowerX,
      );
    }
  }

  void _exact(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    int pointIndex,
    BoostCircleEvent2 circle, {
    required bool recomputeX,
    required bool recomputeY,
    required bool recomputeLowerX,
  }) {
    final start1 = site2.point1;
    final end1 = site2.point0;
    final start2 = site3.point0;
    final end2 = site3.point1;
    final a = <BigInt>[
      BigInt.from(end1.x - start1.x),
      BigInt.from(end2.x - start2.x),
    ];
    final b = <BigInt>[
      BigInt.from(end1.y - start1.y),
      BigInt.from(end2.y - start2.y),
    ];
    final c = List<BigInt>.filled(2, BigInt.zero);
    final cA = List<BigInt>.filled(4, BigInt.zero);
    final cB = List<BigInt>.filled(4, BigInt.zero);
    final orientation = a[1] * b[0] - a[0] * b[1];
    final sqrtExpr = BoostRobustSqrtExpr2();

    if (orientation == BigInt.zero) {
      final denominator = 2.0 *
          BoostBigIntConverter2.toDouble(a[0] * a[0] + b[0] * b[0]);
      c[0] = b[0] * BigInt.from(start2.x - start1.x) -
          a[0] * BigInt.from(start2.y - start1.y);
      final dx = a[0] * BigInt.from(site1.y - start1.y) -
          b[0] * BigInt.from(site1.x - start1.x);
      final dy = b[0] * BigInt.from(site1.x - start2.x) -
          a[0] * BigInt.from(site1.y - start2.y);
      cB[0] = dx * dy;
      cB[1] = BigInt.one;

      if (recomputeY) {
        cA[0] = b[0] * BigInt.from(pointIndex == 2 ? 2 : -2);
        cA[1] = a[0] * a[0] * BigInt.from(start1.y + start2.y) -
            a[0] * b[0] *
                BigInt.from(start1.x + start2.x - site1.x * 2) +
            b[0] * b[0] * BigInt.from(site1.y * 2);
        circle.setY(sqrtExpr.eval2(cA, cB).toDouble() / denominator);
      }

      if (recomputeX || recomputeLowerX) {
        cA[0] = a[0] * BigInt.from(pointIndex == 2 ? 2 : -2);
        cA[1] = b[0] * b[0] * BigInt.from(start1.x + start2.x) -
            a[0] * b[0] *
                BigInt.from(start1.y + start2.y - site1.y * 2) +
            a[0] * a[0] * BigInt.from(site1.x * 2);
        if (recomputeX) {
          circle.setX(sqrtExpr.eval2(cA, cB).toDouble() / denominator);
        }
        if (recomputeLowerX) {
          cA[2] = c[0].abs();
          cB[2] = a[0] * a[0] + b[0] * b[0];
          circle.setLowerX(
            sqrtExpr.eval3(cA, cB).toDouble() / denominator,
          );
        }
      }
      return;
    }

    c[0] = b[0] * BigInt.from(end1.x) - a[0] * BigInt.from(end1.y);
    c[1] = a[1] * BigInt.from(end2.y) - b[1] * BigInt.from(end2.x);
    final ix = a[0] * c[1] + a[1] * c[0];
    final iy = b[0] * c[1] + b[1] * c[0];
    final dx = ix - orientation * BigInt.from(site1.x);
    final dy = iy - orientation * BigInt.from(site1.y);

    if (dx == BigInt.zero && dy == BigInt.zero) {
      final denominator = BoostBigIntConverter2.toDouble(orientation);
      final cx = BoostBigIntConverter2.toDouble(ix) / denominator;
      final cy = BoostBigIntConverter2.toDouble(iy) / denominator;
      circle
        ..setX(cx)
        ..setY(cy)
        ..setLowerX(cx);
      return;
    }

    final sign = BigInt.from(
      (pointIndex == 2 ? 1 : -1) * (orientation.isNegative ? 1 : -1),
    );
    cA[0] = a[1] * -dx + b[1] * -dy;
    cA[1] = a[0] * -dx + b[0] * -dy;
    cA[2] = sign;
    cA[3] = BigInt.zero;
    cB[0] = a[0] * a[0] + b[0] * b[0];
    cB[1] = a[1] * a[1] + b[1] * b[1];
    cB[2] = a[0] * a[1] + b[0] * b[1];
    cB[3] = (a[0] * dy - b[0] * dx) *
        (a[1] * dy - b[1] * dx) *
        BigInt.from(-2);

    final temp = _sqrtExprPss4(cA, cB);
    final denominator =
        temp.toDouble() * BoostBigIntConverter2.toDouble(orientation);
    final distanceSquared = dx * dx + dy * dy;

    if (recomputeY) {
      cA[0] = b[1] * distanceSquared -
          iy * (dx * a[1] + dy * b[1]);
      cA[1] = b[0] * distanceSquared -
          iy * (dx * a[0] + dy * b[0]);
      cA[2] = iy * sign;
      circle.setY(_sqrtExprPss4(cA, cB).toDouble() / denominator);
    }

    if (recomputeX || recomputeLowerX) {
      cA[0] = a[1] * distanceSquared -
          ix * (dx * a[1] + dy * b[1]);
      cA[1] = a[0] * distanceSquared -
          ix * (dx * a[0] + dy * b[0]);
      cA[2] = ix * sign;
      if (recomputeX) {
        circle.setX(_sqrtExprPss4(cA, cB).toDouble() / denominator);
      }
      if (recomputeLowerX) {
        cA[3] = orientation *
            distanceSquared *
            BigInt.from(temp.isNegative ? -1 : 1);
        circle.setLowerX(
          _sqrtExprPss4(cA, cB).toDouble() / denominator,
        );
      }
    }
  }

  BoostExtendedExponentFpt2 _sqrtExprPss4(
    List<BigInt> a,
    List<BigInt> b,
  ) {
    final sqrtExpr = BoostRobustSqrtExpr2();
    if (a[3] == BigInt.zero) {
      final left = sqrtExpr.eval2(a, b);
      final cA = <BigInt>[BigInt.one, b[2]];
      final cB = <BigInt>[b[0] * b[1], BigInt.one];
      final right = sqrtExpr.eval1([a[2]], [b[3]]) *
          sqrtExpr.eval2(cA, cB).sqrt();
      if (_sameSign(left, right)) return left + right;

      final nA = <BigInt>[
        a[0] * a[0] * b[0] +
            a[1] * a[1] * b[1] -
            a[2] * a[2] * b[3] * b[2],
        a[0] * a[1] * BigInt.two - a[2] * a[2] * b[3],
      ];
      final nB = <BigInt>[BigInt.one, b[0] * b[1]];
      return sqrtExpr.eval2(nA, nB) / (left - right);
    }

    var cA = <BigInt>[BigInt.one, b[2]];
    var cB = <BigInt>[b[0] * b[1], BigInt.one];
    final right = sqrtExpr.eval1([a[2]], [b[3]]) *
        sqrtExpr.eval2(cA, cB).sqrt();
    cA = <BigInt>[a[0], a[1], a[3]];
    cB = <BigInt>[b[0], b[1], BigInt.one];
    final left = sqrtExpr.eval3(cA, cB);
    if (_sameSign(left, right)) return left + right;

    cA = <BigInt>[
      a[3] * a[0] * BigInt.two,
      a[3] * a[1] * BigInt.two,
      a[0] * a[0] * b[0] +
          a[1] * a[1] * b[1] +
          a[3] * a[3] -
          a[2] * a[2] * b[2] * b[3],
      a[0] * a[1] * BigInt.two - a[2] * a[2] * b[3],
    ];
    cB = <BigInt>[
      b[0],
      b[1],
      BigInt.one,
      b[0] * b[1],
    ];
    return _sqrtExprPss3(cA, cB) / (left - right);
  }

  BoostExtendedExponentFpt2 _sqrtExprPss3(
    List<BigInt> a,
    List<BigInt> b,
  ) {
    final sqrtExpr = BoostRobustSqrtExpr2();
    final left = sqrtExpr.eval2(a, b);
    final right = sqrtExpr.eval2(
      [a[2], a[3]],
      [b[2], b[3]],
    );
    if (_sameSign(left, right)) return left + right;

    final cA = <BigInt>[
      a[0] * a[0] * b[0] +
          a[1] * a[1] * b[1] -
          a[2] * a[2] -
          a[3] * a[3] * b[0] * b[1],
      (a[0] * a[1] - a[2] * a[3]) * BigInt.two,
    ];
    final cB = <BigInt>[BigInt.one, b[3]];
    return sqrtExpr.eval2(cA, cB) / (left - right);
  }

  bool _sameSign(
    BoostExtendedExponentFpt2 a,
    BoostExtendedExponentFpt2 b,
  ) =>
      (!a.isNegative && !b.isNegative) ||
      (!a.isPositive && !b.isPositive);
}
