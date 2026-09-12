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

class FlowWidthOption {
  const FlowWidthOption(this.value, {this.percent = false});

  final double value;
  final bool percent;

  double absoluteValue(double ratioOver) =>
      percent ? ratioOver * value / 100 : value;
}

class FlowConfigSnapshot {
  const FlowConfigSnapshot({
    required this.widthOptions,
    required this.scalarOptions,
    required this.nozzleDiameters,
  });

  final Map<String, FlowWidthOption> widthOptions;
  final Map<String, double> scalarOptions;
  final List<double> nozzleDiameters;
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

/// Pure-Dart port of `libslic3r/Flow.hpp` + the mathematical/config-width
/// portions of `Flow.cpp` from the supplied Qidi Flow source tree.
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

  /// Port of both `Flow::extrusion_width()` overloads after the source config
  /// values have been represented by [FlowConfigSnapshot].
  static double resolveExtrusionWidth(
    String optionKey,
    FlowConfigSnapshot config, {
    int firstPrintingExtruder = 0,
  }) {
    final original = config.widthOptions[optionKey];
    if (original == null) {
      throw FlowException(
        'Failed to calculate line width of $optionKey. Can not get value of "$optionKey" ',
      );
    }

    var option = original;
    var firstLayer = optionKey.startsWith('initial_layer_');

    if (option.value == 0) {
      final fallback = config.widthOptions['line_width'];
      if (fallback == null) {
        throw FlowException(
          'Failed to calculate line width of $optionKey. Can not get value of "line_width" ',
        );
      }
      option = fallback;
      // Exact source behavior: a role-specific zero falls back to line_width
      // and stops using initial_layer_print_height for percentage resolution.
      firstLayer = false;
    }

    if (option.percent) {
      final heightKey = firstLayer
          ? 'initial_layer_print_height'
          : 'layer_height';
      final base = config.scalarOptions[heightKey];
      if (base == null) {
        throw FlowException(
          'Failed to calculate line width of $optionKey. Can not get value of "$heightKey" ',
        );
      }
      return option.absoluteValue(base);
    }

    if (option.value == 0) {
      if (firstPrintingExtruder < 0 ||
          firstPrintingExtruder >= config.nozzleDiameters.length) {
        throw FlowException(
          'Failed to calculate line width of $optionKey. Can not get value of "nozzle_diameter" ',
        );
      }
      return autoExtrusionWidth(
        _flowRoleForOptionKey(optionKey),
        config.nozzleDiameters[firstPrintingExtruder],
      );
    }

    return option.value;
  }

  static FlowRole _flowRoleForOptionKey(String optionKey) {
    switch (optionKey) {
      case 'inner_wall_line_width':
      case 'line_width':
      case 'initial_layer_line_width':
        return FlowRole.perimeter;
      case 'outer_wall_line_width':
        return FlowRole.externalPerimeter;
      case 'sparse_infill_line_width':
        return FlowRole.infill;
      case 'internal_solid_infill_line_width':
        return FlowRole.solidInfill;
      case 'top_surface_line_width':
        return FlowRole.topSolidInfill;
      case 'support_line_width':
        return FlowRole.supportMaterial;
      default:
        throw ArgumentError.value(
          optionKey,
          'optionKey',
          'opt_key_to_flow_role: invalid argument',
        );
    }
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
