import 'source_libnoise_vectors.dart';

/// Literal Dart port of the libnoise v1.0.0 subset used by pinned
/// BambuStudio `FuzzySkin.cpp`.
///
/// Upstream dependency identity:
/// `bambulab/libnoise` tag `v1.0.0`, selected by BambuStudio's
/// `deps/libnoise/libnoise.cmake` at commit
/// `f2b55a5a83f266cf56e06c7943a81a08bebb7fad`.
abstract interface class SourceLibNoiseModule2 {
  double getValue(double x, double y, double z);
}

class SourceLibNoisePerlin2 implements SourceLibNoiseModule2 {
  SourceLibNoisePerlin2({
    required this.frequency,
    required this.octaveCount,
    required this.persistence,
    this.seed = 0,
  }) {
    if (octaveCount < 1 || octaveCount > 30) {
      throw ArgumentError.value(octaveCount, 'octaveCount', 'must be 1..30');
    }
  }

  final double frequency;
  final int octaveCount;
  final double persistence;
  final int seed;

  @override
  double getValue(double x, double y, double z) {
    var value = 0.0;
    var currentPersistence = 1.0;
    x *= frequency;
    y *= frequency;
    z *= frequency;

    for (var octave = 0; octave < octaveCount; octave++) {
      final nx = SourceLibNoiseCore2.makeInt32Range(x);
      final ny = SourceLibNoiseCore2.makeInt32Range(y);
      final nz = SourceLibNoiseCore2.makeInt32Range(z);
      final signal = SourceLibNoiseCore2.gradientCoherentNoise3D(
        nx,
        ny,
        nz,
        seed + octave,
      );
      value += signal * currentPersistence;
      x *= 2.0;
      y *= 2.0;
      z *= 2.0;
      currentPersistence *= persistence;
    }
    return value;
  }
}

class SourceLibNoiseBillow2 implements SourceLibNoiseModule2 {
  SourceLibNoiseBillow2({
    required this.frequency,
    required this.octaveCount,
    required this.persistence,
    this.seed = 0,
  }) {
    if (octaveCount < 1 || octaveCount > 30) {
      throw ArgumentError.value(octaveCount, 'octaveCount', 'must be 1..30');
    }
  }

  final double frequency;
  final int octaveCount;
  final double persistence;
  final int seed;

  @override
  double getValue(double x, double y, double z) {
    var value = 0.0;
    var currentPersistence = 1.0;
    x *= frequency;
    y *= frequency;
    z *= frequency;

    for (var octave = 0; octave < octaveCount; octave++) {
      final nx = SourceLibNoiseCore2.makeInt32Range(x);
      final ny = SourceLibNoiseCore2.makeInt32Range(y);
      final nz = SourceLibNoiseCore2.makeInt32Range(z);
      var signal = SourceLibNoiseCore2.gradientCoherentNoise3D(
        nx,
        ny,
        nz,
        seed + octave,
      );
      signal = 2.0 * signal.abs() - 1.0;
      value += signal * currentPersistence;
      x *= 2.0;
      y *= 2.0;
      z *= 2.0;
      currentPersistence *= persistence;
    }
    return value + 0.5;
  }
}

class SourceLibNoiseRidgedMulti2 implements SourceLibNoiseModule2 {
  SourceLibNoiseRidgedMulti2({
    required this.frequency,
    required this.octaveCount,
    this.seed = 0,
  }) {
    // libnoise's RidgedMulti::SetOctaveCount() checks only the upper bound.
    if (octaveCount > 30) {
      throw ArgumentError.value(octaveCount, 'octaveCount', 'must be <= 30');
    }
  }

  final double frequency;
  final int octaveCount;
  final int seed;

  @override
  double getValue(double x, double y, double z) {
    x *= frequency;
    y *= frequency;
    z *= frequency;

    var value = 0.0;
    var weight = 1.0;
    var spectralWeight = 1.0;

    for (var octave = 0; octave < octaveCount; octave++) {
      final nx = SourceLibNoiseCore2.makeInt32Range(x);
      final ny = SourceLibNoiseCore2.makeInt32Range(y);
      final nz = SourceLibNoiseCore2.makeInt32Range(z);
      var signal = SourceLibNoiseCore2.gradientCoherentNoise3D(
        nx,
        ny,
        nz,
        (seed + octave) & 0x7fffffff,
      );

      signal = 1.0 - signal.abs();
      signal *= signal;
      signal *= weight;
      weight = signal * 2.0;
      if (weight > 1.0) weight = 1.0;
      if (weight < 0.0) weight = 0.0;

      value += signal * spectralWeight;
      x *= 2.0;
      y *= 2.0;
      z *= 2.0;
      spectralWeight *= 0.5;
    }

    return value * 1.25 - 1.0;
  }
}

class SourceLibNoiseVoronoi2 implements SourceLibNoiseModule2 {
  const SourceLibNoiseVoronoi2({
    required this.frequency,
    this.displacement = 1.0,
    this.seed = 0,
  });

  final double frequency;
  final double displacement;
  final int seed;

  @override
  double getValue(double x, double y, double z) {
    x *= frequency;
    y *= frequency;
    z *= frequency;

    final xInt = SourceLibNoiseCore2.sourceCubeLower(x);
    final yInt = SourceLibNoiseCore2.sourceCubeLower(y);
    final zInt = SourceLibNoiseCore2.sourceCubeLower(z);

    var minDist = 2147483647.0;
    var xCandidate = 0.0;
    var yCandidate = 0.0;
    var zCandidate = 0.0;

    for (var zCur = zInt - 2; zCur <= zInt + 2; zCur++) {
      for (var yCur = yInt - 2; yCur <= yInt + 2; yCur++) {
        for (var xCur = xInt - 2; xCur <= xInt + 2; xCur++) {
          final xPos = xCur +
              SourceLibNoiseCore2.valueNoise3D(xCur, yCur, zCur, seed);
          final yPos = yCur +
              SourceLibNoiseCore2.valueNoise3D(xCur, yCur, zCur, seed + 1);
          final zPos = zCur +
              SourceLibNoiseCore2.valueNoise3D(xCur, yCur, zCur, seed + 2);
          final xDist = xPos - x;
          final yDist = yPos - y;
          final zDist = zPos - z;
          final dist = xDist * xDist + yDist * yDist + zDist * zDist;
          if (dist < minDist) {
            minDist = dist;
            xCandidate = xPos;
            yCandidate = yPos;
            zCandidate = zPos;
          }
        }
      }
    }

    // FuzzySkin.cpp never calls EnableDistance(), so the distance term is 0.
    return displacement *
        SourceLibNoiseCore2.valueNoise3D(
          xCandidate.floor(),
          yCandidate.floor(),
          zCandidate.floor(),
          seed,
        );
  }
}

class SourceLibNoiseCore2 {
  const SourceLibNoiseCore2._();

  static const int _u32Mask = 0xffffffff;
  static const int _u31Mask = 0x7fffffff;

  static double makeInt32Range(double n) {
    if (n >= 1073741824.0) {
      return 2.0 * n.remainder(1073741824.0) - 1073741824.0;
    }
    if (n <= -1073741824.0) {
      return 2.0 * n.remainder(1073741824.0) + 1073741824.0;
    }
    return n;
  }

  /// Literal libnoise cube-lower expression, including its integer-boundary
  /// quirk for zero and negative integral coordinates.
  static int sourceCubeLower(double value) =>
      value > 0.0 ? value.truncate() : value.truncate() - 1;

  static double gradientCoherentNoise3D(
    double x,
    double y,
    double z,
    int seed,
  ) {
    final x0 = sourceCubeLower(x);
    final x1 = x0 + 1;
    final y0 = sourceCubeLower(y);
    final y1 = y0 + 1;
    final z0 = sourceCubeLower(z);
    final z1 = z0 + 1;

    final xs = _sCurve3(x - x0.toDouble());
    final ys = _sCurve3(y - y0.toDouble());
    final zs = _sCurve3(z - z0.toDouble());

    var n0 = gradientNoise3D(x, y, z, x0, y0, z0, seed);
    var n1 = gradientNoise3D(x, y, z, x1, y0, z0, seed);
    var ix0 = _linearInterp(n0, n1, xs);
    n0 = gradientNoise3D(x, y, z, x0, y1, z0, seed);
    n1 = gradientNoise3D(x, y, z, x1, y1, z0, seed);
    var ix1 = _linearInterp(n0, n1, xs);
    final iy0 = _linearInterp(ix0, ix1, ys);

    n0 = gradientNoise3D(x, y, z, x0, y0, z1, seed);
    n1 = gradientNoise3D(x, y, z, x1, y0, z1, seed);
    ix0 = _linearInterp(n0, n1, xs);
    n0 = gradientNoise3D(x, y, z, x0, y1, z1, seed);
    n1 = gradientNoise3D(x, y, z, x1, y1, z1, seed);
    ix1 = _linearInterp(n0, n1, xs);
    final iy1 = _linearInterp(ix0, ix1, ys);
    return _linearInterp(iy0, iy1, zs);
  }

  static double gradientNoise3D(
    double fx,
    double fy,
    double fz,
    int ix,
    int iy,
    int iz,
    int seed,
  ) {
    final sum = _u32(
      1619 * ix + 31337 * iy + 6971 * iz + 1013 * seed,
    );
    var vectorIndex = _i32(sum);
    vectorIndex = _i32(vectorIndex ^ (vectorIndex >> 8));
    vectorIndex &= 0xff;

    final tableIndex = vectorIndex << 2;
    final xvGradient = sourceLibNoiseRandomVectors2[tableIndex];
    final yvGradient = sourceLibNoiseRandomVectors2[tableIndex + 1];
    final zvGradient = sourceLibNoiseRandomVectors2[tableIndex + 2];
    final xvPoint = fx - ix.toDouble();
    final yvPoint = fy - iy.toDouble();
    final zvPoint = fz - iz.toDouble();
    return (xvGradient * xvPoint +
            yvGradient * yvPoint +
            zvGradient * zvPoint) *
        2.12;
  }

  static int intValueNoise3D(int x, int y, int z, int seed) {
    var n = _u32(1619 * x + 31337 * y + 6971 * z + 1013 * seed) &
        _u31Mask;
    n = (n >> 13) ^ n;
    final inner = _u32(_u32(n * n) * 60493 + 19990303);
    return _u32(n * inner + 1376312589) & _u31Mask;
  }

  static double valueNoise3D(int x, int y, int z, int seed) =>
      1.0 - intValueNoise3D(x, y, z, seed) / 1073741824.0;

  static int _u32(int value) => value & _u32Mask;

  static int _i32(int value) {
    final wrapped = value & _u32Mask;
    return wrapped >= 0x80000000 ? wrapped - 0x100000000 : wrapped;
  }

  static double _linearInterp(double n0, double n1, double a) =>
      (1.0 - a) * n0 + a * n1;

  static double _sCurve3(double a) => a * a * (3.0 - 2.0 * a);
}
