import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';

void main() {
  group('translated tests/libslic3r/test_geometry.cpp Line fixtures', () {
    test('Line::parallel_to preserves integer rotation rounding behavior', () {
      var line = const SourceLine2(
        SourcePoint2(100000, 0),
        SourcePoint2(0, 0),
      );
      final line2 = const SourceLine2(
        SourcePoint2(200000, 0),
        SourcePoint2(0, 0),
      );

      expect(line.parallelTo(line), true);
      expect(line.parallelTo(line2), true);

      var line3 = line2.rotated(0.9 * Slic3rUnits.epsilon);
      expect(line.parallelTo(line3), true);

      var line4 = line2.rotated(1.1 * Slic3rUnits.epsilon);
      expect(line.parallelTo(line4), false);

      final line5 = const SourceLine2(
        SourcePoint2(20000, 0),
        SourcePoint2(0, 0),
      ).rotated(1.1 * Slic3rUnits.epsilon);
      expect(line.parallelTo(line5), true);

      const offset = SourcePoint2(342876, 97636249);
      line = line.rotated(1).translated(offset);
      line3 = line3.rotated(1).translated(offset);
      line4 = line4.rotated(1).translated(offset);
      expect(line.parallelTo(line3), true);
      expect(line.parallelTo(line4), false);
    });

    test('Line::perpendicular_to preserves source epsilon behavior', () {
      var line = const SourceLine2(
        SourcePoint2(100000, 0),
        SourcePoint2(0, 0),
      );
      final line2 = const SourceLine2(
        SourcePoint2(0, 200000),
        SourcePoint2(0, 0),
      );

      expect(line.perpendicularTo(line), false);
      expect(line.perpendicularTo(line2), true);

      var line3 = line2.rotated(0.9 * Slic3rUnits.epsilon);
      expect(line.perpendicularTo(line3), true);

      var line4 = line2.rotated(1.1 * Slic3rUnits.epsilon);
      expect(line.perpendicularTo(line4), false);

      final line5 = const SourceLine2(
        SourcePoint2(0, 20000),
        SourcePoint2(0, 0),
      ).rotated(1.1 * Slic3rUnits.epsilon);
      expect(line.perpendicularTo(line5), true);

      const offset = SourcePoint2(342876, 97636249);
      line = line.rotated(1).translated(offset);
      line3 = line3.rotated(1).translated(offset);
      line4 = line4.rotated(1).translated(offset);
      expect(line.perpendicularTo(line3), true);
      expect(line.perpendicularTo(line4), false);
    });
  });

  group('Line source formulas', () {
    test('orientation is normalized to 0..2PI', () {
      const line = SourceLine2(SourcePoint2(0, 0), SourcePoint2(0, -10));
      expect(line.orientation, closeTo(3.141592653589793 * 1.5, 1e-12));
    });

    test('segment intersection truncates integer coord result like Eigen cast', () {
      const a = SourceLine2(SourcePoint2(0, 0), SourcePoint2(9, 9));
      const b = SourceLine2(SourcePoint2(0, 8), SourcePoint2(9, 0));
      final hit = a.intersection(b);
      expect(hit, isNotNull);
      expect(hit, const SourcePoint2(4, 4));
    });

    test('distanceTo clamps projection to finite segment endpoints', () {
      const line = SourceLine2(SourcePoint2(0, 0), SourcePoint2(10, 0));
      expect(line.distanceTo(const SourcePoint2(5, 3)), closeTo(3, 1e-12));
      expect(
        line.distanceTo(const SourcePoint2(20, 0)),
        closeTo(10, 1e-12),
      );
    });
  });
}
