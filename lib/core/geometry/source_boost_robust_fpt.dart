import 'dart:math' as math;

/// Port of Boost.Polygon 1.83 `detail::robust_fpt<double>`.
class BoostRobustFpt2 {
  const BoostRobustFpt2(this.fpv, [this.re = 0]);

  static const double roundingError = 1;

  final double fpv;
  final double re;

  double get ulp => re;
  bool get isPositive => fpv > 0;
  bool get isNegative => fpv < 0;
  bool get isZero => fpv == 0;

  BoostRobustFpt2 operator -() => BoostRobustFpt2(-fpv, re);

  BoostRobustFpt2 operator +(BoostRobustFpt2 other) {
    final value = fpv + other.fpv;
    double error;
    if ((!isNegative && !other.isNegative) ||
        (!isPositive && !other.isPositive)) {
      error = math.max(re, other.re) + roundingError;
    } else {
      var temp = (fpv * re - other.fpv * other.re) / value;
      if (temp < 0) temp = -temp;
      error = temp + roundingError;
    }
    return BoostRobustFpt2(value, error);
  }

  BoostRobustFpt2 operator -(BoostRobustFpt2 other) {
    final value = fpv - other.fpv;
    double error;
    if ((!isNegative && !other.isPositive) ||
        (!isPositive && !other.isNegative)) {
      error = math.max(re, other.re) + roundingError;
    } else {
      var temp = (fpv * re + other.fpv * other.re) / value;
      if (temp < 0) temp = -temp;
      error = temp + roundingError;
    }
    return BoostRobustFpt2(value, error);
  }

  BoostRobustFpt2 operator *(BoostRobustFpt2 other) =>
      BoostRobustFpt2(fpv * other.fpv, re + other.re + roundingError);

  BoostRobustFpt2 operator /(BoostRobustFpt2 other) =>
      BoostRobustFpt2(fpv / other.fpv, re + other.re + roundingError);

  BoostRobustFpt2 sqrt() => BoostRobustFpt2(
        math.sqrt(fpv),
        re * 0.5 + roundingError,
      );

  @override
  String toString() => 'BoostRobustFpt2(fpv=$fpv,re=$re)';
}

/// Port of Boost.Polygon 1.83 `detail::robust_dif<robust_fpt<double>>`.
/// The represented expression is `positiveSum - negativeSum`; all arithmetic
/// preserves those two sums until [difference] is explicitly requested.
class BoostRobustDif2 {
  BoostRobustDif2()
      : positiveSum = const BoostRobustFpt2(0),
        negativeSum = const BoostRobustFpt2(0);

  BoostRobustDif2.fromValue(BoostRobustFpt2 value)
      : positiveSum = value.isPositive ? value : const BoostRobustFpt2(0),
        negativeSum = value.isNegative ? -value : const BoostRobustFpt2(0);

  BoostRobustDif2.fromParts(this.positiveSum, this.negativeSum);

  BoostRobustFpt2 positiveSum;
  BoostRobustFpt2 negativeSum;

  BoostRobustFpt2 get difference => positiveSum - negativeSum;
  BoostRobustFpt2 get positive => positiveSum;
  BoostRobustFpt2 get negative => negativeSum;

  BoostRobustDif2 negated() =>
      BoostRobustDif2.fromParts(negativeSum, positiveSum);

  BoostRobustDif2 addValue(BoostRobustFpt2 value) {
    if (!value.isNegative) {
      positiveSum = positiveSum + value;
    } else {
      negativeSum = negativeSum - value;
    }
    return this;
  }

  BoostRobustDif2 addDif(BoostRobustDif2 other) {
    positiveSum = positiveSum + other.positiveSum;
    negativeSum = negativeSum + other.negativeSum;
    return this;
  }

  BoostRobustDif2 subtractValue(BoostRobustFpt2 value) {
    if (!value.isNegative) {
      negativeSum = negativeSum + value;
    } else {
      positiveSum = positiveSum - value;
    }
    return this;
  }

  BoostRobustDif2 subtractDif(BoostRobustDif2 other) {
    positiveSum = positiveSum + other.negativeSum;
    negativeSum = negativeSum + other.positiveSum;
    return this;
  }

  BoostRobustDif2 multiplyValue(BoostRobustFpt2 value) {
    if (!value.isNegative) {
      positiveSum = positiveSum * value;
      negativeSum = negativeSum * value;
    } else {
      positiveSum = positiveSum * -value;
      negativeSum = negativeSum * -value;
      _swap();
    }
    return this;
  }

  BoostRobustDif2 multiplyDif(BoostRobustDif2 other) {
    final positive = positiveSum * other.positiveSum +
        negativeSum * other.negativeSum;
    final negative = positiveSum * other.negativeSum +
        negativeSum * other.positiveSum;
    positiveSum = positive;
    negativeSum = negative;
    return this;
  }

  BoostRobustDif2 divideValue(BoostRobustFpt2 value) {
    if (!value.isNegative) {
      positiveSum = positiveSum / value;
      negativeSum = negativeSum / value;
    } else {
      positiveSum = positiveSum / -value;
      negativeSum = negativeSum / -value;
      _swap();
    }
    return this;
  }

  BoostRobustDif2 copy() =>
      BoostRobustDif2.fromParts(positiveSum, negativeSum);

  static BoostRobustDif2 add(BoostRobustDif2 a, BoostRobustDif2 b) =>
      BoostRobustDif2.fromParts(
        a.positiveSum + b.positiveSum,
        a.negativeSum + b.negativeSum,
      );

  static BoostRobustDif2 addValueToDif(
    BoostRobustDif2 a,
    BoostRobustFpt2 value,
  ) =>
      a.copy()..addValue(value);

  static BoostRobustDif2 subtract(BoostRobustDif2 a, BoostRobustDif2 b) =>
      BoostRobustDif2.fromParts(
        a.positiveSum + b.negativeSum,
        a.negativeSum + b.positiveSum,
      );

  static BoostRobustDif2 multiply(
    BoostRobustDif2 a,
    BoostRobustDif2 b,
  ) =>
      BoostRobustDif2.fromParts(
        a.positiveSum * b.positiveSum + a.negativeSum * b.negativeSum,
        a.positiveSum * b.negativeSum + a.negativeSum * b.positiveSum,
      );

  static BoostRobustDif2 multiplyByValue(
    BoostRobustDif2 a,
    BoostRobustFpt2 value,
  ) {
    if (!value.isNegative) {
      return BoostRobustDif2.fromParts(
        a.positiveSum * value,
        a.negativeSum * value,
      );
    }
    return BoostRobustDif2.fromParts(
      a.negativeSum * -value,
      a.positiveSum * -value,
    );
  }

  static BoostRobustDif2 divideByValue(
    BoostRobustDif2 a,
    BoostRobustFpt2 value,
  ) {
    if (!value.isNegative) {
      return BoostRobustDif2.fromParts(
        a.positiveSum / value,
        a.negativeSum / value,
      );
    }
    return BoostRobustDif2.fromParts(
      a.negativeSum / -value,
      a.positiveSum / -value,
    );
  }

  void _swap() {
    final temp = positiveSum;
    positiveSum = negativeSum;
    negativeSum = temp;
  }
}
