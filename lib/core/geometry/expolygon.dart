import 'point.dart';
import 'polygon.dart';

/// Dart counterpart of Slic3r::ExPolygon: one outer contour plus zero or more
/// holes. Orientation is normalized only when crossing the Clipper boundary;
/// callers may retain source winding while editing/importing geometry.
class ExPolygon2 {
  ExPolygon2({
    required this.contour,
    Iterable<Polygon2> holes = const [],
  }) : holes = List.unmodifiable(holes);

  final Polygon2 contour;
  final List<Polygon2> holes;

  double get area =>
      contour.area - holes.fold<double>(0, (sum, hole) => sum + hole.area);

  bool containsPoint(Point2 point) {
    if (!contour.contains(point)) return false;
    for (final hole in holes) {
      if (hole.contains(point)) return false;
    }
    return true;
  }

  List<Polygon2> get polygons => List.unmodifiable([contour, ...holes]);
}
