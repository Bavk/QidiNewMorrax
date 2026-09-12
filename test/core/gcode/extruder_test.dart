import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/gcode/extruder.dart';

const config = ExtruderConfigSnapshot(
  useRelativeEDistances: false,
  filamentMap: [1, 2],
  filamentNozzleMap: [1, 2],
  nozzleVolumeTypes: [0, 0],
  extruderTypes: [0, 0],
  filamentDiameters: [1.75, 1.75],
  filamentDensities: [1.24, 1.24],
  filamentCosts: [20, 20],
  filamentConfigIndexes: [0, 1],
  filamentFlowRatios: [0.98, 1.02],
  retractBeforeWipePercents: [25, 120],
  retractionLengths: [0.8, 1.2],
  zHops: [0.4, 0.6],
  retractionSpeeds: [29.6, 39.4],
  deretractionSpeeds: [0, 35.5],
  retractRestartExtras: [0.05, 0.1],
  retractLengthsToolchange: [2, 3],
  retractRestartExtrasToolchange: [0.2, 0.3],
);

void main() {
  group('QIDI variant resolver source behavior', () {
    test('variant string uses exact source names', () {
      expect(
        QidiConfigVariantResolver.extruderVariantString(
          ExtruderType.directDrive,
          NozzleVolumeType.highFlow,
        ),
        'Direct Drive High Flow',
      );
      expect(
        QidiConfigVariantResolver.extruderVariantString(
          ExtruderType.bowden,
          NozzleVolumeType.tpuHighFlow,
        ),
        'Bowden TPU High Flow',
      );
    });

    test('get_config_index_base returns matching index or source fallback zero', () {
      const variants = [
        'Direct Drive Standard',
        'Direct Drive High Flow',
        'Bowden Standard',
      ];
      const ids = [1, 1, 2];
      expect(
        QidiConfigVariantResolver.configIndexBase(
          volumeType: NozzleVolumeType.highFlow,
          extruderType: ExtruderType.directDrive,
          variantId1Based: 1,
          variantList: variants,
          variantIds1Based: ids,
        ),
        1,
      );
      expect(
        QidiConfigVariantResolver.configIndexBase(
          volumeType: NozzleVolumeType.hybrid,
          extruderType: ExtruderType.bowden,
          variantId1Based: 9,
          variantList: variants,
          variantIds1Based: ids,
        ),
        0,
      );
    });

    test('get_filament_config_idx combines filament map, volume and self id', () {
      expect(
        QidiConfigVariantResolver.filamentConfigIndex(
          filamentId: 1,
          filamentMap: const [1, 2],
          filamentVolumeMap: const [0, 1],
          extruderTypes: const [0, 1],
          filamentExtruderVariants: const [
            'Direct Drive Standard',
            'Bowden High Flow',
          ],
          filamentSelfIndexes: const [1, 2],
        ),
        1,
      );
    });
  });

  test('e_per_mm3 matches source filament flow ratio / cross section', () {
    final extruder = ExtruderState(id: 0, config: config, shareExtruder: false);
    expect(
      extruder.ePerMm3,
      closeTo(0.98 / (1.75 * 1.75 * 0.25 * math.pi), 1e-12),
    );
  });

  test('retract only retracts missing amount and unretract includes restart extra', () {
    final extruder = ExtruderState(id: 0, config: config, shareExtruder: false);
    expect(extruder.retract(0.8, 0.05), closeTo(0.8, 1e-12));
    expect(extruder.retracted, closeTo(0.8, 1e-12));
    expect(extruder.retract(0.6, 0.02), 0);
    // Source updates restart_extra even when no additional retract occurred.
    expect(extruder.restartExtra, closeTo(0.02, 1e-12));
    expect(extruder.unretract(), closeTo(0.82, 1e-12));
    expect(extruder.retracted, 0);
  });

  test('used filament adds outstanding retract only for non-shared mode', () {
    final extruder = ExtruderState(id: 0, config: config, shareExtruder: false);
    extruder.extrude(10);
    extruder.retract(1, 0);
    expect(extruder.absoluteE, 9);
    expect(extruder.usedFilament, 10);
  });

  test('deretraction speed zero falls back to rounded retract speed', () {
    final extruder = ExtruderState(id: 0, config: config, shareExtruder: false);
    expect(extruder.retractSpeed, 30);
    expect(extruder.deretractSpeed, 30);
  });

  test('retract-before-wipe percent is clamped to 0..1', () {
    final extruder0 = ExtruderState(id: 0, config: config, shareExtruder: false);
    final extruder1 = ExtruderState(id: 1, config: config, shareExtruder: false);
    expect(extruder0.retractBeforeWipe, 0.25);
    expect(extruder1.retractBeforeWipe, 1);
  });

  test('relative E resets current E before each emitted delta', () {
    const relativeConfig = ExtruderConfigSnapshot(
      useRelativeEDistances: true,
      filamentMap: [1, 2],
      filamentNozzleMap: [1, 2],
      nozzleVolumeTypes: [0, 0],
      extruderTypes: [0, 0],
      filamentDiameters: [1.75, 1.75],
      filamentDensities: [1.24, 1.24],
      filamentCosts: [20, 20],
      filamentConfigIndexes: [0, 1],
      filamentFlowRatios: [0.98, 1.02],
      retractBeforeWipePercents: [25, 120],
      retractionLengths: [0.8, 1.2],
      zHops: [0.4, 0.6],
      retractionSpeeds: [29.6, 39.4],
      deretractionSpeeds: [0, 35.5],
      retractRestartExtras: [0.05, 0.1],
      retractLengthsToolchange: [2, 3],
      retractRestartExtrasToolchange: [0.2, 0.3],
    );
    final extruder = ExtruderState(
      id: 0,
      config: relativeConfig,
      shareExtruder: false,
    );
    extruder.extrude(2);
    expect(extruder.e, 2);
    extruder.extrude(3);
    expect(extruder.e, 3);
    expect(extruder.absoluteE, 5);
  });
}
