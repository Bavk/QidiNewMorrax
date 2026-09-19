import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/legal/release_legal_notice.dart';

void main() {
  test('release legal notice identifies licenses and pinned Orca source', () {
    expect(
      ReleaseLegalNotice.projectLicense,
      'GNU Affero General Public License v3',
    );
    expect(ReleaseLegalNotice.orcaVersion, '2.4.2');
    expect(
      ReleaseLegalNotice.orcaCommit,
      '8500fcdccaa10b5099ac20d252af3a7c560046f1',
    );
    expect(ReleaseLegalNotice.summary, contains('NO WARRANTY'));
    expect(
      ReleaseLegalNotice.summary,
      contains('Complete source archives'),
    );
    expect(
      ReleaseLegalNotice.summary,
      contains('does not bundle or use OrcaSlicer'),
    );
  });
}
