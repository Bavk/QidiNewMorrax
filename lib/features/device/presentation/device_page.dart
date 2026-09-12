import 'package:flutter/material.dart';

import '../application/device_controller.dart';
import '../domain/printer_device.dart';
import '../domain/printer_state.dart';

class DevicePage extends StatefulWidget {
  const DevicePage({super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  late final DeviceController controller;
  var tab = 0;

  @override
  void initState() {
    super.initState();
    controller = DeviceController()..restore();
    controller.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  Future<void> _manualPrinter() async {
    final ip = TextEditingController();
    final name = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add printer by IP'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ip,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'IP address'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == true && ip.text.trim().isNotEmpty) {
      await controller.addManual(ip.text, name: name.text);
    }
    ip.dispose();
    name.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = controller.selected;
    return Column(
      children: [
        _DeviceHeader(
          controller: controller,
          onDiscover: () => _run(controller.discover),
          onManual: _manualPrinter,
          onConnect: () => _run(
            controller.state.connected
                ? controller.disconnect
                : controller.connect,
          ),
        ),
        if (controller.lastError != null)
          MaterialBanner(
            content: Text(controller.lastError.toString()),
            actions: [
              TextButton(
                onPressed: controller.clearError,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        const Divider(),
        _DeviceTabBar(
          index: tab,
          onChanged: (value) => setState(() => tab = value),
        ),
        const Divider(),
        Expanded(
          child: selected == null
              ? _EmptyDevice(
                  discovering: controller.discovering,
                  onDiscover: () => _run(controller.discover),
                  onManual: _manualPrinter,
                )
              : switch (tab) {
                  0 => _OverviewTab(
                    controller: controller,
                    device: selected,
                    run: _run,
                  ),
                  1 => _ControlTab(controller: controller, run: _run),
                  2 => _FilesTab(controller: controller, run: _run),
                  _ => _AutomationTab(controller: controller, run: _run),
                },
        ),
      ],
    );
  }
}

class _DeviceHeader extends StatelessWidget {
  const _DeviceHeader({
    required this.controller,
    required this.onDiscover,
    required this.onManual,
    required this.onConnect,
  });

  final DeviceController controller;
  final VoidCallback onDiscover;
  final VoidCallback onManual;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selected;
    final state = controller.state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          const Icon(Icons.print_outlined),
          const SizedBox(width: 10),
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<PrinterDevice>(
              initialValue:
                  selected != null && controller.devices.contains(selected)
                  ? selected
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Printer',
                isDense: true,
              ),
              items: [
                for (final device in controller.devices)
                  DropdownMenuItem(
                    value: device,
                    child: Text(
                      '${device.name}  ${device.ip}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.select(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: controller.discovering ? null : onDiscover,
            tooltip: 'Discover QIDI printers on LAN',
            icon: controller.discovering
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar),
          ),
          IconButton(
            onPressed: onManual,
            tooltip: 'Add printer by IP',
            icon: const Icon(Icons.add_link),
          ),
          const Spacer(),
          if (selected != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  state.connected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: state.connected
                        ? Colors.green
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(selected.ip, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: controller.connecting ? null : onConnect,
              icon: Icon(
                state.connected ? Icons.link_off : Icons.link,
                size: 18,
              ),
              label: Text(state.connected ? 'Disconnect' : 'Connect'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTabBar extends StatelessWidget {
  const _DeviceTabBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const items = <(IconData, String)>[
    (Icons.dashboard_outlined, 'Overview'),
    (Icons.tune_outlined, 'Control'),
    (Icons.folder_outlined, 'Files'),
    (Icons.auto_awesome_outlined, 'Automation'),
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              selected: index == i,
              onSelected: (_) => onChanged(i),
              avatar: Icon(items[i].$1, size: 17),
              label: Text(items[i].$2),
            ),
          ),
      ],
    ),
  );
}

class _EmptyDevice extends StatelessWidget {
  const _EmptyDevice({
    required this.discovering,
    required this.onDiscover,
    required this.onManual,
  });
  final bool discovering;
  final VoidCallback onDiscover;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.print_outlined, size: 52),
            const SizedBox(height: 12),
            Text(
              'Connect a QIDI printer',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The Flutter port uses the source LAN SSDP discovery and Moonraker command contract.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: discovering ? null : onDiscover,
                  icon: const Icon(Icons.radar),
                  label: const Text('Discover'),
                ),
                OutlinedButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Add by IP'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.controller,
    required this.device,
    required this.run,
  });
  final DeviceController controller;
  final PrinterDevice device;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final camera = _CameraCard(
              device: device,
              connected: state.connected,
            );
            final telemetry = _TelemetryCard(
              state: state,
              fileCount: controller.files.length,
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: camera),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: telemetry),
                    ],
                  )
                : Column(
                    children: [camera, const SizedBox(height: 12), telemetry],
                  );
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.pauseOrResume)
                      : null,
                  icon: Icon(state.jobPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(state.jobPaused ? 'Resume' : 'Pause'),
                ),
                OutlinedButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.cancelPrint)
                      : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.home)
                      : null,
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Home'),
                ),
                OutlinedButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.cooldown)
                      : null,
                  icon: const Icon(Icons.ac_unit),
                  label: const Text('Cooldown'),
                ),
                OutlinedButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.toggleLight)
                      : null,
                  icon: Icon(
                    state.caseLight ? Icons.lightbulb : Icons.lightbulb_outline,
                  ),
                  label: Text(state.caseLight ? 'Light off' : 'Light on'),
                ),
                OutlinedButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.refreshFiles)
                      : null,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh files'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.device, required this.connected});
  final PrinterDevice device;
  final bool connected;

  @override
  Widget build(BuildContext context) => Card(
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: connected
            ? Image.network(
                device.snapshotUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const _CameraFallback(),
              )
            : const _CameraFallback(),
      ),
    ),
  );
}

class _CameraFallback extends StatelessWidget {
  const _CameraFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF1D2124),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_outlined, color: Colors.white70, size: 44),
          SizedBox(height: 8),
          Text('Camera snapshot', style: TextStyle(color: Colors.white70)),
        ],
      ),
    ),
  );
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({required this.state, required this.fileCount});
  final PrinterState state;
  final int fileCount;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.fileName.isEmpty ? 'Printer status' : state.fileName,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 12),
          _metric('State', state.printState),
          _metric(
            'Nozzle',
            '${state.nozzleTemperature.toStringAsFixed(1)} / ${state.nozzleTarget.toStringAsFixed(0)} °C',
          ),
          _metric(
            'Bed',
            '${state.bedTemperature.toStringAsFixed(1)} / ${state.bedTarget.toStringAsFixed(0)} °C',
          ),
          _metric(
            'Chamber',
            '${state.chamberTemperature.toStringAsFixed(1)} / ${state.chamberTarget.toStringAsFixed(0)} °C',
          ),
          _metric('Layer', '${state.currentLayer} / ${state.totalLayer}'),
          _metric('Speed', '${state.speedPercent}%'),
          _metric('Files', '$fileCount'),
        ],
      ),
    ),
  );

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _ControlTab extends StatelessWidget {
  const _ControlTab({required this.controller, required this.run});
  final DeviceController controller;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _TemperatureControl(controller: controller, state: state, run: run),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Movement',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in const [-10, -1, 1, 10])
                      OutlinedButton(
                        onPressed: state.connected
                            ? () => run(() => controller.moveX(value))
                            : null,
                        child: Text('X ${value > 0 ? '+' : ''}$value'),
                      ),
                    for (final value in const [-10, -1, 1, 10])
                      OutlinedButton(
                        onPressed: state.connected
                            ? () => run(() => controller.moveY(value))
                            : null,
                        child: Text('Y ${value > 0 ? '+' : ''}$value'),
                      ),
                    for (final value in const [-10, -1, 1, 10])
                      OutlinedButton(
                        onPressed: state.connected
                            ? () => run(() => controller.moveZ(value))
                            : null,
                        child: Text('Z ${value > 0 ? '+' : ''}$value'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FanControl(
          label: 'Part cooling',
          value: state.coolingFan,
          enabled: state.connected,
          onChanged: (value) => run(() => controller.setCoolingFan(value)),
        ),
        const SizedBox(height: 8),
        _FanControl(
          label: 'Auxiliary fan',
          value: state.auxiliaryFan,
          enabled: state.connected,
          onChanged: (value) => run(() => controller.setAuxiliaryFan(value)),
        ),
        const SizedBox(height: 8),
        _FanControl(
          label: 'Chamber fan',
          value: state.chamberFan,
          enabled: state.connected,
          onChanged: (value) => run(() => controller.setChamberFan(value)),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final speed in const [50, 100, 124, 166])
                  ChoiceChip(
                    selected: state.speedPercent == speed,
                    onSelected: state.connected
                        ? (_) => run(() => controller.setSpeed(speed))
                        : null,
                    label: Text('$speed%'),
                  ),
                OutlinedButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.togglePolarCooler)
                      : null,
                  icon: const Icon(Icons.ac_unit),
                  label: Text(
                    state.polarCooler ? 'Polar cooler off' : 'Polar cooler on',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: state.connected
                      ? () => run(controller.fansOff)
                      : null,
                  icon: const Icon(Icons.air),
                  label: const Text('Fans off'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TemperatureControl extends StatelessWidget {
  const _TemperatureControl({
    required this.controller,
    required this.state,
    required this.run,
  });
  final DeviceController controller;
  final PrinterState state;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Temperatures', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _TempButton(
                label: 'Nozzle',
                current: state.nozzleTemperature,
                target: state.nozzleTarget,
                enabled: state.connected,
                onSet: (value) =>
                    run(() => controller.setNozzleTemperature(value)),
              ),
              _TempButton(
                label: 'Bed',
                current: state.bedTemperature,
                target: state.bedTarget,
                enabled: state.connected,
                onSet: (value) =>
                    run(() => controller.setBedTemperature(value)),
              ),
              _TempButton(
                label: 'Chamber',
                current: state.chamberTemperature,
                target: state.chamberTarget,
                enabled: state.connected,
                onSet: (value) =>
                    run(() => controller.setChamberTemperature(value)),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TempButton extends StatelessWidget {
  const _TempButton({
    required this.label,
    required this.current,
    required this.target,
    required this.enabled,
    required this.onSet,
  });
  final String label;
  final double current;
  final double target;
  final bool enabled;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: enabled
        ? () async {
            final text = TextEditingController(text: target.round().toString());
            final value = await showDialog<int>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('$label target'),
                content: TextField(
                  controller: text,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(suffixText: '°C'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, int.tryParse(text.text)),
                    child: const Text('Set'),
                  ),
                ],
              ),
            );
            text.dispose();
            if (value != null) onSet(value);
          }
        : null,
    child: Text(
      '$label  ${current.toStringAsFixed(1)} / ${target.toStringAsFixed(0)} °C',
    ),
  );
}

class _FanControl extends StatefulWidget {
  const _FanControl({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  State<_FanControl> createState() => _FanControlState();
}

class _FanControlState extends State<_FanControl> {
  double? pending;

  @override
  Widget build(BuildContext context) {
    final value = pending ?? (widget.value * 100).clamp(0, 100).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 140, child: Text(widget.label)),
            Expanded(
              child: Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${value.round()}%',
                onChanged: widget.enabled
                    ? (next) => setState(() => pending = next)
                    : null,
                onChangeEnd: widget.enabled
                    ? (next) {
                        setState(() => pending = null);
                        widget.onChanged(next.round());
                      }
                    : null,
              ),
            ),
            SizedBox(width: 48, child: Text('${value.round()}%')),
          ],
        ),
      ),
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.controller, required this.run});
  final DeviceController controller;
  final Future<void> Function(Future<void> Function()) run;

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
          child: Row(
            children: [
              Text(
                'Printer files',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: state.connected
                    ? () => run(controller.refreshFiles)
                    : null,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: controller.files.isEmpty
              ? const Center(child: Text('No files loaded'))
              : ListView.builder(
                  itemCount: controller.files.length,
                  itemBuilder: (context, index) {
                    final file = controller.files[index];
                    final path =
                        (file['path'] ?? file['filename'] ?? file['name'])
                            ?.toString() ??
                        '';
                    final size = file['size'];
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(path.isEmpty ? 'File $index' : path),
                      subtitle: size == null ? null : Text('$size bytes'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Print',
                            onPressed: state.connected && path.isNotEmpty
                                ? () => run(() => controller.startPrint(path))
                                : null,
                            icon: const Icon(Icons.play_arrow),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: state.connected && path.isNotEmpty
                                ? () => run(() => controller.deleteFile(path))
                                : null,
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AutomationTab extends StatefulWidget {
  const _AutomationTab({required this.controller, required this.run});
  final DeviceController controller;
  final Future<void> Function(Future<void> Function()) run;

  @override
  State<_AutomationTab> createState() => _AutomationTabState();
}

class _AutomationTabState extends State<_AutomationTab> {
  final gcode = TextEditingController();

  @override
  void dispose() {
    gcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'Automation & advanced functions',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QIDI Box / materials',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                for (var slot = 0; slot < 4; slot++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(child: Text('${slot + 1}')),
                    title: Text(
                      'Slot ${slot + 1}  •  ${state.boxTemperature[slot]} °C  •  ${state.boxHumidity[slot]}% RH',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: state.connected
                              ? () => widget.run(
                                  () => widget.controller.loadSlot(slot),
                                )
                              : null,
                          child: const Text('Load'),
                        ),
                        TextButton(
                          onPressed: state.connected
                              ? () => widget.run(
                                  () => widget.controller.unloadSlot(slot),
                                )
                              : null,
                          child: const Text('Unload'),
                        ),
                        TextButton(
                          onPressed: state.connected
                              ? () => widget.run(
                                  () => widget.controller.ejectSlot(slot),
                                )
                              : null,
                          child: const Text('Eject'),
                        ),
                        IconButton(
                          tooltip: 'Read RFID',
                          onPressed: state.connected
                              ? () => widget.run(
                                  () => widget.controller.refreshRfid(slot),
                                )
                              : null,
                          icon: const Icon(Icons.nfc),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Timelapses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: state.connected
                          ? () async {
                              try {
                                final files = await widget.controller
                                    .listTimelapses();
                                if (!mounted) return;
                                await showDialog<void>(
                                  context: this.context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Timelapses'),
                                    content: SizedBox(
                                      width: 520,
                                      height: 360,
                                      child: files.isEmpty
                                          ? const Center(
                                              child: Text('No timelapses'),
                                            )
                                          : ListView(
                                              children: [
                                                for (final file in files)
                                                  ListTile(
                                                    leading: const Icon(
                                                      Icons.movie_outlined,
                                                    ),
                                                    title: Text(
                                                      (file['path'] ??
                                                              file['filename'] ??
                                                              file['name'])
                                                          .toString(),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Browse'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'G-code console',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: gcode,
                  enabled: state.connected,
                  minLines: 3,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Enter Klipper / G-code commands',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: state.connected && gcode.text.trim().isNotEmpty
                      ? () => widget.run(
                          () => widget.controller.sendGcode(gcode.text),
                        )
                      : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cloud/P2P account transport, HMS diagnostics, firmware flows and the remaining service panels are still explicit parity items; they are not represented by fake local controls here.',
            ),
          ),
        ),
      ],
    );
  }
}
