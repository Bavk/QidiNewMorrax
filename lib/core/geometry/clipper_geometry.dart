import 'package:clipper2/clipper2.dart' as c2;

import 'expolygon.dart';
import 'point.dart';
import 'polygon.dart';

enum PolygonFillRule { evenOdd, nonZero, positive, negative }
enum PolygonJoinType { square, round, miter }

/// Pure-Dart polygon boolean/offset compatibility layer for
/// Slic3r::ClipperUtils.
///
/// Qidi Flow uses SCALING_FACTOR=0.00001, so 1 mm = 100000 integer units.
/// The API mirrors source operations so regression tests can compare the Dart
/// implementation directly against the supplied C++ fixtures.
class ClipperGeometry {
  const ClipperGeometry();

  static const double scalingFactor = 0.00001;
  static const double coordinateScale = 1 / scalingFactor;
  static const double defaultMiterLimit = 3.0;

  List<ExPolygon2> unionEx(
    List<Polygon2> subject, {
    PolygonFillRule fillRule = PolygonFillRule.nonZero,
  }) =>
      _booleanEx(c2.ClipType.union, subject, const [], fillRule: fillRule);

  List<ExPolygon2> intersectionEx(
    List<Polygon2> subject,
    List<Polygon2> clip, {
    PolygonFillRule fillRule = PolygonFillRule.nonZero,
  }) {
    if (subject.isEmpty || clip.isEmpty) return const [];
    return _booleanEx(
      c2.ClipType.intersection,
      subject,
      clip,
      fillRule: fillRule,
    );
  }

  List<ExPolygon2> differenceEx(
    List<Polygon2> subject,
    List<Polygon2> clip, {
    PolygonFillRule fillRule = PolygonFillRule.nonZero,
  }) {
    if (subject.isEmpty) return const [];
    if (clip.isEmpty) return unionEx(subject, fillRule: fillRule);
    return _booleanEx(
      c2.ClipType.difference,
      subject,
      clip,
      fillRule: fillRule,
    );
  }

  List<ExPolygon2> xorEx(
    List<Polygon2> subject,
    List<Polygon2> clip, {
    PolygonFillRule fillRule = PolygonFillRule.nonZero,
  }) {
    if (subject.isEmpty && clip.isEmpty) return const [];
    return _booleanEx(c2.ClipType.xor, subject, clip, fillRule: fillRule);
  }

  List<ExPolygon2> offsetPolygonsEx(
    List<Polygon2> polygons,
    double delta, {
    PolygonJoinType joinType = PolygonJoinType.miter,
    double miterLimit = defaultMiterLimit,
    double arcTolerance = 0,
  }) {
    if (polygons.isEmpty) return const [];
    if (delta == 0) return unionEx(polygons);
    final result = c2.Clipper.inflatePaths(
      paths: _toPaths(polygons),
      delta: _scaleDistance(delta),
      joinType: _joinType(joinType),
      endType: c2.EndType.polygon,
      miterLimit: miterLimit,
      arcTolerance: arcTolerance == 0 ? 0 : _scaleDistance(arcTolerance).abs(),
    );
    return _pathsToExPolygons(result);
  }

  /// Mirrors ClipperUtils.cpp `offset_ex(ExPolygon)`: contour and holes are
  /// offset separately, hole delta is reversed, and holes are then subtracted
  /// or re-oriented according to the sign of the requested offset.
  List<ExPolygon2> offsetExPolygon(
    ExPolygon2 expolygon,
    double delta, {
    PolygonJoinType joinType = PolygonJoinType.miter,
    double miterLimit = defaultMiterLimit,
    double arcTolerance = 0,
  }) {
    if (delta == 0) {
      return [
        ExPolygon2(
          contour: _ensureOuter(expolygon.contour),
          holes: [for (final h in expolygon.holes) _ensureHole(h)],
        ),
      ];
    }

    final contours = _offsetSinglePolygon(
      _ensureOuter(expolygon.contour),
      delta,
      joinType: joinType,
      miterLimit: miterLimit,
      arcTolerance: arcTolerance,
    );
    if (contours.isEmpty) return const [];
    if (expolygon.holes.isEmpty) return _pathsToExPolygons(contours);

    final holes = <c2.Path64>[];
    for (final hole in expolygon.holes) {
      holes.addAll(_offsetSinglePolygon(
        _ensureHole(hole),
        -delta,
        joinType: joinType,
        miterLimit: miterLimit,
        arcTolerance: arcTolerance,
      ));
    }
    if (holes.isEmpty) return _pathsToExPolygons(contours);

    if (delta < 0) {
      return _pathsToExPolygons(c2.Clipper.difference(
        subject: contours,
        clip: holes,
        fillRule: c2.FillRule.nonZero,
      ));
    }

    final raw = <c2.Path64>[
      ...contours,
      for (final hole in holes) hole.reversed.toList(growable: false),
    ];
    return _pathsToExPolygons(raw);
  }

  List<ExPolygon2> offsetExPolygons(
    List<ExPolygon2> expolygons,
    double delta, {
    PolygonJoinType joinType = PolygonJoinType.miter,
    double miterLimit = defaultMiterLimit,
    double arcTolerance = 0,
  }) {
    if (expolygons.isEmpty) return const [];
    if (delta == 0) {
      return unionEx([
        for (final e in expolygons) ...[
          _ensureOuter(e.contour),
          ...e.holes.map(_ensureHole),
        ],
      ]);
    }

    final raw = <Polygon2>[];
    for (final expolygon in expolygons) {
      final offset = offsetExPolygon(
        expolygon,
        delta,
        joinType: joinType,
        miterLimit: miterLimit,
        arcTolerance: arcTolerance,
      );
      for (final result in offset) {
        raw.add(_ensureOuter(result.contour));
        raw.addAll(result.holes.map(_ensureHole));
      }
    }
    return unionEx(raw);
  }

  List<ExPolygon2> offset2Ex(
    List<ExPolygon2> expolygons,
    double delta1,
    double delta2, {
    PolygonJoinType joinType = PolygonJoinType.miter,
    double miterLimit = defaultMiterLimit,
  }) {
    final first = offsetExPolygons(
      expolygons,
      delta1,
      joinType: joinType,
      miterLimit: miterLimit,
    );
    return offsetExPolygons(
      first,
      delta2,
      joinType: joinType,
      miterLimit: miterLimit,
    );
  }

  List<ExPolygon2> closingEx(
    List<ExPolygon2> expolygons,
    double delta, {
    PolygonJoinType joinType = PolygonJoinType.miter,
    double miterLimit = defaultMiterLimit,
  }) {
    if (delta <= 0) {
      throw ArgumentError.value(delta, 'delta', 'closing delta must be > 0');
    }
    return offset2Ex(
      expolygons,
      delta,
      -delta,
      joinType: joinType,
      miterLimit: miterLimit,
    );
  }

  List<ExPolygon2> openingEx(
    List<ExPolygon2> expolygons,
    double delta, {
    PolygonJoinType joinType = PolygonJoinType.miter,
    double miterLimit = defaultMiterLimit,
  }) {
    if (delta <= 0) {
      throw ArgumentError.value(delta, 'delta', 'opening delta must be > 0');
    }
    return offset2Ex(
      expolygons,
      -delta,
      delta,
      joinType: joinType,
      miterLimit: miterLimit,
    );
  }

  List<ExPolygon2> _booleanEx(
    c2.ClipType operation,
    List<Polygon2> subject,
    List<Polygon2> clip, {
    required PolygonFillRule fillRule,
  }) {
    final tree = c2.Clipper.booleanOpPolyTree(
      clipType: operation,
      subject: _toPaths(subject),
      clip: _toPaths(clip),
      fillRule: _fillRule(fillRule),
    );
    return _treeToExPolygons(tree);
  }

  List<c2.Path64> _offsetSinglePolygon(
    Polygon2 polygon,
    double delta, {
    required PolygonJoinType joinType,
    required double miterLimit,
    required double arcTolerance,
  }) {
    if (polygon.points.length < 3) return const [];
    return c2.Clipper.inflatePaths(
      paths: [_toPath(polygon)],
      delta: _scaleDistance(delta),
      joinType: _joinType(joinType),
      endType: c2.EndType.polygon,
      miterLimit: miterLimit,
      arcTolerance: arcTolerance == 0 ? 0 : _scaleDistance(arcTolerance).abs(),
    );
  }

  List<ExPolygon2> _pathsToExPolygons(c2.Paths64 paths) {
    if (paths.isEmpty) return const [];
    final tree = c2.Clipper.booleanOpPolyTree(
      clipType: c2.ClipType.union,
      subject: paths,
      fillRule: c2.FillRule.nonZero,
    );
    return _treeToExPolygons(tree);
  }

  List<ExPolygon2> _treeToExPolygons(c2.PolyTree64 tree) {
    final result = <ExPolygon2>[];

    void visit(c2.PolyPath64 node) {
      final path = node.polygon;
      if (path != null && path.length >= 3 && !node.isHole) {
        final holes = <Polygon2>[];
        for (final child in node.children) {
          final holePath = child.polygon;
          if (child.isHole && holePath != null && holePath.length >= 3) {
            holes.add(_ensureHole(_fromPath(holePath)));
          }
        }
        result.add(ExPolygon2(
          contour: _ensureOuter(_fromPath(path)),
          holes: holes,
        ));
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final child in tree.children) {
      visit(child);
    }
    return List.unmodifiable(result);
  }

  c2.Paths64 _toPaths(List<Polygon2> polygons) => [
        for (final polygon in polygons)
          if (polygon.points.length >= 3) _toPath(polygon),
      ];

  c2.Path64 _toPath(Polygon2 polygon) => [
        for (final point in polygon.points)
          c2.Point64(_scaleCoordinate(point.x), _scaleCoordinate(point.y)),
      ];

  Polygon2 _fromPath(c2.Path64 path) => Polygon2([
        for (final point in path)
          Point2(point.x / coordinateScale, point.y / coordinateScale),
      ]);

  int _scaleCoordinate(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'coordinate', 'must be finite');
    }
    return (value * coordinateScale).round();
  }

  double _scaleDistance(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'delta', 'must be finite');
    }
    return value * coordinateScale;
  }

  Polygon2 _ensureOuter(Polygon2 polygon) =>
      polygon.isClockwise ? polygon.reversed() : polygon;

  Polygon2 _ensureHole(Polygon2 polygon) =>
      polygon.isClockwise ? polygon : polygon.reversed();

  c2.FillRule _fillRule(PolygonFillRule value) => switch (value) {
        PolygonFillRule.evenOdd => c2.FillRule.evenOdd,
        PolygonFillRule.nonZero => c2.FillRule.nonZero,
        PolygonFillRule.positive => c2.FillRule.positive,
        PolygonFillRule.negative => c2.FillRule.negative,
      };

  c2.JoinType _joinType(PolygonJoinType value) => switch (value) {
        PolygonJoinType.square => c2.JoinType.square,
        PolygonJoinType.round => c2.JoinType.round,
        PolygonJoinType.miter => c2.JoinType.miter,
      };
}
