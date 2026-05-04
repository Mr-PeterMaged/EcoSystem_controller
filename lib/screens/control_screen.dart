import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/connection_service.dart';
import '../widgets/control_button.dart';
import '../app_constants.dart';
import 'about_screen.dart';
import 'notifications_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  Map<String, dynamic> _status = {
    'system': true,
    'gasSensor': true,
    'tempSensor': true,
    'ledSensor': true,
    'pirSensor': true,
    'ldrSensor': true,
    'buzzer': true,
    'autoLight': true,
    'temperature': 0,
    'humidity': 0,
    'gasDetected': false,
    'led2': false,
    'locked': true,
    'gasPercent': 0,
  };

  Timer? _timer;
  bool _isConnected = ConnectionService.isConnected;

  @override
  void initState() {
    super.initState();
    AppSettingsService.settingsNotifier.addListener(_startPolling);
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _fetchStatus();
    final seconds = AppSettingsService.settings.refreshIntervalSeconds;
    _timer = Timer.periodic(Duration(seconds: seconds), (_) => _fetchStatus());
  }

  Future<void> _fetchStatus() async {
    final data = await ConnectionService.getStatus();
    if (data != null && mounted) {
      setState(() {
        _status = data;
        _isConnected = true;
      });
    } else if (mounted) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _toggle(String key) async {
    if (!_hasDeviceConnection) {
      _showNoConnectionMessage();
      return;
    }

    if (!(_status['system'] as bool) && key != 'system') return;
    final newVal = !(_status[key] as bool);

    final Map<String, dynamic> command;
    if (key == 'system' && !newVal) {
      command = {for (final k in kAllDeviceKeys) k: false};
    } else {
      command = {key: newVal};
    }

    final result = await ConnectionService.sendControl(command);
    if (result != null && mounted) {
      setState(() => _status = result);
    } else if (mounted) {
      setState(() => _isConnected = false);
      _showNoConnectionMessage();
    }
  }

  Future<void> _applyPowerSave(Map<String, bool> preset) async {
    if (!_hasDeviceConnection) {
      _showNoConnectionMessage();
      return;
    }

    final result = await ConnectionService.sendControl(
      Map<String, dynamic>.from(preset),
    );
    if (result != null && mounted) {
      setState(() => _status = result);
    } else if (mounted) {
      setState(() => _isConnected = false);
      _showNoConnectionMessage();
    }
  }

  bool get _hasDeviceConnection => ConnectionService.isConnected;

  void _showNoConnectionMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'No action was taken because the system is not connected to the devices.',
          ),
        ),
      );
  }

  void _showReorderSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReorderSheet(
        order: AppSettingsService.settings.buttonOrder,
        onSave: (newOrder) async {
          await AppSettingsService.update(
            AppSettingsService.settings.copyWith(buttonOrder: newOrder),
          );
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  void dispose() {
    AppSettingsService.settingsNotifier.removeListener(_startPolling);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final accent = Theme.of(context).colorScheme.primary;
    final systemOn = _status['system'] as bool;
    final gasDetected = _status['gasDetected'] as bool;
    final buttonOrder = AppSettingsService.settings.buttonOrder;

    return Scaffold(
      backgroundColor: isDark ? kBgDark : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? kAppBarDark : Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Full Control',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.bolt,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            tooltip: 'Power Save',
            onSelected: (mode) {
              if (mode == 'eco') _applyPowerSave(kPowerSaveEco);
              if (mode == 'deep') _applyPowerSave(kPowerSaveDeep);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'eco',
                child: Row(
                  children: [
                    Icon(Icons.eco, color: Colors.teal, size: 20),
                    SizedBox(width: 10),
                    Text('Eco Mode'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deep',
                child: Row(
                  children: [
                    Icon(
                      Icons.power_settings_new,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Text('Deep Save'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Reorder buttons',
            onPressed: _showReorderSheet,
            icon: Icon(
              Icons.swap_vert,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.all(6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_none,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  if (gasDetected)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'About Us',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
            icon: Icon(
              Icons.info_outline,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isConnected ? 'Connected' : 'No Connection',
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: buttonOrder.length,
                  itemBuilder: (_, i) {
                    final key = buttonOrder[i];
                    final label = kDeviceLabels[key] ?? key;
                    final enabled = key == 'system'
                        ? true
                        : systemOn || !_isConnected;
                    return ControlButton(
                      label: label,
                      isOn: (_status[key] as bool?) ?? false,
                      enabled: enabled,
                      onTap: () => _toggle(key),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderSheet extends StatefulWidget {
  final List<String> order;
  final Future<void> Function(List<String>) onSave;

  const _ReorderSheet({required this.order, required this.onSave});

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late List<String> _order;

  @override
  void initState() {
    super.initState();
    _order = List.from(widget.order);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : kTextPrimary;
    final cardBg = isDark ? kCardDark : kCardLight;
    final accent = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kBgDarkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reorder Buttons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                TextButton(
                  onPressed: _save,
                  style: TextButton.styleFrom(foregroundColor: accent),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 380,
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _order.removeAt(oldIndex);
                  _order.insert(newIndex, item);
                });
              },
              children: _order.map((key) {
                return Container(
                  key: ValueKey(key),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                      const SizedBox(width: 14),
                      Text(
                        kDeviceLabels[key] ?? key,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _save() async {
    await widget.onSave(_order);
    if (mounted) Navigator.pop(context);
  }
}
