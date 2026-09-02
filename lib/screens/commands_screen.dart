import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class CommandsScreen extends StatefulWidget {
  final Device? device;

  const CommandsScreen({super.key, this.device});

  @override
  State<CommandsScreen> createState() => _CommandsScreenState();
}

class _CommandsScreenState extends State<CommandsScreen> {
  Map<String, dynamic>? _cmdData;
  bool _loading = true;
  Device? _selected;

  final List<Map<String, dynamic>> _quickCommands = [
    {'title': 'Engine On', 'icon': Icons.power_settings_new, 'message': 'RELAY,0#', 'color': AppColors.online},
    {'title': 'Engine Off', 'icon': Icons.power_off, 'message': 'RELAY,1#', 'color': AppColors.danger},
    {'title': 'Lock', 'icon': Icons.lock, 'message': 'DOOR,1#', 'color': AppColors.info},
    {'title': 'Unlock', 'icon': Icons.lock_open, 'message': 'DOOR,0#', 'color': AppColors.online},
    {'title': 'Restart Device', 'icon': Icons.restart_alt, 'message': 'RESET#', 'color': AppColors.warning},
    {'title': 'Stop Tracking', 'icon': Icons.stop_circle, 'message': 'STOP#', 'color': AppColors.danger},
    {'title': 'Get Location', 'icon': Icons.my_location, 'message': 'WHERE#', 'color': AppColors.info},
    {'title': 'Device Info', 'icon': Icons.info_outline, 'message': 'STATUS#', 'color': AppColors.textSecondary},
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.device;
    _load();
  }

  Future<void> _load() async {
    final data = await context.read<AppProvider>().loadCommandData();
    setState(() {
      _cmdData = data;
      _loading = false;
    });
  }

  Future<void> _send(String message, String title) async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a vehicle first')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send "$title"?'),
        content: Text('Send command to ${_selected!.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final provider = context.read<AppProvider>();
    final success = await provider.sendCommand(
      deviceId: _selected!.id,
      type: 'gprs',
      message: message,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Command sent successfully' : (provider.error ?? 'Failed')),
          backgroundColor: success ? AppColors.online : AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Commands')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Vehicle selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Device>(
                      isExpanded: true,
                      hint: const Text('Select Vehicle'),
                      value: _selected,
                      items: provider.devices.map((d) {
                        return DropdownMenuItem(value: d, child: Text(d.name));
                      }).toList(),
                      onChanged: (d) => setState(() => _selected = d),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Quick Commands',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.6,
                  children: _quickCommands.map((cmd) {
                    return GestureDetector(
                      onTap: () => _send(cmd['message'] as String, cmd['title'] as String),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cmd['icon'] as IconData, color: cmd['color'] as Color, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              cmd['title'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}
