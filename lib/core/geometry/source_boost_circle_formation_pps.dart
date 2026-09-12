import 'dart:math' as math;

import 'source_boost_extended_numeric.dart';
import 'source_boost_robust_fpt.dart';
import 'source_boost_voronoi_predicates.dart';
import 'source_boost_voronoi_structures.dart';

/// Exact normalized `(point, point, segment)` branch of Boost.Polygon 1.83
/// `lazy_circle_formation_functor::pps()` plus the multiprecision fallback.
/// [segmentIndex] retains the original position of the segment (1, 2 or 3)
/// before `circle_formation_predicate` reordered the sites.
class BoostPpsCircleFormation2 {
  const BoostPpsCircleFormation2();

  void form(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    int segmentIndex,
    BoostCircleEvent2 circle,
  ) {
    final lineA = site3.y1.toDouble() - site3.y0.toDouble();
    final lineB = site3.x0.toDouble() - site3.x1.toDouble();
    final vecX = site2.y.toDouble() - site1.y.toDouble();
    final vecY = site1.x.toDouble() - site2.x.toDouble();

    final teta = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site3.y1 - site3.y0,
        site3.x0 - site3.x1,
        site2.x - site1.x,
        site2.y - site1.y,
      ),
      1,
    );
    final a = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site3.y0 - site3.y1,
        site3.x0 - site3.x1,
        site3.y1 - site1.y,
        site3.x1 - site1.x,
      ),
      1,
    );
    final b = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site3.y0 - site3.y1,
        site3.x0 - site3.x1,
        site3.y1 - site2.y,
        site3.x1 - site2.x,
      ),
      1,
    );
    final denom = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site1.y - site2.y,
        site1.x - site2.x,
        site3.y1 - site3.y0,
        site3.x1 - site3.x0,
      ),
      1,
    );
    final invSegmentLength = BoostRobustFpt2(
      1.0 / math.sqrt(lineA * lineA + lineB * lineB),
      3,
    );

    final t = BoostRobustDif2();
    if (denom.fpv == 0) {
      t.addValue(
        teta /
            (const BoostRobustFpt2(8) * a),
      );
      t.subtractValue(
        a /
            (const BoostRobustFpt2(2) * teta),
      );
    } else {
      final det = ((teta * teta + denom * denom) * a * b).sqrt();
      final denomSquared = denom * denom;
      final detTerm = det / denomSquared;
      if (segmentIndex == 2) {
        t.subtractValue(detTerm);
      } else {
        t.addValue(detTerm);
      }
      t.addValue(
        teta * (a + b) /
            (const BoostRobustFpt2(2) * denomSquared),
      );
    }

    final cx = BoostRobustDif2()
      ..addValue(BoostRobustFpt2(
        0.5 * (site1.x.toDouble() + site2.x.toDouble()),
      ))
      ..addDif(
        BoostRobustDif2.multiplyByValue(
          t,
          BoostRobustFpt2(vecX),
        ),
      );
    final cy = BoostRobustDif2()
      ..addValue(BoostRobustFpt2(
        0.5 * (site1.y.toDouble() + site2.y.toDouble()),
      ))
      ..addDif(
        BoostRobustDif2.multiplyByValue(
          t,
          BoostRobustFpt2(vecY),
        ),
      );

    var r = BoostRobustDif2()
      ..subtractValue(
        BoostRobustFpt2(lineA) * BoostRobustFpt2(site3.x0.toDouble()),
      )
      ..subtractValue(
        BoostRobustFpt2(lineB) * BoostRobustFpt2(site3.y0.toDouble()),
      )
      ..addDif(
        BoostRobustDif2.multiplyByValue(cx, BoostRobustFpt2(lineA)),
      )
      ..addDif(
        BoostRobustDif2.multiplyByValue(cy, BoostRobustFpt2(lineB)),
      );
    if (r.positive.fpv < r.negative.fpv) r = r.negated();

    final lowerX = cx.copy()
      ..addDif(
        BoostRobustDif2.multiplyByValue(r, invSegmentLength),
      );

    circle
      ..setX(cx.difference.fpv)
      ..setY(cy.difference.fpv)
      ..setLowerX(lowerX.difference.fpv);

    final recomputeX = cx.difference.ulp > BoostVoronoiPredicates2.ulps;
    final recomputeY = cy.difference.ulp > BoostVoronoiPredicates2.ulps;
    final recomputeLowerX =
        lowerX.difference.ulp > BoostVoronoiPredicates2.ulps;
    if (recomputeX || recomputeY || recomputeLowerX) {
      _exact(
        site1,
        site2,
        site3,
        segmentIndex,
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
    int segmentIndex,
    BoostCircleEvent2 circle, {
    required bool recomputeX,
    required bool recomputeY,
    required bool recomputeLowerX,
  }) {
    final lineA = BigInt.from(site3.y1 - site3.y0);
    final lineB = BigInt.from(site3.x0 - site3.x1);
    final segmentLength = lineA * lineA + lineB * lineB;
    final vecX = BigInt.from(site2.y - site1.y);
    final vecY = BigInt.from(site1.x - site2.x);
    final sumX = BigInt.from(site1.x + site2.x);
    final sumY = BigInt.from(site1.y + site2.y);
    final teta = lineA * vecX + lineB * vecY;
    var denom = vecX * lineB - vecY * lineA;

    var dif0 = BigInt.from(site3.y1 - site1.y);
    var dif1 = BigInt.from(site1.x - site3.x1);
    final a = lineA * dif1 - lineB * dif0;
    dif0 = BigInt.from(site3.y1 - site2.y);
    dif1 = BigInt.from(site2.x - site3.x1);
    final b = lineA * dif1 - lineB * dif0;
    final sumAB = a + b;

    final sqrtExpr = BoostRobustSqrtExpr2();
    final cA = List<BigInt>.filled(4, BigInt.zero);
    final cB = List<BigInt>.filled(4, BigInt.zero);

    if (denom == BigInt.zero) {
      final numerator = teta * teta - sumAB * sumAB;
      denom = teta * sumAB;
      cA[0] = denom * sumX * BigInt.two + numerator * vecX;
      cB[0] = segmentLength;
      cA[1] = denom * sumAB * BigInt.two + numerator * teta;
      cB[1] = BigInt.one;
      cA[2] = denom * sumY * BigInt.two + numerator * vecY;
      final inverseDenom = 1.0 / BoostBigIntConverter2.toDouble(denom);

      if (recomputeX) {
        circle.setX(
          0.25 * BoostBigIntConverter2.toDouble(cA[0]) * inverseDenom,
        );
      }
      if (recomputeY) {
        circle.setY(
          0.25 * BoostBigIntConverter2.toDouble(cA[2]) * inverseDenom,
        );
      }
      if (recomputeLowerX) {
        circle.setLowerX(
          0.25 *
              sqrtExpr.eval2(cA, cB).toDouble() *
              inverseDenom /
              math.sqrt(BoostBigIntConverter2.toDouble(segmentLength)),
        );
      }
      return;
    }

    final det =
        (teta * teta + denom * denom) * a * b * BigInt.from(4);
    var inverseDenomSquared = 1.0 / BoostBigIntConverter2.toDouble(denom);
    inverseDenomSquared *= inverseDenomSquared;

    if (recomputeX || recomputeLowerX) {
      cA[0] = sumX * denom * denom + teta * sumAB * vecX;
      cB[0] = BigInt.one;
      cA[1] = segmentIndex == 2 ? -vecX : vecX;
      cB[1] = det;
      if (recomputeX) {
        circle.setX(
          0.5 * sqrtExpr.eval2(cA, cB).toDouble() * inverseDenomSquared,
        );
      }
    }

    if (recomputeY || recomputeLowerX) {
      cA[2] = sumY * denom * denom + teta * sumAB * vecY;
      cB[2] = BigInt.one;
      cA[3] = segmentIndex == 2 ? -vecY : vecY;
      cB[3] = det;
      if (recomputeY) {
        final a2 = [cA[2], cA[3]];
        final b2 = [cB[2], cB[3]];
        circle.setY(
          0.5 * sqrtExpr.eval2(a2, b2).toDouble() * inverseDenomSquared,
        );
      }
    }

    if (recomputeLowerX) {
      cB[0] *= segmentLength;
      cB[1] *= segmentLength;
      cA[2] = sumAB * (denom * denom + teta * teta);
      cB[2] = BigInt.one;
      cA[3] = segmentIndex == 2 ? -teta : teta;
      cB[3] = det;
      circle.setLowerX(
        0.5 *
            sqrtExpr.eval4(cA, cB).toDouble() *
            inverseDenomSquared /
            math.sqrt(BoostBigIntConverter2.toDouble(segmentLength)),
      );
    }
  }
}
