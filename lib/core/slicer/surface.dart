import '../geometry/source_polygon.dart';

enum SurfaceType {
  top,
  bottom,
  bottomBridge,
  internal,
  floatingVerticalShell,
  internalSolid,
  internalBridge,
  internalVoid,
  perimeter,
}

/// Source-shaped port of `libslic3r/Surface.hpp`.
class Surface2 {
  Surface2({
    this.surfaceType = SurfaceType.internal,
    SourceExPolygon2? expolygon,
    this.thickness = -1,
    this.thicknessLayers = 1,
    this.bridgeAngle = -1,
    this.extraPerimeters = 0,
    this.counterCircleCompensation = false,
    Iterable<int> holesCircleCompensation = const [],
  })  : expolygon = expolygon ?? _emptyExPolygon(),
        holesCircleCompensation = List<int>.of(holesCircleCompensation);

  SurfaceType surfaceType;
  SourceExPolygon2 expolygon;
  double thickness;
  int thicknessLayers;
  double bridgeAngle;
  int extraPerimeters;

  // QIDI additions present in the supplied source.
  bool counterCircleCompensation;
  final List<int> holesCircleCompensation;

  /// Exact source copy-constructor semantics.
  ///
  /// The supplied C++ copy constructor explicitly copies fields only through
  /// `extra_perimeters`. QIDI circle-compensation members are omitted and thus
  /// receive their member-initializer defaults (false / empty).
  factory Surface2.sourceCopy(Surface2 source) => Surface2(
        surfaceType: source.surfaceType,
        expolygon: source.expolygon,
        thickness: source.thickness,
        thicknessLayers: source.thicknessLayers,
        bridgeAngle: source.bridgeAngle,
        extraPerimeters: source.extraPerimeters,
      );

  /// Mirrors `Surface(const Surface &other, const ExPolygon &_expolygon)`.
  factory Surface2.sourceCopyWithExPolygon(
    Surface2 source,
    SourceExPolygon2 expolygon,
  ) =>
      Surface2(
        surfaceType: source.surfaceType,
        expolygon: expolygon,
        thickness: source.thickness,
        thicknessLayers: source.thicknessLayers,
        bridgeAngle: source.bridgeAngle,
        extraPerimeters: source.extraPerimeters,
      );

  /// Mirrors the supplied `Surface::operator=(const Surface&)` quirk: circle
  /// compensation members are not assigned and retain their destination state.
  void sourceAssignFrom(Surface2 source) {
    surfaceType = source.surfaceType;
    expolygon = source.expolygon;
    thickness = source.thickness;
    thicknessLayers = source.thicknessLayers;
    bridgeAngle = source.bridgeAngle;
    extraPerimeters = source.extraPerimeters;
  }

  double get area => expolygon.area;
  bool get isEmpty => expolygon.contour.points.isEmpty;

  void clear() {
    expolygon = _emptyExPolygon();
  }

  // The source comments explicitly note that these methods do not special-case
  // stPerimeter. Preserve that classification exactly.
  bool get isTop => surfaceType == SurfaceType.top;
  bool get isBottom =>
      surfaceType == SurfaceType.bottom ||
      surfaceType == SurfaceType.bottomBridge;
  bool get isBridge =>
      surfaceType == SurfaceType.bottomBridge ||
      surfaceType == SurfaceType.internalBridge;
  bool get isExternal => isTop || isBottom;
  bool get isInternal => !isExternal;
  bool get isFloatingVerticalShell =>
      surfaceType == SurfaceType.floatingVerticalShell;
  bool get isSolid =>
      isExternal ||
      isFloatingVerticalShell ||
      surfaceType == SurfaceType.internalSolid ||
      surfaceType == SurfaceType.internalBridge;
  bool get isSolidInfill => surfaceType == SurfaceType.internalSolid;

  static SourceExPolygon2 _emptyExPolygon() =>
      SourceExPolygon2(contour: SourcePolygon2(const []));
}

List<SourcePolygon2> surfaceToPolygons(Surface2 surface) => [
      surface.expolygon.contour,
      ...surface.expolygon.holes,
    ];

List<SourcePolygon2> surfacesToPolygons(Iterable<Surface2> surfaces) => [
      for (final surface in surfaces) ...surfaceToPolygons(surface),
    ];

List<SourceExPolygon2> surfacesToExPolygons(Iterable<Surface2> surfaces) =>
    [for (final surface in surfaces) surface.expolygon];

int numberSurfacePolygons(Iterable<Surface2> surfaces) {
  var count = 0;
  for (final surface in surfaces) {
    count += surface.expolygon.holes.length + 1;
  }
  return count;
}

void appendSurfacesFromExPolygons(
  List<Surface2> destination,
  Iterable<SourceExPolygon2> source,
  SurfaceType surfaceType,
) {
  for (final expolygon in source) {
    destination.add(
      Surface2(surfaceType: surfaceType, expolygon: expolygon),
    );
  }
}

/// Exact supplied source predicate. Notice that `extraPerimeters` and QIDI
/// circle-compensation fields are intentionally not part of merge eligibility.
bool surfacesCouldMerge(Surface2 a, Surface2 b) =>
    a.surfaceType == b.surfaceType &&
    a.thickness == b.thickness &&
    a.thicknessLayers == b.thicknessLayers &&
    a.bridgeAngle == b.bridgeAngle;

String surfaceTypeToColorName(SurfaceType? surfaceType) {
  switch (surfaceType) {
    case SurfaceType.top:
      return 'rgb(255,0,0)';
    case SurfaceType.bottom:
      return 'rgb(0,255,0)';
    case SurfaceType.bottomBridge:
      return 'rgb(0,0,255)';
    case SurfaceType.internal:
      return 'rgb(255,255,128)';
    case SurfaceType.floatingVerticalShell:
    case SurfaceType.internalSolid:
      return 'rgb(255,0,255)';
    case SurfaceType.internalBridge:
      return 'rgb(0,255,255)';
    case SurfaceType.internalVoid:
      return 'rgb(128,128,128)';
    case SurfaceType.perimeter:
      return 'rgb(128,0,0)';
    case null:
      return 'rgb(64,64,64)';
  }
}
