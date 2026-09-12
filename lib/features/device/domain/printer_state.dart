import 'dart:math' as math;

class PrinterState {
  const PrinterState({
    this.connected = false,
    this.raw = const {},
    this.printState = 'standby',
    this.printMessage = '',
    this.fileName = '',
    this.nozzleTemperature = 0,
    this.nozzleTarget = 0,
    this.bedTemperature = 0,
    this.bedTarget = 0,
    this.chamberTemperature = 0,
    this.chamberTarget = 0,
    this.progress = 0,
    this.currentLayer = 0,
    this.totalLayer = 0,
    this.printDuration = 0,
    this.totalDuration = 0,
    this.caseLight = false,
    this.polarCooler = false,
    this.coolingFan = 0,
    this.auxiliaryFan = 0,
    this.chamberFan = 0,
    this.speedFactor = 1,
    this.homedAxes = '',
    this.filamentDetected = false,
    this.excludedObjects = const [],
    this.boxTemperature = const [0, 0, 0, 0],
    this.boxHumidity = const [0, 0, 0, 0],
  });

  final bool connected;
  final Map<String, dynamic> raw;
  final String printState;
  final String printMessage;
  final String fileName;
  final double nozzleTemperature;
  final double nozzleTarget;
  final double bedTemperature;
  final double bedTarget;
  final double chamberTemperature;
  final double chamberTarget;
  final double progress;
  final int currentLayer;
  final int totalLayer;
  final double printDuration;
  final double totalDuration;
  final bool caseLight;
  final bool polarCooler;
  final double coolingFan;
  final double auxiliaryFan;
  final double chamberFan;
  final double speedFactor;
  final String homedAxes;
  final bool filamentDetected;
  final List<String> excludedObjects;
  final List<int> boxTemperature;
  final List<int> boxHumidity;

  int get speedPercent {
    final value = (speedFactor * 100).round();
    const known = [50, 100, 124, 166];
    var best = known.first;
    var distance = (value - best).abs();
    for (final candidate in known.skip(1)) {
      final next = (value - candidate).abs();
      if (next < distance) {
        distance = next;
        best = candidate;
      }
    }
    return best;
  }

  bool get jobActive {
    final lower = printState.toLowerCase();
    return lower == 'printing' || lower == 'paused';
  }

  bool get jobPaused => printState.toLowerCase() == 'paused';

  PrinterState disconnected() => PrinterState(raw: raw);

  PrinterState applyStatusPatch(
    Map<String, dynamic> patch, {
    bool markConnected = true,
  }) {
    final merged = _deepMerge(raw, patch);
    return PrinterState.fromRaw(
      merged,
      connected: markConnected || connected,
    );
  }

  factory PrinterState.fromRaw(
    Map<String, dynamic> raw, {
    bool connected = true,
  }) {
    Map<String, dynamic>? object(String key) {
      final value = raw[key];
      return value is Map ? value.cast<String, dynamic>() : null;
    }

    double number(
      Map<String, dynamic>? map,
      String key, [
      double fallback = 0,
    ]) {
      final value = map?[key];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    int integer(dynamic value, [int fallback = 0]) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool boolish(dynamic value, [bool fallback = false]) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final lower = value?.toString().toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'on') return true;
      if (lower == 'false' || lower == '0' || lower == 'off') return false;
      return fallback;
    }

    final printStats = object('print_stats');
    final printInfo = printStats?['info'] is Map
        ? (printStats!['info'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final display = object('display_status');
    final manager = object('print_stats_manager');
    final mainStatus = manager?['main_status']?.toString();
    final subStatus = manager?['sub_status']?.toString() ?? '';
    final printMessage = mainStatus == 'printing' ? 'Printing' : subStatus;
    final light = object('output_pin caselight');
    final polar = object('output_pin polar_cooler');
    final gcodeMove = object('gcode_move');
    final toolhead = object('toolhead');
    final filament = object('filament_switch_sensor filament_switch_sensor');
    final exclude = object('exclude_object');

    final boxTemperature = <int>[];
    final boxHumidity = <int>[];
    for (var i = 1; i <= 4; i++) {
      final sensor = object('aht20_f heater_box$i');
      boxTemperature.add(number(sensor, 'temperature').round());
      boxHumidity.add(integer(sensor?['humidity']));
    }

    final excluded = <String>[];
    final excludedRaw = exclude?['excluded_objects'];
    if (excludedRaw is List) {
      excluded.addAll(excludedRaw.whereType<String>());
    }

    return PrinterState(
      connected: connected,
      raw: Map.unmodifiable(raw),
      printState: printStats?['state']?.toString() ?? 'standby',
      printMessage: printMessage,
      fileName: printStats?['filename']?.toString() ?? '',
      nozzleTemperature: number(object('extruder'), 'temperature'),
      nozzleTarget: number(object('extruder'), 'target'),
      bedTemperature: number(object('heater_bed'), 'temperature'),
      bedTarget: number(object('heater_bed'), 'target'),
      chamberTemperature:
          number(object('heater_generic chamber'), 'temperature'),
      chamberTarget: number(object('heater_generic chamber'), 'target'),
      progress: math.max(0.0, math.min(1.0, number(display, 'progress'))),
      currentLayer: integer(printInfo['current_layer']),
      totalLayer: integer(printInfo['total_layer']),
      printDuration: number(printStats, 'print_duration'),
      totalDuration: number(printStats, 'total_duration'),
      caseLight: boolish(light?['value']),
      polarCooler: boolish(polar?['value']),
      coolingFan: number(object('fan_generic cooling_fan'), 'speed'),
      auxiliaryFan:
          number(object('fan_generic auxiliary_cooling_fan'), 'speed'),
      chamberFan:
          number(object('fan_generic chamber_circulation_fan'), 'speed'),
      speedFactor: number(gcodeMove, 'speed_factor', 1),
      homedAxes: toolhead?['homed_axes']?.toString() ?? '',
      filamentDetected: boolish(filament?['filament_detected']),
      excludedObjects: List.unmodifiable(excluded),
      boxTemperature: List.unmodifiable(boxTemperature),
      boxHumidity: List.unmodifiable(boxHumidity),
    );
  }

  static Map<String, dynamic> _deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> patch,
  ) {
    final result = <String, dynamic>{...base};
    for (final entry in patch.entries) {
      final oldValue = result[entry.key];
      final newValue = entry.value;
      if (oldValue is Map && newValue is Map) {
        result[entry.key] = _deepMerge(
          oldValue.cast<String, dynamic>(),
          newValue.cast<String, dynamic>(),
        );
      } else {
        result[entry.key] = newValue;
      }
    }
    return result;
  }
}
