import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _tab = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadDashboard();
    });
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'overspeed':
        return Icons.speed;
      case 'geofence_in':
      case 'geofence_out':
      case 'geofence_entry':
      case 'geofence_exit':
        return Icons.fence;
      case 'low_battery':
        return Icons.battery_alert;
      case 'ignition_on':
      case 'ignition_off':
        return Icons.power_settings_new;
      case 'power_cut':
        return Icons.power_off;
      default:
        return Icons.warning_amber;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'overspeed':
        return AppColors.danger;
      case 'geofence_in':
      case 'geofence_entry':
        return AppColors.online;
      case 'geofence_out':
      case 'geofence_exit':
        return AppColors.warning;
      case 'low_battery':
        return AppColors.warning;
      case 'power_cut':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final events = provider.events;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _tabChip('All', events.length),
                _tabChip('Active', events.length),
                _tabChip('Resolved', 0),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadDashboard(),
              color: AppColors.primary,
              child: events.isEmpty
                  ? const Center(child: Text('No alerts yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (_, i) {
                        final e = events[i];
                        final type = e['type']?.toString();
                        final color = _colorForType(type);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_iconForType(type), color: color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e['message']?.toString() ?? e['name']?.toString() ?? 'Alert',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      e['device_name']?.toString() ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                e['time']?.toString().length > 16
                                    ? e['time'].toString().substring(11, 16)
                                    : (e['time']?.toString() ?? ''),
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int count) {
    final selected = _tab == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _tab = label),
        selectedColor: AppColors.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
        side: BorderSide(color: selected ? AppColors.primary : Colors.grey.shade300),
      ),
    );
  }
}
