import 'dart:math' as math;

import '../geometry/point.dart';

/// Affine transform using a conventional row-major 4x4 matrix.
///
/// 3MF serializes the first three rows column-by-column as 12 numbers. Keeping
/// the conversion here avoids spreading Bambu/Orca matrix-order assumptions
/// through the workspace and project writers.
class ThreeMfTransform {
  const ThreeMfTransform._(this.values);

  static const identity = ThreeMfTransform._(<double>[
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1,
  ]);

  final List<double> values;

  factory ThreeMfTransform.from3mf(String? source) {
    if (source == null || source.trim().isEmpty) return identity;
    final parsed = source
        .trim()
        .split(RegExp(r'\s+'))
        .map(double.tryParse)
        .toList(growable: false);
    if (parsed.length != 12 || parsed.any((value) => value == null)) {
      return identity;
    }
    final p = parsed.cast<double>();
    return ThreeMfTransform._(<double>[
      p[0], p[3], p[6], p[9],
      p[1], p[4], p[7], p[10],
      p[2], p[5], p[8], p[11],
      0, 0, 0, 1,
    ]);
  }

  factory ThreeMfTransform.fromComponents({
    Point3 translation = const Point3(0, 0, 0),
    Point3 scale = const Point3(1, 1, 1),
    Point3 rotationDegrees = const Point3(0, 0, 0),
  }) {
    final rx = rotationDegrees.x * math.pi / 180;
    final ry = rotationDegrees.y * math.pi / 180;
    final rz = rotationDegrees.z * math.pi / 180;

    final scaling = ThreeMfTransform._(<double>[
      scale.x, 0, 0, 0,
      0, scale.y, 0, 0,
      0, 0, scale.z, 0,
      0, 0, 0, 1,
    ]);
    final rotateX = ThreeMfTransform._(<double>[
      1, 0, 0, 0,
      0, math.cos(rx), -math.sin(rx), 0,
      0, math.sin(rx), math.cos(rx), 0,
      0, 0, 0, 1,
    ]);
    final rotateY = ThreeMfTransform._(<double>[
      math.cos(ry), 0, math.sin(ry), 0,
      0, 1, 0, 0,
      -math.sin(ry), 0, math.cos(ry), 0,
      0, 0, 0, 1,
    ]);
    final rotateZ = ThreeMfTransform._(<double>[
      math.cos(rz), -math.sin(rz), 0, 0,
      math.sin(rz), math.cos(rz), 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]);
    final translate = ThreeMfTransform._(<double>[
      1, 0, 0, translation.x,
      0, 1, 0, translation.y,
      0, 0, 1, translation.z,
      0, 0, 0, 1,
    ]);

    // Mesh.transformed applies scale, X rotation, Y rotation, Z rotation and
    // finally translation. Matrix multiplication is therefore reversed.
    return translate * rotateZ * rotateY * rotateX * scaling;
  }

  ThreeMfTransform operator *(ThreeMfTransform other) {
    final a = values;
    final b = other.values;
    final result = List<double>.filled(16, 0);
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        var value = 0.0;
        for (var k = 0; k < 4; k++) {
          value += a[row * 4 + k] * b[k * 4 + col];
        }
        result[row * 4 + col] = value;
      }
    }
    return ThreeMfTransform._(List.unmodifiable(result));
  }

  Point3 apply(Point3 point) {
    final m = values;
    return Point3(
      m[0] * point.x + m[1] * point.y + m[2] * point.z + m[3],
      m[4] * point.x + m[5] * point.y + m[6] * point.z + m[7],
      m[8] * point.x + m[9] * point.y + m[10] * point.z + m[11],
    );
  }

  bool get isIdentity {
    const expected = <double>[
      1, 0, 0, 0,
      0, 1, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ];
    for (var i = 0; i < 16; i++) {
      if ((values[i] - expected[i]).abs() > 1e-12) return false;
    }
    return true;
  }

  String to3mfString() {
    final m = values;
    return <double>[
      m[0], m[4], m[8],
      m[1], m[5], m[9],
      m[2], m[6], m[10],
      m[3], m[7], m[11],
    ].map(_format).join(' ');
  }

  static String _format(double value) {
    if (value.abs() < 1e-15) return '0';
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 1e-12) return rounded.toInt().toString();
    return value.toStringAsPrecision(17);
  }
}
