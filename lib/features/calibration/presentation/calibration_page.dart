import 'package:flutter/material.dart';

class CalibrationPage extends StatelessWidget {
  const CalibrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.speed_outlined, 'Flow rate', 'Calibration patterns and profile update'),
      (Icons.waves_outlined, 'Pressure advance', 'Line/pattern calibration'),
      (Icons.blur_on_outlined, 'Flow dynamics', 'Dynamic extrusion tuning'),
      (Icons.grid_4x4_outlined, 'Bed leveling', 'Bed mesh and leveling workflow'),
      (Icons.vibration_outlined, 'Input shaper', 'Resonance compensation workflow'),
      (Icons.thermostat_outlined, 'Temperature tower', 'Material temperature calibration'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Calibration',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Flutter-native replacements for the original calibration wizards.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth < 720 ? c.maxWidth : (c.maxWidth - 24) / 3;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in items)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$1, size: 30),
                            const SizedBox(height: 14),
                            Text(
                              item.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(item.$3),
                            const SizedBox(height: 14),
                            const OutlinedButton(
                              onPressed: null,
                              child: Text('Parity port pending'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
