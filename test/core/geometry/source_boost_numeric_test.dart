import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_extended_numeric.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_robust_fpt.dart';

void main() {
  group('Boost 1.83 robust_fpt C++ oracle goldens', () {
    const a = BoostRobustFpt2(10, 2);
    const b = BoostRobustFpt2(-3, 4);

    test('addition/subtraction error propagation matches oracle', () {
      final add = a + b;
      expect(add.fpv, 7);
      expect(add.re, closeTo(5.5714285714285712, 1e-15));

      final subtract = a - b;
      expect(subtract.fpv, 13);
      expect(subtract.re, 5);
    });

    test('multiply/divide/sqrt error propagation matches oracle', () {
      final multiply = a * b;
      expect(multiply.fpv, -30);
      expect(multiply.re, 7);

      final divide = a / const BoostRobustFpt2(2, 1);
      expect(divide.fpv, 5);
      expect(divide.re, 4);

      final root = a.sqrt();
      expect(root.fpv, closeTo(3.1622776601683795, 1e-15));
      expect(root.re, 2);
    });

    test('robust_dif keeps positive/negative sums before cancellation', () {
      final difference = BoostRobustDif2()
        ..addValue(const BoostRobustFpt2(10, 1))
        ..subtractValue(const BoostRobustFpt2(3, 2));

      expect(difference.positive.fpv, 10);
      expect(difference.positive.re, 2);
      expect(difference.negative.fpv, 3);
      expect(difference.negative.re, 3);
      expect(difference.difference.fpv, 7);
      expect(
        difference.difference.re,
        closeTo(5.1428571428571432, 1e-15),
      );
    });
  });

  group('Boost extended_int / robust_sqrt_expr C++ oracle goldens', () {
    test('BigInt converter preserves top-three-chunk + exponent contract', () {
      final value = BigInt.parse('123456789abcdef013579bdf2468ace0', radix: 16);
      final pair = BoostBigIntConverter2.pair(value);
      expect(pair.value, closeTo(5.6340026676810196e27, 1e12));
      expect(pair.exponent, 32);
      expect(
        BoostBigIntConverter2.toDouble(value),
        closeTo(2.4197857203266735e37, 1e22),
      );
    });

    test('robust_sqrt_expr eval1..eval4 match Boost oracle', () {
      final a = [
        BigInt.from(3),
        BigInt.from(-2),
        BigInt.from(5),
        BigInt.from(-7),
      ];
      final b = [
        BigInt.from(4),
        BigInt.from(9),
        BigInt.from(16),
        BigInt.from(25),
      ];
      final expression = BoostRobustSqrtExpr2();
      expect(expression.eval1(a, b).toDouble(), 6);
      expect(expression.eval2(a, b).toDouble(), 0);
      expect(expression.eval3(a, b).toDouble(), 20);
      expect(expression.eval4(a, b).toDouble(), -15);
    });
  });
}
