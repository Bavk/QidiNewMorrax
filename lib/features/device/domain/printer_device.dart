class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    required this.ip,
    this.serialNumber = '',
    this.model = '',
    this.isCloud = false,
    this.linkUrl,
  });

  final String id;
  final String name;
  final String ip;
  final String serialNumber;
  final String model;
  final bool isCloud;
  final String? linkUrl;

  String get websocketUrl => 'ws://$ip:7125/websocket';
  String get moonrakerBaseUrl => 'http://$ip:7125';
  String get snapshotUrl =>
      '${linkUrl ?? 'http://$ip'}/webcam/?action=snapshot';

  PrinterDevice copyWith({
    String? id,
    String? name,
    String? ip,
    String? serialNumber,
    String? model,
    bool? isCloud,
    String? linkUrl,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      serialNumber: serialNumber ?? this.serialNumber,
      model: model ?? this.model,
      isCloud: isCloud ?? this.isCloud,
      linkUrl: linkUrl ?? this.linkUrl,
    );
  }
}
