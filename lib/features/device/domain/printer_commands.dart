abstract final class PrinterCommands {
  static const homeAll = 'G28';
  static const cooldown = 'TURN_OFF_HEATERS';
  static const fansOff = 'M107';
  static const lightOn = 'SET_PIN PIN=caselight VALUE=1';
  static const lightOff = 'SET_PIN PIN=caselight VALUE=0';
  static const polarCoolerOn = 'SET_PIN PIN=polar_cooler VALUE=1';
  static const polarCoolerOff = 'SET_PIN PIN=polar_cooler VALUE=0';

  static String setNozzleTemperature(int celsius) =>
      'SET_HEATER_TEMPERATURE HEATER=extruder TARGET=$celsius';

  static String setBedTemperature(int celsius) =>
      'SET_HEATER_TEMPERATURE HEATER=heater_bed TARGET=$celsius';

  static String setChamberTemperature(int celsius) =>
      'SET_HEATER_TEMPERATURE HEATER=chamber TARGET=$celsius';

  static String setSpeedPercent(int percent) => 'M220 S$percent';

  static String moveX(int millimeters) =>
      'G91\nG1 X$millimeters F7800\nG90';
  static String moveY(int millimeters) =>
      'G91\nG1 Y$millimeters F7800\nG90';
  static String moveZ(int millimeters) =>
      'G91\nG1 Z$millimeters F600\nG90';

  static String setCoolingFanPercent(int percent) =>
      _setFan('cooling_fan', percent);
  static String setAuxiliaryFanPercent(int percent) =>
      _setFan('auxiliary_cooling_fan', percent);
  static String setChamberFanPercent(int percent) =>
      _setFan('chamber_circulation_fan', percent);

  static String _setFan(String fan, int percent) {
    final normalized = percent.clamp(0, 100) / 100.0;
    return 'SET_FAN_SPEED FAN=$fan SPEED=${normalized.toStringAsFixed(2)}';
  }

  static String setAutoReadRfid(bool enabled) =>
      'SAVE_VARIABLE VARIABLE=auto_read_rfid VALUE="${enabled ? 1 : 0}"';
  static String setAutoInitDetect(bool enabled) =>
      'SAVE_VARIABLE VARIABLE=auto_init_detect VALUE="${enabled ? 1 : 0}"';
  static String setAutoReloadDetect(bool enabled) =>
      'SAVE_VARIABLE VARIABLE=auto_reload_detect VALUE="${enabled ? 1 : 0}"';

  static String excludeObject(String name) => 'EXCLUDE_OBJECT NAME=$name';

  static String setSlotColorIndex(int slot, int filamentIndex) =>
      'SAVE_VARIABLE VARIABLE=color_slot$slot VALUE="$filamentIndex"';
  static String setSlotVendorIndex(int slot, int filamentIndex) =>
      'SAVE_VARIABLE VARIABLE=vendor_slot$slot VALUE="$filamentIndex"';
  static String setSlotFilamentIndex(int slot, int filamentIndex) =>
      'SAVE_VARIABLE VARIABLE=filament_slot$slot VALUE="$filamentIndex"';

  static String loadSlot(int slot) => 'E_LOAD slot=$slot';
  static String unloadSlot(int slot) => 'E_UNLOAD slot=$slot';
  static String ejectSlot(int slot) => 'E_BOX slot=$slot';
  static String refreshRfid(int slot) => 'RFID_READ SLOT=slot$slot';
}
