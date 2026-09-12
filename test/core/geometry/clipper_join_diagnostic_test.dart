import 'package:clipper2/clipper2.dart' as c2;
import 'package:flutter_test/flutter_test.dart';

double _areaMm2(c2.Path64 path) {
  var twiceArea = 0.0;
  for (var i = 0; i < path.length; i++) {
    final a = path[i];
    final b = path[(i + 1) % path.length];
    twiceArea += a.x.toDouble() * b.y.toDouble() -
        b.x.toDouble() * a.y.toDouble();
  }
  return twiceArea.abs() * 0.5 / 10000000000.0;
}

void main() {
  test('diagnose clipper2 0.0.3 join dispatch', () {
    final box = <c2.Point64>[
      c2.Point64(0, 0),
      c2.Point64(2000000, 0),
      c2.Point64(2000000, 2000000),
      c2.Point64(0, 2000000),
    ];

    for (final join in c2.JoinType.values) {
      final paths = c2.Clipper.inflatePaths(
        paths: [box],
        delta: 100000,
        joinType: join,
        endType: c2.EndType.polygon,
        miterLimit: 2,
      );
      final areas = paths.map(_areaMm2).toList(growable: false);
      // ignore: avoid_print
      print('CLIPPER2_JOIN_DIAGNOSTIC $join $areas');
    }
  });
}
