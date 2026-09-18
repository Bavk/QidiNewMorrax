import '../geometry/point.dart';
import '../model_io/three_mf_transform.dart';
import '../profiles/profile_repository.dart';

/// Converts QidiNewMorrax's centered Prepare coordinates to Orca/QIDI printer
/// coordinates, whose printable area is normally expressed from the bed's
/// lower-left origin.
class OrcaBedCoordinateMapper {
  const OrcaBedCoordinateMapper();

  Point3 bedCenter(QidiProfile machine) {
    final area = machine.values['printable_area'];
    if (area is! List || area.isEmpty) return const Point3(0, 0, 0);

    final points = <Point3>[];
    for (final raw in area) {
      final point = _parsePoint(raw.toString());
      if (point != null) points.add(point);
    }
    if (points.isEmpty) return const Point3(0, 0, 0);

    var minX = points.first.x;
    var maxX = points.first.x;
    var minY = points.first.y;
    var maxY = points.first.y;
    for (final point in points.skip(1)) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }
    return Point3((minX + maxX) / 2, (minY + maxY) / 2, 0);
  }

  ThreeMfTransform workspaceToPrinter(QidiProfile machine) {
    final center = bedCenter(machine);
    return ThreeMfTransform.fromComponents(translation: center);
  }

  Point3? _parsePoint(String value) {
    final match = RegExp(
      r'^\s*(-?(?:\d+(?:\.\d*)?|\.\d+))x'
      r'(-?(?:\d+(?:\.\d*)?|\.\d+))\s*$',
    ).firstMatch(value);
    if (match == null) return null;
    final x = double.tryParse(match.group(1)!);
    final y = double.tryParse(match.group(2)!);
    if (x == null || y == null) return null;
    return Point3(x, y, 0);
  }
}
