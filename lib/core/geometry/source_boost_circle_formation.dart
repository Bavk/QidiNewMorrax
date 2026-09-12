import 'dart:math' as math;

import 'source_boost_circle_formation_pps.dart';
import 'source_boost_circle_formation_pss.dart';
import 'source_boost_circle_formation_sss.dart';
import 'source_boost_extended_numeric.dart';
import 'source_boost_robust_fpt.dart';
import 'source_boost_voronoi_predicates.dart';
import 'source_boost_voronoi_structures.dart';

/// Boost.Polygon 1.83 `circle_formation_predicate` plus its lazy and selective
/// multiprecision circle-formation functors for PPP/PPS/PSS/SSS.
class BoostCircleFormation2 {
  const BoostCircleFormation2();

  bool tryForm(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    BoostCircleEvent2 circle,
  ) {
    if (!site1.isSegment) {
      if (!site2.isSegment) {
        if (!site3.isSegment) {
          if (!BoostVoronoiPredicates2.circleExistsPpp(site1, site2, site3)) {
            return false;
          }
          _lazyPpp(site1, site2, site3, circle);
        } else {
          if (!BoostVoronoiPredicates2.circleExistsPps(
            site1,
            site2,
            site3,
            3,
          )) {
            return false;
          }
          const BoostPpsCircleFormation2().form(
            site1,
            site2,
            site3,
            3,
            circle,
          );
        }
      } else if (!site3.isSegment) {
        if (!BoostVoronoiPredicates2.circleExistsPps(
          site1,
          site3,
          site2,
          2,
        )) {
          return false;
        }
        const BoostPpsCircleFormation2().form(
          site1,
          site3,
          site2,
          2,
          circle,
        );
      } else {
        if (!BoostVoronoiPredicates2.circleExistsPss(
          site1,
          site2,
          site3,
          1,
        )) {
          return false;
        }
        const BoostPssCircleFormation2().form(
          site1,
          site2,
          site3,
          1,
          circle,
        );
      }
    } else if (!site2.isSegment) {
      if (!site3.isSegment) {
        if (!BoostVoronoiPredicates2.circleExistsPps(
          site2,
          site3,
          site1,
          1,
        )) {
          return false;
        }
        const BoostPpsCircleFormation2().form(
          site2,
          site3,
          site1,
          1,
          circle,
        );
      } else {
        // Boost source: pss(site2, site1, site3, 2). The two segment sites
        // must retain their original left/right order here.
        if (!BoostVoronoiPredicates2.circleExistsPss(
          site2,
          site1,
          site3,
          2,
        )) {
          return false;
        }
        const BoostPssCircleFormation2().form(
          site2,
          site1,
          site3,
          2,
          circle,
        );
      }
    } else if (!site3.isSegment) {
      if (!BoostVoronoiPredicates2.circleExistsPss(
        site3,
        site1,
        site2,
        3,
      )) {
        return false;
      }
      const BoostPssCircleFormation2().form(
        site3,
        site1,
        site2,
        3,
        circle,
      );
    } else {
      if (!BoostVoronoiPredicates2.circleExistsSss(site1, site2, site3)) {
        return false;
      }
      const BoostSssCircleFormation2().form(site1, site2, site3, circle);
    }

    if (_liesOutsideVerticalSegment(circle, site1) ||
        _liesOutsideVerticalSegment(circle, site2) ||
        _liesOutsideVerticalSegment(circle, site3)) {
      return false;
    }
    return true;
  }

  bool _liesOutsideVerticalSegment(
    BoostCircleEvent2 circle,
    BoostSiteEvent2 site,
  ) {
    if (!site.isSegment || !BoostVoronoiPredicates2.isVertical(site)) {
      return false;
    }
    final y0 = (site.isInverse ? site.y1 : site.y0).toDouble();
    final y1 = (site.isInverse ? site.y0 : site.y1).toDouble();
    return BoostVoronoiPredicates2.ulpCompare(
              circle.y,
              y0,
              BoostVoronoiPredicates2.ulps,
            ) ==
            BoostUlpResult2.less ||
        BoostVoronoiPredicates2.ulpCompare(
              circle.y,
              y1,
              BoostVoronoiPredicates2.ulps,
            ) ==
            BoostUlpResult2.more;
  }

  void _lazyPpp(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    BoostCircleEvent2 circle,
  ) {
    final difX1 = site1.x.toDouble() - site2.x.toDouble();
    final difX2 = site2.x.toDouble() - site3.x.toDouble();
    final difY1 = site1.y.toDouble() - site2.y.toDouble();
    final difY2 = site2.y.toDouble() - site3.y.toDouble();

    // Boost: robust_cross_product(dif_x1, dif_y1, dif_x2, dif_y2).
    // Keeping the x/y pairs in this exact order is observable at int32
    // extremes and determines whether a circle event exists later in sweep.
    final orientation = BoostVoronoiPredicates2.robustCrossProduct(
      site1.x - site2.x,
      site1.y - site2.y,
      site2.x - site3.x,
      site2.y - site3.y,
    );
    final invOrientation = BoostRobustFpt2(0.5 / orientation, 2);

    final sumX1 = site1.x.toDouble() + site2.x.toDouble();
    final sumX2 = site2.x.toDouble() + site3.x.toDouble();
    final sumY1 = site1.y.toDouble() + site2.y.toDouble();
    final sumY2 = site2.y.toDouble() + site3.y.toDouble();
    final difX3 = site1.x.toDouble() - site3.x.toDouble();
    final difY3 = site1.y.toDouble() - site3.y.toDouble();

    final cx = BoostRobustDif2()
      ..addValue(BoostRobustFpt2(difX1 * sumX1 * difY2, 2))
      ..addValue(BoostRobustFpt2(difY1 * sumY1 * difY2, 2))
      ..subtractValue(BoostRobustFpt2(difX2 * sumX2 * difY1, 2))
      ..subtractValue(BoostRobustFpt2(difY2 * sumY2 * difY1, 2));

    final cy = BoostRobustDif2()
      ..addValue(BoostRobustFpt2(difX2 * sumX2 * difX1, 2))
      ..addValue(BoostRobustFpt2(difY2 * sumY2 * difX1, 2))
      ..subtractValue(BoostRobustFpt2(difX1 * sumX1 * difX2, 2))
      ..subtractValue(BoostRobustFpt2(difY1 * sumY1 * difX2, 2));

    final lowerX = cx.copy()
      ..subtractValue(BoostRobustFpt2(
        math.sqrt(
          (difX1 * difX1 + difY1 * difY1) *
              (difX2 * difX2 + difY2 * difY2) *
              (difX3 * difX3 + difY3 * difY3),
        ),
        5,
      ));

    circle
      ..setX(cx.difference.fpv * invOrientation.fpv)
      ..setY(cy.difference.fpv * invOrientation.fpv)
      ..setLowerX(lowerX.difference.fpv * invOrientation.fpv);

    final recomputeX = cx.difference.ulp > BoostVoronoiPredicates2.ulps;
    final recomputeY = cy.difference.ulp > BoostVoronoiPredicates2.ulps;
    final recomputeLowerX =
        lowerX.difference.ulp > BoostVoronoiPredicates2.ulps;
    if (recomputeX || recomputeY || recomputeLowerX) {
      _exactPpp(
        site1,
        site2,
        site3,
        circle,
        recomputeX: recomputeX,
        recomputeY: recomputeY,
        recomputeLowerX: recomputeLowerX,
      );
    }
  }

  void _exactPpp(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    BoostCircleEvent2 circle, {
    required bool recomputeX,
    required bool recomputeY,
    required bool recomputeLowerX,
  }) {
    final difX = <BigInt>[
      BigInt.from(site1.x - site2.x),
      BigInt.from(site2.x - site3.x),
      BigInt.from(site1.x - site3.x),
    ];
    final difY = <BigInt>[
      BigInt.from(site1.y - site2.y),
      BigInt.from(site2.y - site3.y),
      BigInt.from(site1.y - site3.y),
    ];
    final sumX = <BigInt>[
      BigInt.from(site1.x + site2.x),
      BigInt.from(site2.x + site3.x),
    ];
    final sumY = <BigInt>[
      BigInt.from(site1.y + site2.y),
      BigInt.from(site2.y + site3.y),
    ];

    final denominator = difX[0] * difY[1] - difX[1] * difY[0];
    final invDenom = 0.5 / BoostBigIntConverter2.toDouble(denominator);
    final numerator1 = difX[0] * sumX[0] + difY[0] * sumY[0];
    final numerator2 = difX[1] * sumX[1] + difY[1] * sumY[1];

    if (recomputeX || recomputeLowerX) {
      final cx = numerator1 * difY[1] - numerator2 * difY[0];
      if (recomputeX) {
        circle.setX(BoostBigIntConverter2.toDouble(cx) * invDenom);
      }

      if (recomputeLowerX) {
        final sqrR = (difX[0] * difX[0] + difY[0] * difY[0]) *
            (difX[1] * difX[1] + difY[1] * difY[1]) *
            (difX[2] * difX[2] + difY[2] * difY[2]);
        final r = math.sqrt(BoostBigIntConverter2.toDouble(sqrR));
        if (circle.x >= 0) {
          circle.setLowerX(
            invDenom >= 0
                ? circle.x + r * invDenom
                : circle.x - r * invDenom,
          );
        } else {
          final numerator = cx * cx - sqrR;
          circle.setLowerX(
            BoostBigIntConverter2.toDouble(numerator) *
                invDenom /
                (BoostBigIntConverter2.toDouble(cx) + r),
          );
        }
      }
    }

    if (recomputeY) {
      final cy = numerator2 * difX[0] - numerator1 * difX[1];
      circle.setY(BoostBigIntConverter2.toDouble(cy) * invDenom);
    }
  }
}
