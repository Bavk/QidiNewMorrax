class ReleaseLegalNotice {
  const ReleaseLegalNotice._();

  static const projectName = 'QidiNewMorrax';
  static const projectLicense = 'GNU Affero General Public License v3';
  static const orcaName = 'OrcaSlicer';
  static const orcaVersion = '2.4.2';
  static const orcaCommit =
      '8500fcdccaa10b5099ac20d252af3a7c560046f1';

  static const summary = '''
QidiNewMorrax is distributed under the GNU Affero General Public License v3.
There is NO WARRANTY, to the extent permitted by law.

This Linux release bundles an unmodified upstream OrcaSlicer $orcaVersion
engine at commit $orcaCommit, also licensed under GNU AGPL v3.

The distribution includes legal/AGPL-3.0.txt and legal/RELEASE-NOTICES.txt.
Complete source archives for QidiNewMorrax and the exact pinned OrcaSlicer
commit are delivered alongside the binary release.

QidiNewMorrax does not bundle or use OrcaSlicer's optional Bambu networking
plugin. Printer delivery uses the application's Moonraker/QIDI integration.
''';
}
