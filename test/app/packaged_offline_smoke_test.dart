import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/app/packaged_offline_smoke.dart';

void main() {
  test('packaged smoke flag is explicit', () {
    expect(
      PackagedOfflineSmoke.requested(const ['--packaged-offline-smoke']),
      isTrue,
    );
    expect(PackagedOfflineSmoke.requested(const ['--model', 'cube.stl']), isFalse);
  });

  test('packaged smoke options accept split and equals arguments', () {
    final split = PackagedOfflineSmokeOptions.parse(
      const [
        '--packaged-offline-smoke',
        '--model',
        '/tmp/cube.stl',
        '--report',
        '/tmp/report.json',
      ],
    );
    expect(split.modelPath, '/tmp/cube.stl');
    expect(split.reportPath, '/tmp/report.json');

    final equals = PackagedOfflineSmokeOptions.parse(
      const [
        '--packaged-offline-smoke',
        '--model=/tmp/other.stl',
        '--report=/tmp/other.json',
      ],
    );
    expect(equals.modelPath, '/tmp/other.stl');
    expect(equals.reportPath, '/tmp/other.json');
  });

  test('packaged smoke options require model and report paths', () {
    expect(
      () => PackagedOfflineSmokeOptions.parse(
        const ['--packaged-offline-smoke', '--report', '/tmp/report.json'],
      ),
      throwsFormatException,
    );
    expect(
      () => PackagedOfflineSmokeOptions.parse(
        const ['--packaged-offline-smoke', '--model', '/tmp/cube.stl'],
      ),
      throwsFormatException,
    );
  });
}
