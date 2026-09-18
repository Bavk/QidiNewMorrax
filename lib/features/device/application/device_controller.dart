import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_device_discovery.dart';
import '../data/moonraker_client.dart';
import '../domain/printer_commands.dart';
import '../domain/printer_device.dart';
import '../domain/printer_state.dart';

class DeviceController extends ChangeNotifier {
  DeviceController({LocalDeviceDiscovery? discovery})
      : _discovery = discovery ?? LocalDeviceDiscovery();

  final LocalDeviceDiscovery _discovery;
  final List<PrinterDevice> _devices = [];
  List<PrinterDevice> get devices => List.unmodifiable(_devices);

  PrinterDevice? _selected;
  PrinterDevice? get selected => _selected;
  PrinterState _state = const PrinterState();
  PrinterState get state => _state;
  MoonrakerClient? _client;
  StreamSubscription<PrinterState>? _stateSubscription;
  bool _discovering = false;
  bool get discovering => _discovering;
  bool _connecting = false;
  bool get connecting => _connecting;
  Object? _lastError;
  Object? get lastError => _lastError;

  List<Map<String, dynamic>> _files = const [];
  List<Map<String, dynamic>> get files => _files;

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('last_printer_ip');
    if (ip == null || ip.isEmpty) return;
    final name = prefs.getString('last_printer_name') ?? 'QIDI $ip';
    final serial = prefs.getString('last_printer_serial') ?? ip;
    final device = PrinterDevice(
      id: serial,
      serialNumber: serial,
      name: name,
      ip: ip,
    );
    _upsert(device);
    _selected = device;
    notifyListeners();
  }

  Future<void> discover() async {
    _discovering = true;
    _lastError = null;
    notifyListeners();
    try {
      final discovered = await _discovery.discover();
      for (final device in discovered) {
        _upsert(device);
      }
    } catch (error) {
      _lastError = error;
    } finally {
      _discovering = false;
      notifyListeners();
    }
  }

  Future<void> addManual(String ip, {String? name}) async {
    final normalized = ip.trim();
    if (normalized.isEmpty) return;
    final device = PrinterDevice(
      id: normalized,
      name: name?.trim().isNotEmpty == true
          ? name!.trim()
          : 'QIDI $normalized',
      ip: normalized,
      serialNumber: normalized,
    );
    _upsert(device);
    _selected = device;
    await _persistSelection(device);
    notifyListeners();
  }

  Future<void> select(PrinterDevice device) async {
    if (_selected?.id == device.id) return;
    await disconnect();
    _selected = device;
    await _persistSelection(device);
    notifyListeners();
  }

  Future<void> connect() async {
    final device = _selected;
    if (device == null || _connecting) return;
    _connecting = true;
    _lastError = null;
    notifyListeners();
    try {
      await _stateSubscription?.cancel();
      await _client?.dispose();
      final client = MoonrakerClient(device);
      _client = client;
      _stateSubscription = client.states.listen((value) {
        _state = value;
        notifyListeners();
      });
      await client.connect();
      _state = client.state;
      unawaited(refreshFiles());
    } catch (error) {
      _lastError = error;
      _state = const PrinterState();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> reconnect() async {
    await disconnect(keepSelection: true);
    await connect();
  }

  Future<void> disconnect({bool keepSelection = true}) async {
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    await _client?.dispose();
    _client = null;
    _state = const PrinterState();
    _files = const [];
    if (!keepSelection) _selected = null;
    notifyListeners();
  }

  Future<void> sendGcode(String gcode) async {
    final client = _requireClient();
    final lines = gcode
        .split(RegExp(r'[\r\n]+'))
        .map((it) => it.trim())
        .where((it) => it.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    await client.sendGcode(lines.join('\n'));
  }

  Future<void> home() => sendGcode(PrinterCommands.homeAll);
  Future<void> cooldown() => sendGcode(PrinterCommands.cooldown);
  Future<void> fansOff() => sendGcode(PrinterCommands.fansOff);
  Future<void> toggleLight() => sendGcode(
        state.caseLight ? PrinterCommands.lightOff : PrinterCommands.lightOn,
      );
  Future<void> pauseOrResume() => state.jobPaused
      ? _requireClient().resumePrint()
      : _requireClient().pausePrint();
  Future<void> cancelPrint() => _requireClient().cancelPrint();
  Future<void> startPrint(String filename) =>
      _requireClient().startPrint(filename);

  Future<String> uploadGcode(String localPath) async {
    final remotePath = await _requireClient().uploadGcodeFile(localPath);
    await refreshFiles();
    return remotePath;
  }

  Future<void> uploadAndStart(String localPath) async {
    final remotePath = await uploadGcode(localPath);
    await startPrint(remotePath);
  }

  Future<void> setNozzleTemperature(int value) =>
      sendGcode(PrinterCommands.setNozzleTemperature(value));
  Future<void> setBedTemperature(int value) =>
      sendGcode(PrinterCommands.setBedTemperature(value));
  Future<void> setChamberTemperature(int value) =>
      sendGcode(PrinterCommands.setChamberTemperature(value));
  Future<void> setSpeed(int value) =>
      sendGcode(PrinterCommands.setSpeedPercent(value));
  Future<void> moveX(int value) => sendGcode(PrinterCommands.moveX(value));
  Future<void> moveY(int value) => sendGcode(PrinterCommands.moveY(value));
  Future<void> moveZ(int value) => sendGcode(PrinterCommands.moveZ(value));
  Future<void> setCoolingFan(int value) =>
      sendGcode(PrinterCommands.setCoolingFanPercent(value));
  Future<void> setAuxiliaryFan(int value) =>
      sendGcode(PrinterCommands.setAuxiliaryFanPercent(value));
  Future<void> setChamberFan(int value) =>
      sendGcode(PrinterCommands.setChamberFanPercent(value));
  Future<void> excludeObject(String name) =>
      sendGcode(PrinterCommands.excludeObject(name));
  Future<void> loadSlot(int slot) => sendGcode(PrinterCommands.loadSlot(slot));
  Future<void> unloadSlot(int slot) =>
      sendGcode(PrinterCommands.unloadSlot(slot));
  Future<void> ejectSlot(int slot) =>
      sendGcode(PrinterCommands.ejectSlot(slot));
  Future<void> refreshRfid(int slot) =>
      sendGcode(PrinterCommands.refreshRfid(slot));
  Future<void> togglePolarCooler() => sendGcode(
        state.polarCooler
            ? PrinterCommands.polarCoolerOff
            : PrinterCommands.polarCoolerOn,
      );

  Future<List<Map<String, dynamic>>> listTimelapses() =>
      _requireClient().listFiles(root: 'timelapse');

  Future<void> refreshFiles() async {
    final client = _client;
    if (client == null || !state.connected) return;
    try {
      _files = await client.listFiles();
    } catch (error) {
      _lastError = error;
    }
    notifyListeners();
  }

  Future<void> deleteFile(String path) async {
    await _requireClient().deleteFile(path);
    await refreshFiles();
  }

  MoonrakerClient _requireClient() {
    final client = _client;
    if (client == null || !state.connected) {
      throw StateError('No connected local Moonraker printer');
    }
    return client;
  }

  void _upsert(PrinterDevice device) {
    final index = _devices.indexWhere(
      (it) => it.id == device.id || it.ip == device.ip,
    );
    if (index >= 0) {
      _devices[index] = device;
      if (_selected?.id == _devices[index].id || _selected?.ip == device.ip) {
        _selected = device;
      }
    } else {
      _devices.add(device);
      _devices.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
  }

  Future<void> _persistSelection(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_printer_ip', device.ip);
    await prefs.setString('last_printer_name', device.name);
    await prefs.setString('last_printer_serial', device.serialNumber);
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_client?.dispose());
    super.dispose();
  }
}
