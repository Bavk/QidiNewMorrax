import 'dart:math' as math;

enum FlowRole {
  externalPerimeter,
  perimeter,
  infill,
  solidInfill,
  topSolidInfill,
  supportMaterial,
  supportMaterialInterface,
  supportTransition,
}

class FlowException implements Exception {
  const FlowException(this.message);
  final String message;
  @override
  String toString() => 'FlowException: $message';
}

class FlowNegativeSpacingException extends FlowException {
  const FlowNegativeSpacingException()
      : super(
          'Flow::spacing() produced negative spacing. Did you set some extrusion width too small?',
        );
}

class FlowNegativeFlowException extends FlowException {
  const FlowNegativeFlowException()
      : super(
          'Flow::mm3_per_mm() produced negative flow. Did you set some extrusion width too small?',
        );
}

class FlowSlicingException extends FlowException {
  const FlowSlicingException()
      : super(
          'Slicing failed because the extrusion line width is too small or the layer height is too large.\n\n'
          'Please increase the line width or reduce the layer height, then slice again.',
        );
}

/// Pure-Dart port of `libslic3r/Flow.hpp` + the mathematical portion of
/// `Flow.cpp` from the supplied Qidi Flow source tree.
///
/// Keep source quirks intact: methods such as [withCrossSection] intentionally
/// reproduce the supplied formulas rather than silently replacing them with a
/// mathematically cleaner model.
class Flow {
  const Flow._({
    required this.width,
    required this.height,
    required this.spacing,
    required this.nozzleDiameter,
    required this.bridge,
  });

  factory Flow.nonBridging({
    required double width,
    required double height,
    required double nozzleDiameter,
  }) {
    return Flow._(
      width: width,
      height: height,
      spacing: roundedRectangleExtrusionSpacing(width, height),
      nozzleDiameter: nozzleDiameter,
      bridge: false,
    );
  }

  factory Flow.newFromConfigWidth({
    required FlowRole role,
    required double configuredWidth,
    required double nozzleDiameter,
    required double height,
  }) {
    if (height <= 0) {
      throw ArgumentError.value(
        height,
        'height',
        'Invalid flow height supplied to newFromConfigWidth()',
      );
    }
    final width = configuredWidth == 0
        ? autoExtrusionWidth(role, nozzleDiameter)
        : configuredWidth;
    return Flow.nonBridging(
      width: width,
      height: height,
      nozzleDiameter: nozzleDiameter,
    );
  }

  factory Flow.bridging({
    required double diameter,
    required double nozzleDiameter,
  }) {
    return Flow._(
      width: diameter,
      height: diameter,
      spacing: bridgeExtrusionSpacing(diameter),
      nozzleDiameter: nozzleDiameter,
      bridge: true,
    );
  }

  static const double bridgeExtraSpacing = 0.05;
  static const double epsilon = 1e-4;
  static const double scalingFactor = 0.00001;

  final double width;
  final double height;
  final double spacing;
  final double nozzleDiameter;
  final bool bridge;

  int get scaledWidth => (width / scalingFactor).truncate();
  int get scaledSpacing => (spacing / scalingFactor).truncate();

  int get scaledElephantFootSpacing =>
      (0.5 * (scaledWidth + 0.6 * scaledSpacing)).truncate();

  double get mm3PerMm {
    final result = bridge
        ? width * width * 0.25 * math.pi
        : height * (width - height * (1 - 0.25 * math.pi));
    if (result <= 0) throw const FlowNegativeFlowException();
    return result;
  }

  static double autoExtrusionWidth(FlowRole role, double nozzleDiameter) {
    switch (role) {
      case FlowRole.supportMaterial:
      case FlowRole.supportMaterialInterface:
      case FlowRole.supportTransition:
      case FlowRole.topSolidInfill:
        return nozzleDiameter;
      case FlowRole.externalPerimeter:
      case FlowRole.perimeter:
      case FlowRole.solidInfill:
      case FlowRole.infill:
        return 1.125 * nozzleDiameter;
    }
  }

  static double roundedRectangleExtrusionSpacing(
    double width,
    double height,
  ) {
    final output = width - height * (1 - 0.25 * math.pi);
    if (output <= 0) throw const FlowNegativeSpacingException();
    return output;
  }

  static double roundedRectangleExtrusionWidthFromSpacing(
    double spacing,
    double height,
  ) =>
      spacing + height * (1 - 0.25 * math.pi);

  static double bridgeExtrusionSpacing(double diameter) =>
      diameter + bridgeExtraSpacing;

  Flow withWidth(double newWidth) {
    if (bridge) {
      throw StateError('Flow::with_width() is invalid for bridging flow');
    }
    return Flow._(
      width: newWidth,
      height: height,
      spacing: roundedRectangleExtrusionSpacing(newWidth, height),
      nozzleDiameter: nozzleDiameter,
      bridge: bridge,
    );
  }

  Flow withHeight(double newHeight) {
    if (bridge) {
      throw StateError('Flow::with_height() is invalid for bridging flow');
    }
    return Flow._(
      width: width,
      height: newHeight,
      spacing: roundedRectangleExtrusionSpacing(width, newHeight),
      nozzleDiameter: nozzleDiameter,
      bridge: bridge,
    );
  }

  /// Port of `Flow::with_spacing()`.
  Flow withSpacing(double newSpacing) {
    if (bridge) {
      final gap = spacing - width;
      final newDiameter = newSpacing - gap;
      return Flow._(
        width: newDiameter,
        height: newDiameter,
        spacing: newSpacing,
        nozzleDiameter: nozzleDiameter,
        bridge: true,
      );
    }

    final newWidth = width + newSpacing - spacing;
    if (newWidth < height) throw const FlowSlicingException();
    return Flow._(
      width: newWidth,
      height: height,
      spacing: newSpacing,
      nozzleDiameter: nozzleDiameter,
      bridge: false,
    );
  }

  /// Exact port of the supplied source's `Flow::with_cross_section()` branch
  /// formulas, including source quirks.
  Flow withCrossSection(double newArea) {
    if (bridge) {
      throw StateError('Flow::with_cross_section() is invalid for bridging flow');
    }
    if (width < height) {
      throw StateError('Flow::with_cross_section() requires width >= height');
    }

    final area = mm3PerMm;
    if (newArea > area + epsilon) {
      final newFullSpacing = newArea / height;
      if (newFullSpacing > spacing) {
        final newHeight = newArea / spacing;
        return Flow._(
          width: roundedRectangleExtrusionWidthFromSpacing(spacing, newHeight),
          height: newHeight,
          spacing: spacing,
          nozzleDiameter: nozzleDiameter,
          bridge: false,
        );
      }
      // The supplied source intentionally uses `area / m_height` here rather
      // than `area_new / m_height`; preserve that behavior 1:1.
      return withWidth(
        roundedRectangleExtrusionWidthFromSpacing(area / height, height),
      );
    }

    if (newArea < area - epsilon) {
      final newWidth = width - (area - newArea) / height;
      if (newWidth <= 0) {
        throw ArgumentError.value(newArea, 'newArea', 'produces non-positive width');
      }
      if (newWidth > height) return withWidth(newWidth);

      // Preserve the exact supplied source formula.
      final diameter = math.sqrt(newArea / math.pi);
      return Flow._(
        width: diameter,
        height: diameter,
        spacing: spacing,
        nozzleDiameter: nozzleDiameter,
        bridge: false,
      );
    }

    return this;
  }

  Flow withFlowRatio(double ratio) => withCrossSection(mm3PerMm * ratio);
}
