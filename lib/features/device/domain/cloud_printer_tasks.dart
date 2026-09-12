class CloudPrinterTask {
  const CloudPrinterTask({required this.path, required this.body});

  final String path;
  final Map<String, dynamic> body;
}

abstract final class QidiCloudTasks {
  static CloudPrinterTask setValue(String serial, String path, int value) =>
      CloudPrinterTask(
        path: path,
        body: {'serialNumber': serial, 'value': value},
      );

  static CloudPrinterTask setEnabled(
    String serial,
    String path,
    bool enabled,
  ) =>
      CloudPrinterTask(
        path: path,
        body: {'serialNumber': serial, 'enable': enabled},
      );

  static CloudPrinterTask printControl(String serial, PrintControl action) =>
      CloudPrinterTask(
        path: '/set/print/control',
        body: {'serialNumber': serial, 'type': action.name},
      );

  static CloudPrinterTask excludeObject(String serial, String objectName) =>
      CloudPrinterTask(
        path: '/common/control/param/one',
        body: {
          'serialNumber': serial,
          'paramValue': objectName,
          'command': 'exclude_print_object',
        },
      );

  static CloudPrinterTask home(String serial) =>
      _StatusPath('/set/return/safeHome').task(serial);
  static CloudPrinterTask setExtrusion(String serial, int value) =>
      _StatusPath('/set/extrusion').value(serial, value);
  static CloudPrinterTask setBack(String serial, int value) =>
      _StatusPath('/set/back').value(serial, value);
  static CloudPrinterTask setCooler(String serial, bool enabled) =>
      _StatusPath('/set/cooler/switch').enabled(serial, enabled);
  static CloudPrinterTask setLeveling(String serial, bool enabled) =>
      _StatusPath('/set/leveling/enable').enabled(serial, enabled);
  static CloudPrinterTask setAms(String serial, bool enabled) =>
      _StatusPath('/set/ams/enable').enabled(serial, enabled);
  static CloudPrinterTask setCoolingFan(String serial, int value) =>
      _StatusPath('/set/coolingFan/speed').value(serial, value);
  static CloudPrinterTask setChamberFan(String serial, int value) =>
      _StatusPath('/set/chamberFan/speed').value(serial, value);
  static CloudPrinterTask setAuxiliaryFan(String serial, int value) =>
      _StatusPath('/set/auxiliaryFan/speed').value(serial, value);
  static CloudPrinterTask setCaseLight(String serial, bool enabled) =>
      _StatusPath('/set/case/light').enabled(serial, enabled);
  static CloudPrinterTask setBeeper(String serial, bool enabled) =>
      _StatusPath('/set/beeper/switch').enabled(serial, enabled);
  static CloudPrinterTask setNozzleTemperature(String serial, int value) =>
      _StatusPath('/set/extruder/temperature').value(serial, value);
  static CloudPrinterTask setPrintSpeed(String serial, int value) =>
      _StatusPath('/set/print/speed').value(serial, value);
  static CloudPrinterTask setBedTemperature(String serial, int value) =>
      _StatusPath('/set/heaterBed/temperature').value(serial, value);
  static CloudPrinterTask setChamberTemperature(String serial, int value) =>
      _StatusPath('/set/chamber/temperature').value(serial, value);
  static CloudPrinterTask moveX(String serial, int value) =>
      _StatusPath('/set/x/axis').value(serial, value);
  static CloudPrinterTask moveY(String serial, int value) =>
      _StatusPath('/set/y/axis').value(serial, value);
  static CloudPrinterTask moveZ(String serial, int value) =>
      _StatusPath('/set/z/axis').value(serial, value);
  static CloudPrinterTask setInsertRead(String serial, bool enabled) =>
      _StatusPath('/ams/insert/filament/read/enable').enabled(serial, enabled);
  static CloudPrinterTask setBootRead(String serial, bool enabled) =>
      _StatusPath('/ams/boot/read/enable').enabled(serial, enabled);
  static CloudPrinterTask setAutoFilament(String serial, bool enabled) =>
      _StatusPath('/ams/auto/filament/enable').enabled(serial, enabled);

  static CloudPrinterTask setSlotColor(String serial, int slot, int index) =>
      _slotIndexed(serial, '/set/filament/color', slot, index);
  static CloudPrinterTask setSlotType(String serial, int slot, int index) =>
      _slotIndexed(serial, '/set/filament/type', slot, index);
  static CloudPrinterTask setSlotVendor(String serial, int slot, int index) =>
      _slotIndexed(serial, '/set/filament/vendor', slot, index);
  static CloudPrinterTask loadSlot(String serial, int slot) =>
      _slot(serial, '/set/filament/load', slot);
  static CloudPrinterTask unloadSlot(String serial, int slot) =>
      _slot(serial, '/set/filament/unload', slot);
  static CloudPrinterTask ejectSlot(String serial, int slot) =>
      _slot(serial, '/set/filament/eject', slot);
  static CloudPrinterTask refreshRfid(String serial, int slot) =>
      _slot(serial, '/set/filament/rfid', slot);

  static CloudPrinterTask unbind(String serial) => CloudPrinterTask(
        path: '/unbind',
        body: {'serialNumber': serial, 'source': 'QIDIStudio'},
      );

  static CloudPrinterTask deleteFiles(String serial, List<String> files) =>
      CloudPrinterTask(
        path: '/delete/file/batch',
        body: {'serialNumber': serial, 'files': List.unmodifiable(files)},
      );

  static CloudPrinterTask _slot(String serial, String path, int slot) =>
      CloudPrinterTask(
        path: path,
        body: {'serialNumber': serial, 'slotIndex': slot},
      );

  static CloudPrinterTask _slotIndexed(
    String serial,
    String path,
    int slot,
    int index,
  ) =>
      CloudPrinterTask(
        path: path,
        body: {'serialNumber': serial, 'slotIndex': slot, 'idx': index},
      );
}

enum PrintControl { pause, resume, cancel }

class _StatusPath {
  _StatusPath(this.path);
  final String path;

  CloudPrinterTask task(String serial) =>
      CloudPrinterTask(path: path, body: {'serialNumber': serial});
  CloudPrinterTask value(String serial, int value) => CloudPrinterTask(
        path: path,
        body: {'serialNumber': serial, 'value': value},
      );
  CloudPrinterTask enabled(String serial, bool enabled) => CloudPrinterTask(
        path: path,
        body: {'serialNumber': serial, 'enable': enabled},
      );
}
