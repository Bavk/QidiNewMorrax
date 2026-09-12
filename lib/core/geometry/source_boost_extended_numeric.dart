import 'dart:math' as math;
import 'dart:typed_data';

class _FrexpResult2 {
  const _FrexpResult2(this.value, this.exponent);
  final double value;
  final int exponent;
}

/// Boost.Polygon 1.83 `extended_exponent_fpt<double>`.
class BoostExtendedExponentFpt2 {
  BoostExtendedExponentFpt2.fromDouble(double value) {
    final split = _frexp(value);
    _value = split.value;
    _exponent = split.exponent;
  }

  BoostExtendedExponentFpt2.fromValueAndExponent(double value, int exponent) {
    final split = _frexp(value);
    _value = split.value;
    _exponent = split.exponent + exponent;
  }

  late final double _value;
  late final int _exponent;

  static const int maxSignificantExponentDifference = 54;

  bool get isPositive => _value > 0;
  bool get isNegative => _value < 0;
  bool get isZero => _value == 0;

  BoostExtendedExponentFpt2 operator -() =>
      BoostExtendedExponentFpt2.fromValueAndExponent(-_value, _exponent);

  BoostExtendedExponentFpt2 operator +(BoostExtendedExponentFpt2 other) {
    if (_value == 0 ||
        other._exponent >
            _exponent + maxSignificantExponentDifference) {
      return other;
    }
    if (other._value == 0 ||
        _exponent >
            other._exponent + maxSignificantExponentDifference) {
      return this;
    }
    if (_exponent >= other._exponent) {
      final difference = _exponent - other._exponent;
      final value = _ldexp(_value, difference) + other._value;
      return BoostExtendedExponentFpt2.fromValueAndExponent(
        value,
        other._exponent,
      );
    }
    final difference = other._exponent - _exponent;
    final value = _ldexp(other._value, difference) + _value;
    return BoostExtendedExponentFpt2.fromValueAndExponent(value, _exponent);
  }

  BoostExtendedExponentFpt2 operator -(BoostExtendedExponentFpt2 other) {
    if (_value == 0 ||
        other._exponent >
            _exponent + maxSignificantExponentDifference) {
      return BoostExtendedExponentFpt2.fromValueAndExponent(
        -other._value,
        other._exponent,
      );
    }
    if (other._value == 0 ||
        _exponent >
            other._exponent + maxSignificantExponentDifference) {
      return this;
    }
    if (_exponent >= other._exponent) {
      final difference = _exponent - other._exponent;
      final value = _ldexp(_value, difference) - other._value;
      return BoostExtendedExponentFpt2.fromValueAndExponent(
        value,
        other._exponent,
      );
    }
    final difference = other._exponent - _exponent;
    final value = _ldexp(-other._value, difference) + _value;
    return BoostExtendedExponentFpt2.fromValueAndExponent(value, _exponent);
  }

  BoostExtendedExponentFpt2 operator *(BoostExtendedExponentFpt2 other) =>
      BoostExtendedExponentFpt2.fromValueAndExponent(
        _value * other._value,
        _exponent + other._exponent,
      );

  BoostExtendedExponentFpt2 operator /(BoostExtendedExponentFpt2 other) =>
      BoostExtendedExponentFpt2.fromValueAndExponent(
        _value / other._value,
        _exponent - other._exponent,
      );

  BoostExtendedExponentFpt2 sqrt() {
    var value = _value;
    var exponent = _exponent;
    if (exponent.isOdd) {
      value *= 2;
      exponent--;
    }
    return BoostExtendedExponentFpt2.fromValueAndExponent(
      math.sqrt(value),
      exponent >> 1,
    );
  }

  double toDouble() => _ldexp(_value, _exponent);

  @override
  String toString() =>
      'BoostExtendedExponentFpt2(value=$_value, exponent=$_exponent)';

  static _FrexpResult2 _frexp(double value) {
    if (value == 0) return _FrexpResult2(value, 0);
    if (!value.isFinite) return _FrexpResult2(value, 0);

    var scaled = value;
    var correction = 0;
    var bits = _doubleBits(scaled);
    var exponentBits = (bits >> 52) & 0x7ff;
    if (exponentBits == 0) {
      // Normalize a subnormal exactly with a power-of-two multiplication.
      scaled *= 18014398509481984.0; // 2^54
      correction = -54;
      bits = _doubleBits(scaled);
      exponentBits = (bits >> 52) & 0x7ff;
    }

    final sign = bits & 0x8000000000000000;
    final fraction = bits & 0x000fffffffffffff;
    final mantissaBits = sign | (0x3fe << 52) | fraction;
    final mantissa = _doubleFromBits(mantissaBits);
    final exponent = exponentBits - 1022 + correction;
    return _FrexpResult2(mantissa, exponent);
  }

  static double _ldexp(double value, int exponent) {
    if (value == 0 || !value.isFinite || exponent == 0) return value;
    var output = value;
    var remaining = exponent;
    while (remaining > 1023) {
      output *= 8.98846567431158e307; // 2^1023
      if (!output.isFinite) return output;
      remaining -= 1023;
    }
    while (remaining < -1022) {
      output *= 2.2250738585072014e-308; // 2^-1022
      if (output == 0) return output;
      remaining += 1022;
    }
    return output * math.pow(2.0, remaining).toDouble();
  }

  static int _doubleBits(double value) {
    final data = ByteData(8)..setFloat64(0, value, Endian.host);
    return data.getUint64(0, Endian.host);
  }

  static double _doubleFromBits(int bits) {
    final data = ByteData(8)..setUint64(0, bits, Endian.host);
    return data.getFloat64(0, Endian.host);
  }
}

class BoostBigIntConverter2 {
  const BoostBigIntConverter2._();

  /// Boost `extended_int::p()`: use at most the three most significant 32-bit
  /// chunks and return the remaining chunk count as a base-2 exponent.
  static ({double value, int exponent}) pair(BigInt input) {
    if (input == BigInt.zero) return (value: 0, exponent: 0);
    final negative = input.isNegative;
    var value = input.abs();
    final chunks = <int>[];
    final mask = BigInt.from(0xffffffff);
    while (value != BigInt.zero) {
      chunks.add((value & mask).toInt());
      value >>= 32;
    }

    double converted;
    var exponent = 0;
    if (chunks.length == 1) {
      converted = chunks[0].toDouble();
    } else if (chunks.length == 2) {
      converted = chunks[1].toDouble() * 4294967296.0 +
          chunks[0].toDouble();
    } else {
      converted = 0;
      for (var i = 1; i <= 3; i++) {
        converted *= 4294967296.0;
        converted += chunks[chunks.length - i].toDouble();
      }
      exponent = (chunks.length - 3) << 5;
    }
    if (negative) converted = -converted;
    return (value: converted, exponent: exponent);
  }

  static double toDouble(BigInt input) {
    final p = pair(input);
    return BoostExtendedExponentFpt2.fromValueAndExponent(
      p.value,
      p.exponent,
    ).toDouble();
  }

  static BoostExtendedExponentFpt2 toExtended(BigInt input) {
    final p = pair(input);
    return BoostExtendedExponentFpt2.fromValueAndExponent(
      p.value,
      p.exponent,
    );
  }
}

/// Boost `robust_sqrt_expr<extended_int<64>,efpt64,...>`.
class BoostRobustSqrtExpr2 {
  BoostExtendedExponentFpt2 eval1(List<BigInt> a, List<BigInt> b,
      [int offset = 0]) {
    final av = BoostBigIntConverter2.toExtended(a[offset]);
    final bv = BoostBigIntConverter2.toExtended(b[offset]);
    return av * bv.sqrt();
  }

  BoostExtendedExponentFpt2 eval2(List<BigInt> a, List<BigInt> b,
      [int offset = 0]) {
    final first = eval1(a, b, offset);
    final second = eval1(a, b, offset + 1);
    if ((!first.isNegative && !second.isNegative) ||
        (!first.isPositive && !second.isPositive)) {
      return first + second;
    }
    final numerator = a[offset] * a[offset] * b[offset] -
        a[offset + 1] * a[offset + 1] * b[offset + 1];
    return BoostBigIntConverter2.toExtended(numerator) / (first - second);
  }

  BoostExtendedExponentFpt2 eval3(List<BigInt> a, List<BigInt> b,
      [int offset = 0]) {
    final first = eval2(a, b, offset);
    final second = eval1(a, b, offset + 2);
    if ((!first.isNegative && !second.isNegative) ||
        (!first.isPositive && !second.isPositive)) {
      return first + second;
    }

    final ta = <BigInt>[
      a[offset] * a[offset] * b[offset] +
          a[offset + 1] * a[offset + 1] * b[offset + 1] -
          a[offset + 2] * a[offset + 2] * b[offset + 2],
      a[offset] * a[offset + 1] * BigInt.two,
    ];
    final tb = <BigInt>[
      BigInt.one,
      b[offset] * b[offset + 1],
    ];
    return eval2(ta, tb) / (first - second);
  }

  BoostExtendedExponentFpt2 eval4(List<BigInt> a, List<BigInt> b,
      [int offset = 0]) {
    final first = eval2(a, b, offset);
    final second = eval2(a, b, offset + 2);
    if ((!first.isNegative && !second.isNegative) ||
        (!first.isPositive && !second.isPositive)) {
      return first + second;
    }

    final ta = <BigInt>[
      a[offset] * a[offset] * b[offset] +
          a[offset + 1] * a[offset + 1] * b[offset + 1] -
          a[offset + 2] * a[offset + 2] * b[offset + 2] -
          a[offset + 3] * a[offset + 3] * b[offset + 3],
      a[offset] * a[offset + 1] * BigInt.two,
      a[offset + 2] * a[offset + 3] * BigInt.from(-2),
    ];
    final tb = <BigInt>[
      BigInt.one,
      b[offset] * b[offset + 1],
      b[offset + 2] * b[offset + 3],
    ];
    return eval3(ta, tb) / (first - second);
  }
}
