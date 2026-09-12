import 'dart:math' as math;

enum NozzleVolumeType { standard, highFlow, hybrid, tpuHighFlow }
enum ExtruderType { directDrive, bowden }

class QidiConfigVariantResolver {
  const QidiConfigVariantResolver._();

  static const List<String> _extruderTypeNames = ['Direct Drive', 'Bowden'];
  static const List<String> _nozzleVolumeTypeNames = [
    'Standard',
    'High Flow',
    'Hybrid',
    'TPU High Flow',
  ];

  static String extruderVariantString(
    ExtruderType extruderType,
    NozzleVolumeType volumeType,
  ) =>
      '${_extruderTypeNames[extruderType.index]} ${_nozzleVolumeTypeNames[volumeType.index]}';

  /// Exact port of `get_config_index_base()` from PrintConfig.cpp.
  static int configIndexBase({
    required NozzleVolumeType volumeType,
    required ExtruderType extruderType,
    required int variantId1Based,
    required List<String> variantList,
    required List<int> variantIds1Based,
  }) {
    if (variantList.length != variantIds1Based.length) {
      throw ArgumentError('variantList and variantIds1Based must have equal length');
    }
    final target = extruderVariantString(extruderType, volumeType);
    for (var index = 0; index < variantList.length; index++) {
      if (target == variantList[index] &&
          variantIds1Based[index] == variantId1Based) {
        return index;
      }
    }
    return 0;
  }

  /// Port of `get_extruder_index()` + `get_filament_config_idx()`.
  static int filamentConfigIndex({
    required int filamentId,
    required List<int> filamentMap,
    required List<int> filamentVolumeMap,
    required List<int> extruderTypes,
    required List<String> filamentExtruderVariants,
    required List<int> filamentSelfIndexes,
  }) {
    final extruderIndex = filamentId < filamentMap.length
        ? filamentMap[filamentId] - 1
        : 0;
    final volumeType = NozzleVolumeType.values[filamentVolumeMap[filamentId]];
    final extruderType = ExtruderType.values[extruderTypes[extruderIndex]];
    return configIndexBase(
      volumeType: volumeType,
      extruderType: extruderType,
      variantId1Based: filamentId + 1,
      variantList: filamentExtruderVariants,
      variantIds1Based: filamentSelfIndexes,
    );
  }
}

/// Resolved subset of source `GCodeConfig` consumed by `Extruder.cpp`.
///
/// The exact QIDI `get_config_index_base()` / `get_filament_config_idx()`
/// helpers are ported above; this snapshot currently stores the already
/// resolved index used by each filament. Full PrintConfig construction remains
/// a separate migration unit.
class ExtruderConfigSnapshot {
  const ExtruderConfigSnapshot({
    required this.useRelativeEDistances,
    required this.filamentMap,
    required this.filamentNozzleMap,
    required this.nozzleVolumeTypes,
    required this.extruderTypes,
    required this.filamentDiameters,
    required this.filamentDensities,
    required this.filamentCosts,
    required this.filamentConfigIndexes,
    required this.filamentFlowRatios,
    required this.retractBeforeWipePercents,
    required this.retractionLengths,
    required this.zHops,
    required this.retractionSpeeds,
    required this.deretractionSpeeds,
    required this.retractRestartExtras,
    required this.retractLengthsToolchange,
    required this.retractRestartExtrasToolchange,
  });

  final bool useRelativeEDistances;
  final List<int> filamentMap;
  final List<int> filamentNozzleMap;
  final List<int> nozzleVolumeTypes;
  final List<int> extruderTypes;
  final List<double> filamentDiameters;
  final List<double> filamentDensities;
  final List<double> filamentCosts;
  final List<int> filamentConfigIndexes;
  final List<double> filamentFlowRatios;
  final List<double> retractBeforeWipePercents;
  final List<double> retractionLengths;
  final List<double> zHops;
  final List<double> retractionSpeeds;
  final List<double> deretractionSpeeds;
  final List<double> retractRestartExtras;
  final List<double> retractLengthsToolchange;
  final List<double> retractRestartExtrasToolchange;
}

/// Dart port of the state/math behavior in `libslic3r/Extruder.cpp`.
class ExtruderState {
  ExtruderState({
    required this.id,
    required this.config,
    required this.shareExtruder,
  }) : _ePerMm3 = _calculateEPerMm3(id, config) {
    reset();
  }

  final int id;
  final ExtruderConfigSnapshot config;
  final bool shareExtruder;
  final double _ePerMm3;

  double _e = 0;
  double _absoluteE = 0;
  double _retracted = 0;
  double _restartExtra = 0;

  // Exact QIDI source shape/reset semantics: two shared channels.
  static List<double> _sharedE = [0, 0];
  static List<double> _sharedRetracted = [0, 0];

  void reset() {
    if (shareExtruder) {
      _sharedE = [0, 0];
      _sharedRetracted = [0, 0];
    } else {
      _e = 0;
      _retracted = 0;
    }
    _restartExtra = 0;
    _absoluteE = 0;
  }

  int get extruderId => id < config.filamentMap.length
      ? config.filamentMap[id] - 1
      : 0;

  int get nozzleId => id < config.filamentNozzleMap.length
      ? config.filamentNozzleMap[id] - 1
      : 0;

  NozzleVolumeType get volumeType {
    if (id < config.nozzleVolumeTypes.length) {
      final value = config.nozzleVolumeTypes[id];
      if (value >= 0 && value < NozzleVolumeType.values.length) {
        return NozzleVolumeType.values[value];
      }
    }
    return NozzleVolumeType.standard;
  }

  ExtruderType get extruderType {
    final mappedId = extruderId;
    if (mappedId < config.extruderTypes.length) {
      final value = config.extruderTypes[mappedId];
      if (value >= 0 && value < ExtruderType.values.length) {
        return ExtruderType.values[value];
      }
    }
    return ExtruderType.directDrive;
  }

  double get e => shareExtruder ? _sharedE[extruderId] : _e;
  double get absoluteE => _absoluteE;
  double get retracted =>
      shareExtruder ? _sharedRetracted[extruderId] : _retracted;
  double get restartExtra => _restartExtra;

  double get ePerMm3 => _ePerMm3;
  double ePerMm(double mm3PerMm) => mm3PerMm * _ePerMm3;

  double get filamentDiameter => config.filamentDiameters[id];
  double get filamentCrossSection =>
      filamentDiameter * filamentDiameter * 0.25 * math.pi;
  double get filamentDensity => config.filamentDensities[id];
  double get filamentCost => config.filamentCosts[id];

  int get _filamentConfigIndex => config.filamentConfigIndexes[id];
  double get filamentFlowRatio =>
      config.filamentFlowRatios[_filamentConfigIndex];

  double get retractBeforeWipe =>
      (config.retractBeforeWipePercents[_filamentConfigIndex] * 0.01)
          .clamp(0.0, 1.0)
          .toDouble();
  double get retractionLength =>
      config.retractionLengths[_filamentConfigIndex];
  double get retractLift => config.zHops[_filamentConfigIndex];
  int get retractSpeed =>
      (config.retractionSpeeds[_filamentConfigIndex] + 0.5).floor();
  int get deretractSpeed {
    final speed =
        (config.deretractionSpeeds[_filamentConfigIndex] + 0.5).floor();
    return speed > 0 ? speed : retractSpeed;
  }

  double get retractRestartExtra =>
      config.retractRestartExtras[_filamentConfigIndex];
  double get retractLengthToolchange =>
      config.retractLengthsToolchange[extruderId];
  double get retractRestartExtraToolchange =>
      config.retractRestartExtrasToolchange[extruderId];

  double extrude(double deltaE) {
    if (shareExtruder) {
      final index = extruderId;
      if (config.useRelativeEDistances) _sharedE[index] = 0;
      _sharedE[index] += deltaE;
      _absoluteE += deltaE;
      if (deltaE < 0) _sharedRetracted[index] -= deltaE;
    } else {
      if (config.useRelativeEDistances) _e = 0;
      _e += deltaE;
      _absoluteE += deltaE;
      if (deltaE < 0) _retracted -= deltaE;
    }
    return deltaE;
  }

  double retract(double length, double restartExtra) {
    if (shareExtruder) {
      final index = extruderId;
      if (config.useRelativeEDistances) _sharedE[index] = 0;
      final toRetract = math.max(0.0, length - _sharedRetracted[index]);
      _restartExtra = restartExtra;
      if (toRetract > 0) {
        _sharedE[index] -= toRetract;
        _absoluteE -= toRetract;
        _sharedRetracted[index] += toRetract;
      }
      return toRetract;
    }

    if (config.useRelativeEDistances) _e = 0;
    final toRetract = math.max(0.0, length - _retracted);
    _restartExtra = restartExtra;
    if (toRetract > 0) {
      _e -= toRetract;
      _absoluteE -= toRetract;
      _retracted += toRetract;
    }
    return toRetract;
  }

  double unretract() {
    if (shareExtruder) {
      final index = extruderId;
      final deltaE = _sharedRetracted[index] + _restartExtra;
      extrude(deltaE);
      _sharedRetracted[index] = 0;
      _restartExtra = 0;
      return deltaE;
    }

    final deltaE = _retracted + _restartExtra;
    extrude(deltaE);
    _retracted = 0;
    _restartExtra = 0;
    return deltaE;
  }

  double get usedFilament =>
      shareExtruder ? _absoluteE : _absoluteE + _retracted;

  double get extrudedVolume => usedFilament * filamentCrossSection;

  void resetE() {
    _e = 0;
    _sharedE[extruderId] = 0;
  }

  static double ePerMm3For({
    required double filamentDiameter,
    required double filamentFlowRatio,
  }) {
    final crossSection =
        filamentDiameter * filamentDiameter * 0.25 * math.pi;
    return filamentFlowRatio / crossSection;
  }

  static double _calculateEPerMm3(
    int id,
    ExtruderConfigSnapshot config,
  ) {
    final diameter = config.filamentDiameters[id];
    final configIndex = config.filamentConfigIndexes[id];
    return ePerMm3For(
      filamentDiameter: diameter,
      filamentFlowRatio: config.filamentFlowRatios[configIndex],
    );
  }
}
