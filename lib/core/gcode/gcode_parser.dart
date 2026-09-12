import 'dart:convert';
import 'dart:math' as math;

class GCodeCommand {
  GCodeCommand({required this.raw, required this.command, required this.parameters, this.comment, this.lineNumber, this.checksum});
  final String raw;
  final String command;
  final Map<String, String> parameters;
  final String? comment;
  final int? lineNumber;
  final int? checksum;
  double? number(String key) => double.tryParse(parameters[key.toUpperCase()] ?? '');
  String? value(String key) => parameters[key.toUpperCase()];
}

class GCodeParser {
  const GCodeParser();
  GCodeCommand? parseLine(String source) {
    final raw = source;
    var line = source.trim();
    if (line.isEmpty) return null;
    String? comment;
    final semicolon = line.indexOf(';');
    if (semicolon >= 0) {
      comment = line.substring(semicolon + 1).trim();
      line = line.substring(0, semicolon).trim();
    }
    line = line.replaceAll(RegExp(r'\([^)]*\)'), ' ').trim();
    if (line.isEmpty) return GCodeCommand(raw: raw, command: '', parameters: const {}, comment: comment);
    int? checksum;
    final star = line.lastIndexOf('*');
    if (star >= 0) {
      checksum = int.tryParse(line.substring(star + 1).trim());
      line = line.substring(0, star).trim();
    }
    final tokens = line.split(RegExp(r'\s+')).where((it) => it.isNotEmpty).toList();
    int? lineNumber;
    if (tokens.isNotEmpty && RegExp(r'^N\d+$', caseSensitive: false).hasMatch(tokens.first)) {
      lineNumber = int.tryParse(tokens.removeAt(0).substring(1));
    }
    if (tokens.isEmpty) return null;
    final command = tokens.removeAt(0).toUpperCase();
    final params = <String, String>{};
    for (final token in tokens) {
      if (token.isEmpty) continue;
      final key = token[0].toUpperCase();
      params[key] = token.length > 1 ? token.substring(1) : '';
    }
    return GCodeCommand(raw: raw, command: command, parameters: Map.unmodifiable(params), comment: comment, lineNumber: lineNumber, checksum: checksum);
  }

  Iterable<GCodeCommand> parse(String text) sync* {
    for (final line in const LineSplitter().convert(text)) {
      final parsed = parseLine(line);
      if (parsed != null) yield parsed;
    }
  }

  GCodeStats stats(String text) {
    var x = 0.0, y = 0.0, z = 0.0, e = 0.0;
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity, maxZ = double.negativeInfinity;
    var moveCount = 0, extrusionMoveCount = 0;
    var travelDistance = 0.0, extrusion = 0.0;
    var absolute = true, absoluteE = true;
    final temperatures = <double>{};
    for (final cmd in parse(text)) {
      switch (cmd.command) {
        case 'G90': absolute = true; continue;
        case 'G91': absolute = false; continue;
        case 'M82': absoluteE = true; continue;
        case 'M83': absoluteE = false; continue;
        case 'G92':
          x = cmd.number('X') ?? x; y = cmd.number('Y') ?? y; z = cmd.number('Z') ?? z; e = cmd.number('E') ?? e; continue;
        case 'M104': case 'M109': case 'M140': case 'M190':
          final temp = cmd.number('S'); if (temp != null) temperatures.add(temp); continue;
      }
      if (cmd.command != 'G0' && cmd.command != 'G1') continue;
      final nextX = cmd.number('X'), nextY = cmd.number('Y'), nextZ = cmd.number('Z'), nextE = cmd.number('E');
      final nx = nextX == null ? x : (absolute ? nextX : x + nextX);
      final ny = nextY == null ? y : (absolute ? nextY : y + nextY);
      final nz = nextZ == null ? z : (absolute ? nextZ : z + nextZ);
      final ne = nextE == null ? e : (absoluteE ? nextE : e + nextE);
      final dx = nx - x, dy = ny - y, dz = nz - z;
      travelDistance += math.sqrt(dx * dx + dy * dy + dz * dz);
      moveCount++;
      final de = ne - e;
      if (de > 0) { extrusionMoveCount++; extrusion += de; }
      x = nx; y = ny; z = nz; e = ne;
      minX = math.min(minX, x); minY = math.min(minY, y); minZ = math.min(minZ, z);
      maxX = math.max(maxX, x); maxY = math.max(maxY, y); maxZ = math.max(maxZ, z);
    }
    return GCodeStats(moveCount: moveCount, extrusionMoveCount: extrusionMoveCount, travelDistanceMm: travelDistance, extrusionMm: extrusion, minX: minX.isFinite ? minX : 0, maxX: maxX.isFinite ? maxX : 0, minY: minY.isFinite ? minY : 0, maxY: maxY.isFinite ? maxY : 0, minZ: minZ.isFinite ? minZ : 0, maxZ: maxZ.isFinite ? maxZ : 0, temperatures: temperatures.toList()..sort());
  }
}

class GCodeStats {
  const GCodeStats({required this.moveCount, required this.extrusionMoveCount, required this.travelDistanceMm, required this.extrusionMm, required this.minX, required this.maxX, required this.minY, required this.maxY, required this.minZ, required this.maxZ, required this.temperatures});
  final int moveCount, extrusionMoveCount;
  final double travelDistanceMm, extrusionMm;
  final double minX, maxX, minY, maxY, minZ, maxZ;
  final List<double> temperatures;
}
