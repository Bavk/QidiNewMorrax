import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/printer_device.dart';

class LocalDeviceDiscovery {
  static final InternetAddress multicastAddress = InternetAddress(
    '239.255.255.250',
  );
  static const int port = 5863;

  Future<List<PrinterDevice>> discover({
    Duration timeout = const Duration(seconds: 10),
    int retries = 2,
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final found = <String, PrinterDevice>{};
    final done = Completer<void>();

    final subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      while (true) {
        final datagram = socket.receive();
        if (datagram == null) break;
        final raw = utf8.decode(datagram.data, allowMalformed: true);
        final parsed = _parseSsdp(raw, datagram.address.address);
        if (parsed != null) found[parsed.ip] = parsed;
      }
    });

    const message =
        'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:5863\r\n'
        'MAN: "ssdp:discover"\r\n'
        'ST: ssdp:all\r\n'
        'MX: 10\r\n'
        '\r\n';
    final payload = utf8.encode(message);
    for (var i = 0; i < retries; i++) {
      socket.send(payload, multicastAddress, port);
      if (i + 1 < retries) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    Timer(timeout, () {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await subscription.cancel();
    socket.close();
    final devices = found.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return devices;
  }

  PrinterDevice? _parseSsdp(String raw, String fallbackIp) {
    final headers = <String, String>{};
    for (final line in const LineSplitter().convert(raw).skip(1)) {
      final cleaned = line.trim();
      if (cleaned.isEmpty) continue;
      final colon = cleaned.indexOf(':');
      if (colon <= 0) continue;
      headers[cleaned.substring(0, colon).trim().toLowerCase()] = cleaned
          .substring(colon + 1)
          .trim();
    }
    final serial = headers['usn'];
    final location = headers['location'];
    if (serial == null || location == null) return null;
    var ip = fallbackIp;
    try {
      ip = Uri.parse(location).host;
    } catch (_) {}
    if (ip.isEmpty) return null;
    final model = headers['devmodel.qidi.com'] ?? '';
    final name =
        headers['devname.qidi.com'] ?? (model.isEmpty ? 'QIDI $ip' : model);
    return PrinterDevice(
      id: serial,
      serialNumber: serial,
      ip: ip,
      name: name,
      model: model,
    );
  }
}
