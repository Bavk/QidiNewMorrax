import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PoLocalizations {
  PoLocalizations(this.locale, this._messages);

  final Locale locale;
  final Map<String, String> _messages;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('de'),
    Locale('fr'),
    Locale('es'),
    Locale('it'),
    Locale('pt', 'BR'),
    Locale('pl'),
    Locale('cs'),
    Locale('hu'),
    Locale('tr'),
    Locale('sv'),
    Locale('nl'),
    Locale('uk'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
  ];

  String tr(String source) =>
      _messages[source]?.isNotEmpty == true ? _messages[source]! : source;

  static PoLocalizations of(BuildContext context) =>
      Localizations.of<PoLocalizations>(context, PoLocalizations) ??
      PoLocalizations(const Locale('en'), const {});

  static Future<PoLocalizations> load(Locale locale) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final prefix = 'assets/po/${_assetDirectory(locale)}/';
    final candidates = manifest
        .listAssets()
        .where((asset) => asset.startsWith(prefix) && asset.endsWith('.po'))
        .toList(growable: false);
    if (candidates.isEmpty) {
      return PoLocalizations(locale, const {});
    }
    final raw = await rootBundle.loadString(candidates.first);
    return PoLocalizations(locale, _parsePo(raw));
  }

  static String _assetDirectory(Locale locale) {
    if (locale.languageCode == 'zh') {
      return locale.countryCode?.toUpperCase() == 'TW' ? 'zh_TW' : 'zh_cn';
    }
    if (locale.languageCode == 'pt' &&
        locale.countryCode?.toUpperCase() == 'BR') {
      return 'pt-BR';
    }
    return locale.languageCode;
  }

  static Map<String, String> _parsePo(String input) {
    final result = <String, String>{};
    String? currentId;
    String? currentStr;
    _Field active = _Field.none;

    void commit() {
      if (currentId != null && currentId!.isNotEmpty && currentStr != null) {
        result[currentId!] = currentStr!;
      }
      currentId = null;
      currentStr = null;
      active = _Field.none;
    }

    for (final rawLine in const LineSplitter().convert(input)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        commit();
        continue;
      }
      if (line.startsWith('#')) continue;
      if (line.startsWith('msgid ')) {
        if (currentId != null || currentStr != null) commit();
        currentId = _decodeQuoted(line.substring(6).trim());
        currentStr = '';
        active = _Field.id;
        continue;
      }
      if (line.startsWith('msgstr ')) {
        currentStr = _decodeQuoted(line.substring(7).trim());
        active = _Field.str;
        continue;
      }
      if (line.startsWith('msgstr[')) {
        final split = line.indexOf(' ');
        if (split > 0 && (currentStr == null || currentStr!.isEmpty)) {
          currentStr = _decodeQuoted(line.substring(split + 1).trim());
        }
        active = _Field.str;
        continue;
      }
      if (line.startsWith('"')) {
        final value = _decodeQuoted(line);
        if (active == _Field.id) currentId = '${currentId ?? ''}$value';
        if (active == _Field.str) currentStr = '${currentStr ?? ''}$value';
      }
    }
    commit();
    return result;
  }

  static String _decodeQuoted(String value) {
    if (!value.startsWith('"')) return value;
    try {
      return jsonDecode(value) as String;
    } catch (_) {
      if (value.length >= 2 && value.endsWith('"')) {
        return value.substring(1, value.length - 1);
      }
      return value;
    }
  }
}

enum _Field { none, id, str }

class PoLocalizationsDelegate extends LocalizationsDelegate<PoLocalizations> {
  const PoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => PoLocalizations.supportedLocales
      .any((it) => it.languageCode == locale.languageCode);

  @override
  Future<PoLocalizations> load(Locale locale) => PoLocalizations.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<PoLocalizations> old) =>
      false;
}

extension QidiTranslation on BuildContext {
  String tr(String source) => PoLocalizations.of(this).tr(source);
}
