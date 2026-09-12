import '../geometry/source_geometry.dart';

/// Source-shaped subset of `Slic3r::Arachne::ExtrusionJunction`.
///
/// The fields remain mutable because pinned `fuzzy_extrusion_line()` updates
/// the first junction's position/width when synchronizing a closed line.
class SourceArachneExtrusionJunction2 {
  SourceArachneExtrusionJunction2({
    required this.p,
    required this.w,
    required this.perimeterIndex,
    this.holeCompensationFlag = false,
  });

  SourcePoint2 p;
  int w;
  int perimeterIndex;
  bool holeCompensationFlag;

  SourceArachneExtrusionJunction2 copy() =>
      SourceArachneExtrusionJunction2(
        p: p,
        w: w,
        perimeterIndex: perimeterIndex,
        holeCompensationFlag: holeCompensationFlag,
      );

  @override
  bool operator ==(Object other) =>
      other is SourceArachneExtrusionJunction2 &&
      other.p == p &&
      other.w == w &&
      other.perimeterIndex == perimeterIndex &&
      other.holeCompensationFlag == holeCompensationFlag;

  @override
  int get hashCode => Object.hash(
        p,
        w,
        perimeterIndex,
        holeCompensationFlag,
      );

  @override
  String toString() =>
      'SourceArachneExtrusionJunction2($p, w=$w, perimeter=$perimeterIndex, '
      'holeCompensation=$holeCompensationFlag)';
}

/// Source-shaped subset of `Slic3r::Arachne::ExtrusionLine` required by fuzzy
/// skin and the LineSegmentation overload.
///
/// Closed source lines normally duplicate the first junction at the end; the
/// model deliberately does not enforce that invariant so source edge cases can
/// be represented literally.
class SourceArachneExtrusionLine2 {
  SourceArachneExtrusionLine2({
    required this.insetIndex,
    required this.isOdd,
    this.isClosed = false,
    Iterable<SourceArachneExtrusionJunction2> junctions = const [],
  }) : junctions = [for (final junction in junctions) junction.copy()];

  final int insetIndex;
  final bool isOdd;
  final bool isClosed;
  final List<SourceArachneExtrusionJunction2> junctions;

  bool get isEmpty => junctions.isEmpty;
  bool get isNotEmpty => junctions.isNotEmpty;
  int get length => junctions.length;

  SourceArachneExtrusionJunction2 get front => junctions.first;
  SourceArachneExtrusionJunction2 get back => junctions.last;

  SourceArachneExtrusionLine2 copy() => SourceArachneExtrusionLine2(
        insetIndex: insetIndex,
        isOdd: isOdd,
        isClosed: isClosed,
        junctions: junctions,
      );
}
