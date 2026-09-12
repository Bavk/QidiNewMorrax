import 'source_boost_extended_numeric.dart';
import 'source_boost_robust_fpt.dart';
import 'source_boost_voronoi_predicates.dart';
import 'source_boost_voronoi_structures.dart';

/// Exact Boost.Polygon 1.83 segment-segment-segment circle-event formation.
class BoostSssCircleFormation2 {
  const BoostSssCircleFormation2();

  void form(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    BoostCircleEvent2 circle,
  ) {
    final a1 = BoostRobustFpt2(
      site1.x1.toDouble() - site1.x0.toDouble(),
    );
    final b1 = BoostRobustFpt2(
      site1.y1.toDouble() - site1.y0.toDouble(),
    );
    final c1 = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site1.x0,
        site1.y0,
        site1.x1,
        site1.y1,
      ),
      1,
    );

    final a2 = BoostRobustFpt2(
      site2.x1.toDouble() - site2.x0.toDouble(),
    );
    final b2 = BoostRobustFpt2(
      site2.y1.toDouble() - site2.y0.toDouble(),
    );
    final c2 = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site2.x0,
        site2.y0,
        site2.x1,
        site2.y1,
      ),
      1,
    );

    final a3 = BoostRobustFpt2(
      site3.x1.toDouble() - site3.x0.toDouble(),
    );
    final b3 = BoostRobustFpt2(
      site3.y1.toDouble() - site3.y0.toDouble(),
    );
    final c3 = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site3.x0,
        site3.y0,
        site3.x1,
        site3.y1,
      ),
      1,
    );

    final len1 = (a1 * a1 + b1 * b1).sqrt();
    final len2 = (a2 * a2 + b2 * b2).sqrt();
    final len3 = (a3 * a3 + b3 * b3).sqrt();
    final cross12 = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site1.x1 - site1.x0,
        site1.y1 - site1.y0,
        site2.x1 - site2.x0,
        site2.y1 - site2.y0,
      ),
      1,
    );
    final cross23 = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site2.x1 - site2.x0,
        site2.y1 - site2.y0,
        site3.x1 - site3.x0,
        site3.y1 - site3.y0,
      ),
      1,
    );
    final cross31 = BoostRobustFpt2(
      BoostVoronoiPredicates2.robustCrossProduct(
        site3.x1 - site3.x0,
        site3.y1 - site3.y0,
        site1.x1 - site1.x0,
        site1.y1 - site1.y0,
      ),
      1,
    );

    final denominator = BoostRobustDif2()
      ..addValue(cross12 * len3)
      ..addValue(cross23 * len1)
      ..addValue(cross31 * len2);

    final r = BoostRobustDif2()
      ..subtractValue(cross12 * c3)
      ..subtractValue(cross23 * c1)
      ..subtractValue(cross31 * c2);

    final cx = BoostRobustDif2()
      ..addValue(a1 * c2 * len3)
      ..subtractValue(a2 * c1 * len3)
      ..addValue(a2 * c3 * len1)
      ..subtractValue(a3 * c2 * len1)
      ..addValue(a3 * c1 * len2)
      ..subtractValue(a1 * c3 * len2);

    final cy = BoostRobustDif2()
      ..addValue(b1 * c2 * len3)
      ..subtractValue(b2 * c1 * len3)
      ..addValue(b2 * c3 * len1)
      ..subtractValue(b3 * c2 * len1)
      ..addValue(b3 * c1 * len2)
      ..subtractValue(b1 * c3 * len2);

    final lowerX = BoostRobustDif2.add(cx, r);
    final denominatorDifference = denominator.difference;
    final cxDifference = cx.difference / denominatorDifference;
    final cyDifference = cy.difference / denominatorDifference;
    final lowerDifference = lowerX.difference / denominatorDifference;

    circle
      ..setX(cxDifference.fpv)
      ..setY(cyDifference.fpv)
      ..setLowerX(lowerDifference.fpv);

    final recomputeX = cxDifference.ulp > BoostVoronoiPredicates2.ulps;
    final recomputeY = cyDifference.ulp > BoostVoronoiPredicates2.ulps;
    final recomputeLowerX =
        lowerDifference.ulp > BoostVoronoiPredicates2.ulps;
    if (recomputeX || recomputeY || recomputeLowerX) {
      _exact(
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

  void _exact(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    BoostCircleEvent2 circle, {
    required bool recomputeX,
    required bool recomputeY,
    required bool recomputeLowerX,
  }) {
    final sites = [site1, site2, site3];
    final a = List<BigInt>.filled(3, BigInt.zero);
    final b = List<BigInt>.filled(3, BigInt.zero);
    final c = List<BigInt>.filled(3, BigInt.zero);
    final cA = List<BigInt>.filled(4, BigInt.zero);
    final cB = List<BigInt>.filled(4, BigInt.zero);

    for (var i = 0; i < 3; i++) {
      final site = sites[i];
      a[i] = BigInt.from(site.x1 - site.x0);
      b[i] = BigInt.from(site.y1 - site.y0);
      c[i] = BigInt.from(site.x0) * BigInt.from(site.y1) -
          BigInt.from(site.y0) * BigInt.from(site.x1);
      cB[i] = a[i] * a[i] + b[i] * b[i];
    }

    for (var i = 0; i < 3; i++) {
      final j = (i + 1) % 3;
      final k = (i + 2) % 3;
      cA[i] = a[j] * b[k] - a[k] * b[j];
    }
    final sqrtExpression = BoostRobustSqrtExpr2();
    final denominator = sqrtExpression.eval3(cA, cB).toDouble();

    if (recomputeY) {
      for (var i = 0; i < 3; i++) {
        final j = (i + 1) % 3;
        final k = (i + 2) % 3;
        cA[i] = b[j] * c[k] - b[k] * c[j];
      }
      circle.setY(sqrtExpression.eval3(cA, cB).toDouble() / denominator);
    }

    if (recomputeX || recomputeLowerX) {
      cA[3] = BigInt.zero;
      for (var i = 0; i < 3; i++) {
        final j = (i + 1) % 3;
        final k = (i + 2) % 3;
        cA[i] = a[j] * c[k] - a[k] * c[j];
        if (recomputeLowerX) cA[3] += cA[i] * b[i];
      }

      if (recomputeX) {
        circle.setX(sqrtExpression.eval3(cA, cB).toDouble() / denominator);
      }
      if (recomputeLowerX) {
        cB[3] = BigInt.one;
        circle.setLowerX(
          sqrtExpression.eval4(cA, cB).toDouble() / denominator,
        );
      }
    }
  }
}
