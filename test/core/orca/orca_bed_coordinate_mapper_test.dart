import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/orca/orca_bed_coordinate_mapper.dart';
import 'package:qidi_flow_flutter/core/profiles/profile_repository.dart';

void main() {
  test('maps centered workspace origin to printable-area center', () {
    final machine = QidiProfile(
      assetPath: 'machine.json',
      values: const {
        'name': 'Qidi X-Plus 4 0.4 nozzle',
        'type': 'machine',
        'printable_area': ['0x0', '305x0', '305x305', '0x305'],
      },
    );

    final mapper = const OrcaBedCoordinateMapper();
    final center = mapper.bedCenter(machine);
    expect(center.x, 152.5);
    expect(center.y, 152.5);

    final mapped = mapper.workspaceToPrinter(machine).apply(
          const Point3(10, -20, 3),
        );
    expect(mapped.x, 162.5);
    expect(mapped.y, 132.5);
    expect(mapped.z, 3);
  });

  test('supports negative printable-area coordinates', () {
    final machine = QidiProfile(
      assetPath: 'machine.json',
      values: const {
        'name': 'Centered bed',
        'type': 'machine',
        'printable_area': ['-100x-90', '100x-90', '100x90', '-100x90'],
      },
    );

    final center = const OrcaBedCoordinateMapper().bedCenter(machine);
    expect(center.x, 0);
    expect(center.y, 0);
  });
}
