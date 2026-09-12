import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import '../geometry/source_polyline.dart';

enum ExtrusionRole {
  none,
  perimeter,
  externalPerimeter,
  overhangPerimeter,
  internalInfill,
  solidInfill,
  floatingVerticalShell,
  topSolidInfill,
  bottomSurface,
  ironing,
  bridgeInfill,
  gapFill,
  skirt,
  brim,
  supportMaterial,
  supportMaterialInterface,
  supportTransition,
  supportIroning,
  wipeTower,
  custom,
  flush,
  mixed,
  count,
}

enum CustomizeFlag { none, circleCompensation, floatingVerticalShell }

class ExtrusionLoopRoles {
  const ExtrusionLoopRoles._();
  static const int defaultRole = 1 << 0;
  static const int contourInternalPerimeter = 1 << 1;
  static const int skirt = 1 << 2;
  static const int perimeterHole = 1 << 3;
  static const int secondPerimeter = 1 << 4;
}

bool isPerimeterRole(ExtrusionRole role) =>
    role == ExtrusionRole.perimeter ||
    role == ExtrusionRole.externalPerimeter ||
    role == ExtrusionRole.overhangPerimeter;

bool isInfillRole(ExtrusionRole role) =>
    role == ExtrusionRole.bridgeInfill ||
    role == ExtrusionRole.internalInfill ||
    role == ExtrusionRole.solidInfill ||
    role == ExtrusionRole.floatingVerticalShell ||
    role == ExtrusionRole.topSolidInfill ||
    role == ExtrusionRole.bottomSurface ||
    role == ExtrusionRole.ironing;

bool isTopSurfaceRole(ExtrusionRole role) =>
    role == ExtrusionRole.topSolidInfill;

bool isSolidInfillRole(ExtrusionRole role) =>
    role == ExtrusionRole.bridgeInfill ||
    role == ExtrusionRole.solidInfill ||
    role == ExtrusionRole.floatingVerticalShell ||
    role == ExtrusionRole.topSolidInfill ||
    role == ExtrusionRole.bottomSurface ||
    role == ExtrusionRole.ironing;

bool isBridgeRole(ExtrusionRole role) =>
    role == ExtrusionRole.bridgeInfill ||
    role == ExtrusionRole.overhangPerimeter;

bool isSupportRole(ExtrusionRole role) =>
    role == ExtrusionRole.supportMaterial ||
    role == ExtrusionRole.supportMaterialInterface ||
    role == ExtrusionRole.supportTransition ||
    role == ExtrusionRole.supportIroning;

String extrusionRoleToString(ExtrusionRole role) {
  switch (role) {
    case ExtrusionRole.none:
      return 'Undefined';
    case ExtrusionRole.perimeter:
      return 'Inner wall';
    case ExtrusionRole.externalPerimeter:
      return 'Outer wall';
    case ExtrusionRole.overhangPerimeter:
      return 'Overhang wall';
    case ExtrusionRole.internalInfill:
      return 'Sparse infill';
    case ExtrusionRole.floatingVerticalShell:
      return 'Floating vertical shell';
    case ExtrusionRole.solidInfill:
      return 'Internal solid infill';
    case ExtrusionRole.topSolidInfill:
      return 'Top surface';
    case ExtrusionRole.bottomSurface:
      return 'Bottom surface';
    case ExtrusionRole.ironing:
      return 'Ironing';
    case ExtrusionRole.supportIroning:
      return 'Support ironing';
    case ExtrusionRole.bridgeInfill:
      return 'Bridge';
    case ExtrusionRole.gapFill:
      return 'Gap infill';
    case ExtrusionRole.skirt:
      return 'Skirt';
    case ExtrusionRole.brim:
      return 'Brim';
    case ExtrusionRole.supportMaterial:
      return 'Support';
    case ExtrusionRole.supportMaterialInterface:
      return 'Support interface';
    case ExtrusionRole.supportTransition:
      return 'Support transition';
    case ExtrusionRole.wipeTower:
      return 'Prime tower';
    case ExtrusionRole.custom:
      return 'Custom';
    case ExtrusionRole.mixed:
      return 'Multiple';
    case ExtrusionRole.flush:
      return 'Flush';
    case ExtrusionRole.count:
      throw ArgumentError('erCount has no source display string');
  }
}

ExtrusionRole extrusionRoleFromString(String value) {
  for (final role in ExtrusionRole.values) {
    if (role == ExtrusionRole.count) continue;
    if (extrusionRoleToString(role) == value) return role;
  }
  return ExtrusionRole.none;
}

abstract class ExtrusionEntity2 {
  ExtrusionEntity2({
    this.customizeFlag = CustomizeFlag.none,
    this.coolingNode = -1,
  });

  CustomizeFlag customizeFlag;
  int coolingNode;

  ExtrusionRole get role;
  bool get isCollection => false;
  bool get isLoop => false;
  bool get canReverse => true;
  bool get canSort => true;
  void setReverseAllowedFalse() {}

  ExtrusionEntity2 cloneEntity();
  void reverse();
  SourcePoint2 get firstPoint;
  SourcePoint2 get lastPoint;
  double get minMm3PerMm;
  SourcePolyline2 asPolyline();
  void collectPolylines(List<SourcePolyline2> destination);
  void collectPoints(List<SourcePoint2> destination);
  double get length;
  double get totalVolume;
}

class ExtrusionPath2 extends ExtrusionEntity2 {
  ExtrusionPath2({
    SourcePolyline2? polyline,
    this.overhangDegree = 0,
    this.curveDegree = 0,
    this.mm3PerMm = -1,
    this.width = -1,
    this.height = -1,
    this.smoothSpeed = 0,
    ExtrusionRole role = ExtrusionRole.none,
    bool forceNoExtrusion = false,
    bool canReverse = true,
    super.customizeFlag,
    super.coolingNode,
  })  : polyline = polyline ?? SourcePolyline2(),
        _role = role,
        _forceNoExtrusion = forceNoExtrusion,
        _canReverse = canReverse;

  final SourcePolyline2 polyline;
  double overhangDegree;
  int curveDegree;
  double mm3PerMm;
  double width;
  double height;
  double smoothSpeed;
  bool _canReverse;
  ExtrusionRole _role;
  bool _forceNoExtrusion;

  factory ExtrusionPath2.sourceCopy(ExtrusionPath2 source) => ExtrusionPath2(
        polyline: source.polyline.copy(),
        overhangDegree: source.overhangDegree,
        curveDegree: source.curveDegree,
        mm3PerMm: source.mm3PerMm,
        width: source.width,
        height: source.height,
        smoothSpeed: source.smoothSpeed,
        role: source.role,
        forceNoExtrusion: source._forceNoExtrusion,
        canReverse: source._canReverse,
        customizeFlag: source.customizeFlag,
        coolingNode: source.coolingNode,
      );

  factory ExtrusionPath2.sourceCopyWithPolyline(
    ExtrusionPath2 source,
    SourcePolyline2 polyline,
  ) =>
      ExtrusionPath2(
        polyline: polyline.copy(),
        overhangDegree: source.overhangDegree,
        curveDegree: source.curveDegree,
        mm3PerMm: source.mm3PerMm,
        width: source.width,
        height: source.height,
        smoothSpeed: source.smoothSpeed,
        role: source.role,
        forceNoExtrusion: source._forceNoExtrusion,
        canReverse: source._canReverse,
        customizeFlag: source.customizeFlag,
        coolingNode: source.coolingNode,
      );

  @override
  ExtrusionRole get role => _role;

  void setExtrusionRole(ExtrusionRole role) => _role = role;

  @override
  bool get canReverse => _canReverse;

  @override
  void setReverseAllowedFalse() => _canReverse = false;

  bool get isForceNoExtrusion => _forceNoExtrusion;
  void setForceNoExtrusion(bool value) => _forceNoExtrusion = value;

  @override
  ExtrusionPath2 cloneEntity() => ExtrusionPath2.sourceCopy(this);

  @override
  void reverse() => polyline.reverse();

  @override
  SourcePoint2 get firstPoint => polyline.firstPoint;

  @override
  SourcePoint2 get lastPoint => polyline.lastPoint;

  bool get isClosed => polyline.isClosed;
  bool get isEmpty => polyline.isEmpty;
  int get size => polyline.lengthInPoints;

  void clipEnd(double distance) => polyline.clipEnd(distance);

  @override
  double get length => polyline.length;

  @override
  double get minMm3PerMm => mm3PerMm;

  @override
  SourcePolyline2 asPolyline() => polyline.copy();

  @override
  void collectPolylines(List<SourcePolyline2> destination) {
    if (!polyline.isEmpty) destination.add(polyline.copy());
  }

  @override
  void collectPoints(List<SourcePoint2> destination) =>
      destination.addAll(polyline.points);

  @override
  double get totalVolume =>
      mm3PerMm * Slic3rUnits.unscaleDouble(length);

  void setOverhangDegree(int overhang) {
    if (isPerimeterRole(role) || isSupportRole(role)) {
      overhangDegree = overhang < 0 ? 0 : (overhang > 10 ? 10 : overhang);
    }
  }

  int getOverhangDegree() {
    if (isPerimeterRole(role) || isSupportRole(role)) {
      return overhangDegree.truncate();
    }
    return 0;
  }

  void setCurveDegree(int curve) {
    curveDegree = curve < 0 ? 0 : (curve > 10 ? 10 : curve);
  }

  int getCurveDegree() => curveDegree;

  bool canMerge(ExtrusionPath2 other) =>
      curveDegree == other.curveDegree &&
      mm3PerMm == other.mm3PerMm &&
      width == other.width &&
      height == other.height &&
      _canReverse == other._canReverse &&
      _role == other._role &&
      _forceNoExtrusion == other._forceNoExtrusion &&
      smoothSpeed == other.smoothSpeed;
}

class ExtrusionSlope2 {
  const ExtrusionSlope2({
    this.zRatio = 1,
    this.eRatio = 1,
    this.speedRecord = 0,
  });

  final double zRatio;
  final double eRatio;
  final double speedRecord;

  static ExtrusionSlope2 interpolate(
    ExtrusionSlope2 begin,
    ExtrusionSlope2 end,
    double ratio,
  ) =>
      ExtrusionSlope2(
        zRatio: _lerp(begin.zRatio, end.zRatio, ratio),
        eRatio: _lerp(begin.eRatio, end.eRatio, ratio),
        speedRecord: _lerp(begin.speedRecord, end.speedRecord, ratio),
      );

  static double _lerp(double a, double b, double ratio) =>
      a + (b - a) * ratio;
}

class ExtrusionPathSloped2 extends ExtrusionPath2 {
  ExtrusionPathSloped2.fromPath(
    ExtrusionPath2 source, {
    required this.slopeBegin,
    required this.slopeEnd,
    SourcePolyline2? replacementPolyline,
  }) : super(
          polyline: replacementPolyline?.copy() ?? source.polyline.copy(),
          overhangDegree: source.overhangDegree,
          curveDegree: source.curveDegree,
          mm3PerMm: source.mm3PerMm,
          width: source.width,
          height: source.height,
          smoothSpeed: source.smoothSpeed,
          role: source.role,
          forceNoExtrusion: source.isForceNoExtrusion,
          canReverse: source.canReverse,
          customizeFlag: source.customizeFlag,
          coolingNode: source.coolingNode,
        );

  final ExtrusionSlope2 slopeBegin;
  final ExtrusionSlope2 slopeEnd;

  ExtrusionSlope2 interpolate(double ratio) =>
      ExtrusionSlope2.interpolate(slopeBegin, slopeEnd, ratio);

  bool get isFlat =>
      (slopeBegin.zRatio - slopeEnd.zRatio).abs() < Slic3rUnits.epsilon;
}

class ExtrusionPathOriented2 extends ExtrusionPath2 {
  ExtrusionPathOriented2({
    required ExtrusionRole role,
    required double mm3PerMm,
    required double width,
    required double height,
    SourcePolyline2? polyline,
  }) : super(
          role: role,
          mm3PerMm: mm3PerMm,
          width: width,
          height: height,
          polyline: polyline,
          canReverse: false,
        );

  factory ExtrusionPathOriented2.sourceCopy(
    ExtrusionPathOriented2 source,
  ) {
    final copy = ExtrusionPathOriented2(
      role: source.role,
      mm3PerMm: source.mm3PerMm,
      width: source.width,
      height: source.height,
      polyline: source.polyline.copy(),
    );
    copy
      ..overhangDegree = source.overhangDegree
      ..curveDegree = source.curveDegree
      ..smoothSpeed = source.smoothSpeed
      ..setForceNoExtrusion(source.isForceNoExtrusion)
      ..customizeFlag = source.customizeFlag
      ..coolingNode = source.coolingNode;
    return copy;
  }

  @override
  bool get canReverse => false;

  @override
  ExtrusionPathOriented2 cloneEntity() =>
      ExtrusionPathOriented2.sourceCopy(this);
}

class ExtrusionMultiPath2 extends ExtrusionEntity2 {
  ExtrusionMultiPath2({
    Iterable<ExtrusionPath2> paths = const [],
    bool canReverse = true,
    super.customizeFlag,
    super.coolingNode,
  })  : paths = [for (final path in paths) ExtrusionPath2.sourceCopy(path)],
        _canReverse = canReverse;

  factory ExtrusionMultiPath2.fromSinglePath(ExtrusionPath2 path) =>
      ExtrusionMultiPath2(paths: [path], canReverse: path.canReverse);

  final List<ExtrusionPath2> paths;
  bool _canReverse;

  @override
  ExtrusionRole get role =>
      paths.isEmpty ? ExtrusionRole.none : paths.first.role;

  @override
  bool get canReverse => _canReverse;

  @override
  void setReverseAllowedFalse() => _canReverse = false;

  @override
  ExtrusionMultiPath2 cloneEntity() =>
      ExtrusionMultiPath2(paths: paths, canReverse: _canReverse);

  @override
  void reverse() {
    for (final path in paths) {
      path.reverse();
    }
    paths.setAll(0, paths.reversed.toList(growable: false));
  }

  @override
  SourcePoint2 get firstPoint => paths.first.polyline.firstPoint;

  @override
  SourcePoint2 get lastPoint => paths.last.polyline.lastPoint;

  bool get isEmpty => paths.isEmpty;
  int get size => paths.length;

  @override
  double get length => paths.fold(0.0, (sum, path) => sum + path.length);

  @override
  double get minMm3PerMm {
    var value = double.maxFinite;
    for (final path in paths) {
      value = math.min(value, path.mm3PerMm);
    }
    return value;
  }

  @override
  SourcePolyline2 asPolyline() {
    final out = SourcePolyline2();
    if (paths.isEmpty) return out;

    var expectedLength = 0;
    for (var i = 0; i < paths.length; i++) {
      final current = paths[i].polyline;
      if (current.points.isEmpty) {
        throw StateError('ExtrusionMultiPath source path must not be empty');
      }
      if (i > 0 && paths[i - 1].polyline.lastPoint != current.firstPoint) {
        throw StateError('ExtrusionMultiPath paths are not continuous');
      }
      expectedLength += current.points.length;
    }
    expectedLength -= paths.length - 1;
    if (expectedLength <= 0) {
      throw StateError('ExtrusionMultiPath source point count must be > 0');
    }

    out.points.add(paths.first.polyline.points.first);
    for (final path in paths) {
      out.points.addAll(path.polyline.points.skip(1));
    }
    return out;
  }

  @override
  void collectPolylines(List<SourcePolyline2> destination) {
    final polyline = asPolyline();
    if (!polyline.isEmpty) destination.add(polyline);
  }

  @override
  void collectPoints(List<SourcePoint2> destination) {
    for (final path in paths) {
      destination.addAll(path.polyline.points);
    }
  }

  @override
  double get totalVolume =>
      paths.fold(0.0, (sum, path) => sum + path.totalVolume);
}

class ExtrusionLoop2 extends ExtrusionEntity2 {
  ExtrusionLoop2({
    Iterable<ExtrusionPath2> paths = const [],
    this.loopRole = ExtrusionLoopRoles.defaultRole,
    super.customizeFlag,
    super.coolingNode,
  }) : paths = [for (final path in paths) ExtrusionPath2.sourceCopy(path)];

  final List<ExtrusionPath2> paths;
  int loopRole;

  @override
  bool get isLoop => true;

  @override
  bool get canReverse => false;

  @override
  ExtrusionRole get role =>
      paths.isEmpty ? ExtrusionRole.none : paths.first.role;

  @override
  ExtrusionLoop2 cloneEntity() => ExtrusionLoop2(
        paths: paths,
        loopRole: loopRole,
        customizeFlag: customizeFlag,
        coolingNode: coolingNode,
      );

  SourcePolygon2 polygon() {
    final points = <SourcePoint2>[];
    for (final path in paths) {
      if (path.polyline.points.isEmpty) {
        throw StateError('ExtrusionLoop source path must not be empty');
      }
      points.addAll(path.polyline.points.take(path.polyline.points.length - 1));
    }
    return SourcePolygon2(points);
  }

  bool makeClockwise() {
    final wasCounterClockwise = polygon().signedArea > 0;
    if (wasCounterClockwise) reverse();
    return wasCounterClockwise;
  }

  bool makeCounterClockwise() {
    final wasClockwise = polygon().signedArea <= 0;
    if (wasClockwise) reverse();
    return wasClockwise;
  }

  bool get isClockwise => polygon().signedArea <= 0;
  bool get isCounterClockwise => polygon().signedArea > 0;

  @override
  void reverse() {
    for (final path in paths) {
      path.reverse();
    }
    paths.setAll(0, paths.reversed.toList(growable: false));
  }

  @override
  SourcePoint2 get firstPoint => paths.first.polyline.firstPoint;

  @override
  SourcePoint2 get lastPoint {
    if (firstPoint != paths.last.polyline.lastPoint) {
      throw StateError('ExtrusionLoop is not closed');
    }
    return firstPoint;
  }

  bool get isSetSpeedDiscontinuityArea =>
      role == ExtrusionRole.externalPerimeter ||
      role == ExtrusionRole.perimeter ||
      role == ExtrusionRole.overhangPerimeter;

  @override
  double get length => paths.fold(0.0, (sum, path) => sum + path.length);

  @override
  double get minMm3PerMm {
    var value = double.maxFinite;
    for (final path in paths) {
      value = math.min(value, path.mm3PerMm);
    }
    return value;
  }

  @override
  SourcePolyline2 asPolyline() {
    final polygonPoints = polygon().points;
    if (polygonPoints.isEmpty) return SourcePolyline2();
    return SourcePolyline2([...polygonPoints, polygonPoints.first]);
  }

  @override
  void collectPolylines(List<SourcePolyline2> destination) {
    final polyline = asPolyline();
    if (!polyline.isEmpty) destination.add(polyline);
  }

  @override
  void collectPoints(List<SourcePoint2> destination) {
    for (final path in paths) {
      destination.addAll(path.polyline.points);
    }
  }

  @override
  double get totalVolume =>
      paths.fold(0.0, (sum, path) => sum + path.totalVolume);
}

class ExtrusionEntityCollection2 extends ExtrusionEntity2 {
  ExtrusionEntityCollection2({
    Iterable<ExtrusionEntity2> entities = const [],
    this.noSort = false,
    bool isReverse = true,
    this.loopNodeRange = const (0, 0),
    super.customizeFlag,
    super.coolingNode,
  })  : entities = [for (final entity in entities) entity.cloneEntity()],
        _isReverse = isReverse;

  final List<ExtrusionEntity2> entities;
  bool noSort;
  bool _isReverse;
  (int, int) loopNodeRange;

  @override
  bool get isCollection => true;

  @override
  ExtrusionRole get role {
    var result = ExtrusionRole.none;
    for (final entity in entities) {
      final entityRole = entity.role;
      result = (result == ExtrusionRole.none || result == entityRole)
          ? entityRole
          : ExtrusionRole.mixed;
    }
    return result;
  }

  @override
  bool get canSort => !noSort;

  @override
  bool get canReverse => noSort ? false : _isReverse;

  @override
  void setReverseAllowedFalse() => _isReverse = false;

  bool get isEmpty => entities.isEmpty;

  void clear() => entities.clear();

  void append(ExtrusionEntity2 entity) => entities.add(entity.cloneEntity());

  @override
  ExtrusionEntityCollection2 cloneEntity() => ExtrusionEntityCollection2(
        entities: entities,
        noSort: noSort,
        isReverse: _isReverse,
        loopNodeRange: loopNodeRange,
      );

  @override
  void reverse() {
    for (final entity in entities) {
      if (!entity.isLoop) entity.reverse();
    }
    entities.setAll(0, entities.reversed.toList(growable: false));
  }

  @override
  SourcePoint2 get firstPoint => entities.first.firstPoint;

  @override
  SourcePoint2 get lastPoint => entities.last.lastPoint;

  int get itemsCount {
    var count = 0;
    for (final entity in entities) {
      if (entity is ExtrusionEntityCollection2) {
        count += entity.itemsCount;
      } else {
        count++;
      }
    }
    return count;
  }

  ExtrusionEntityCollection2 flatten({bool preserveOrdering = false}) {
    final output = ExtrusionEntityCollection2();

    void recursive(ExtrusionEntityCollection2 collection) {
      if (collection.noSort && preserveOrdering) {
        output.append(collection);
        return;
      }
      for (final entity in collection.entities) {
        if (entity is ExtrusionEntityCollection2) {
          recursive(entity);
        } else {
          output.append(entity);
        }
      }
    }

    recursive(this);
    return output;
  }

  @override
  double get minMm3PerMm {
    var value = double.maxFinite;
    for (final entity in entities) {
      value = math.min(value, entity.minMm3PerMm);
    }
    return value;
  }

  @override
  Never asPolyline() => throw StateError(
        'Calling as_polyline() on a ExtrusionEntityCollection',
      );

  @override
  void collectPolylines(List<SourcePolyline2> destination) {
    for (final entity in entities) {
      entity.collectPolylines(destination);
    }
  }

  @override
  void collectPoints(List<SourcePoint2> destination) {
    for (final entity in entities) {
      entity.collectPoints(destination);
    }
  }

  @override
  Never get length => throw StateError(
        'Calling length() on a ExtrusionEntityCollection',
      );

  @override
  double get totalVolume =>
      entities.fold(0.0, (sum, entity) => sum + entity.totalVolume);
}

List<ExtrusionEntity2> filterByExtrusionRole(
  Iterable<ExtrusionEntity2> source,
  ExtrusionRole role,
) {
  if (role == ExtrusionRole.mixed) {
    return [for (final entity in source) entity.cloneEntity()];
  }
  return [
    for (final entity in source)
      if (entity.role == role ||
          (entity.role == ExtrusionRole.supportTransition &&
              role == ExtrusionRole.supportMaterial))
        entity.cloneEntity(),
  ];
}
