import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/i18n/po_localizations.dart';
import '../core/theme/qidi_theme.dart';
import '../features/workspace/presentation/main_shell.dart';

class QidiFlowApp extends StatelessWidget {
  const QidiFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qidi Flow',
      debugShowCheckedModeBanner: false,
      theme: QidiTheme.light(),
      darkTheme: QidiTheme.dark(),
      themeMode: ThemeMode.system,
      supportedLocales: PoLocalizations.supportedLocales,
      localizationsDelegates: const [
        PoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainShell(),
    );
  }
}
