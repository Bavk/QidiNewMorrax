import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/printer_device.dart';
import '../domain/printer_state.dart';

class MoonrakerClient {
  MoonrakerClient(this.device);

  final PrinterDevice device;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _stateController = StreamController<PrinterState>.broadcast();
  final _eventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _pending = <int, Completer<dynamic>>{};
  var _requestId = 1;
  var _state = const PrinterState();

  Stream<PrinterState> get states => _stateController.stream;
  Stream<Map<String, dynamic>> get events => _eventController.stream;
  PrinterState get state => _state;
  bool get isConnected => _channel != null && _state.connected;

  static const subscribedObjects = <String, dynamic>{
    'gcode_move': null,
    'exclude_object': null,
    'filament_switch_sensor filament_switch_sensor': null,
    'print_stats': null,
    'print_stats_manager': null,
    'display_status': null,
    'heater_bed': null,
    'extruder': null,
    'heater_generic chamber': null,
    'output_pin caselight': null,
    'output_pin polar_cooler': null,
    'fan_generic auxiliary_cooling_fan': null,
    'fan_generic chamber_circulation_fan': null,
    'fan_generic cooling_fan': null,
    'toolhead': null,
    'save_variables': null,
    'aht20_f heater_box1': null,
    'aht20_f heater_box2': null,
    'aht20_f heater_box3': null,
    'aht20_f heater_box4': null,
    'box_stepper slot0': null,
    'box_stepper slot1': null,
    'box_stepper slot2': null,
    'box_stepper slot3': null,
  };

  Future<void> connect() async {
    await disconnect();
    final channel = WebSocketChannel.connect(Uri.parse(device.websocketUrl));
    _channel = channel;
    await channel.ready.timeout(const Duration(seconds: 6));
    _state = _state.applyStatusPatch(const {}, markConnected: true);
    _stateController.add(_state);
    _subscription = channel.stream.listen(
      _onMessage,
      onError: _onDisconnected,
      onDone: _onDisconnected,
      cancelOnError: false,
    );
    final result = await request<Map<String, dynamic>>(
      'printer.objects.subscribe',
      {'objects': subscribedObjects},
    );
    final status = result['status'];
    if (status is Map) {
      _applyPatch(status.cast<String, dynamic>());
    }
    unawaited(_requestAllErrors());
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Moonraker disconnected'));
      }
    }
    _pending.clear();
    if (_state.connected) {
      _state = _state.disconnected();
      if (!_stateController.isClosed) _stateController.add(_state);
    }
  }

  Future<T> request<T>(
    String method, [
    Map<String, dynamic>? params,
    Duration timeout = const Duration(seconds: 8),
  ]) async {
    final channel = _channel;
    if (channel == null) throw StateError('Moonraker is not connected');
    final id = _requestId++;
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    channel.sink.add(jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'id': id,
      if (params != null) 'params': params,
    }));
    try {
      final result = await completer.future.timeout(timeout);
      return result as T;
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> sendGcode(String script) async {
    await request<dynamic>('printer.gcode.script', {'script': script});
  }

  Future<void> pausePrint() async => request<dynamic>('printer.print.pause');
  Future<void> resumePrint() async => request<dynamic>('printer.print.resume');
  Future<void> cancelPrint() async => request<dynamic>('printer.print.cancel');
  Future<void> startPrint(String filename) async =>
      request<dynamic>('printer.print.start', {'filename': filename});
  Future<void> deleteFile(String path) async =>
      request<dynamic>('server.files.delete_file', {'path': path});

  Future<List<Map<String, dynamic>>> listFiles({String root = 'gcodes'}) async {
    final result = await request<dynamic>('server.files.list', {'root': root});
    if (result is List) {
      return result
          .whereType<Map>()
          .map((it) => it.cast<String, dynamic>())
          .toList();
    }
    if (result is Map && result['files'] is List) {
      return (result['files'] as List)
          .whereType<Map>()
          .map((it) => it.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  Future<void> _requestAllErrors() async {
    try {
      await request<dynamic>('server.extensions.request', {
        'method': 'get_all_error_list',
      });
    } catch (_) {
      // Firmware-dependent QIDI extension; absence must not break LAN session.
    }
  }

  void _onMessage(dynamic data) {
    if (data is! String) return;
    final decoded = jsonDecode(data);
    if (decoded is! Map) return;
    final message = decoded.cast<String, dynamic>();
    final id = message['id'];
    if (id is int && _pending.containsKey(id)) {
      final completer = _pending[id]!;
      if (message.containsKey('error')) {
        completer.completeError(MoonrakerRpcException(message['error']));
      } else {
        completer.complete(message['result']);
      }
      return;
    }

    final method = message['method']?.toString();
    if (method == 'notify_status_update') {
      final params = message['params'];
      if (params is List && params.isNotEmpty && params.first is Map) {
        _applyPatch((params.first as Map).cast<String, dynamic>());
      }
    }
    _eventController.add(message);
  }

  void _applyPatch(Map<String, dynamic> patch) {
    _state = _state.applyStatusPatch(patch, markConnected: true);
    _stateController.add(_state);
  }

  void _onDisconnected([Object? error, StackTrace? stackTrace]) {
    if (_channel == null) return;
    _channel = null;
    _state = _state.disconnected();
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _eventController.close();
  }
}

class MoonrakerRpcException implements Exception {
  MoonrakerRpcException(this.payload);
  final dynamic payload;

  @override
  String toString() => 'Moonraker RPC error: $payload';
}
