import 'package:flutter/material.dart';

class ProjectPage extends StatelessWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Project',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Project/plate/object settings will replace the original wxWidgets project tree and 3MF metadata editor.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compatibility contract',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'The new project layer must preserve plates, object transforms, modifiers, per-object settings, filament assignments, custom G-code, thumbnails, printer/process/filament profile references and QIDI-specific metadata from existing projects.',
                ),
                const SizedBox(height: 14),
                const LinearProgressIndicator(value: .08),
                const SizedBox(height: 8),
                const Text(
                  'Basic 3MF mesh import exists in Prepare. Full project serialization is still tracked as pending in the migration ledger.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
