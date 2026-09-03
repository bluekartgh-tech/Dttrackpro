import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/device.dart';
import '../utils/theme.dart';
import 'vehicle_detail_screen.dart';
import 'live_tracking_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Device> _filtered(List<Device> all) {
    var list = all;
    switch (_filter) {
      case 'Online':
        list = list.where((d) => d.isOnline).toList();
        break;
      case 'Offline':
        list = list.where((d) => !d.isOnline).toList();
        break;
      case 'Moving':
        list = list.where((d) => d.isMoving).toList();
        break;
      case 'Idle':
        list = list.where((d) => d.isOnline && !d.isMoving).toList();
        break;
      case 'Ignition On':
        list = list.where((d) {
          final ign = d.ignition?.toLowerCase() ?? '';
          return ign.contains('on') || ign == 'true' || ign == '1';
        }).toList();
        break;
    }
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((d) =>
          d.name.toLowerCase().contains(q) ||
          (d.plateNumber?.toLowerCase().contains(q) ?? false) ||
          (d.imei?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  int _count(List<Device> all, String filter) {
    switch (filter) {
      case 'Online': return all.where((d) => d.isOnline).length;
      case 'Offline': return all.where((d) => !d.isOnline).length;
      case 'Moving': return all.where((d) => d.isMoving).length;
      case 'Idle': return all.where((d) => d.isOnline && !d.isMoving).length;
      case 'Ignition On':
        return all.where((d) {
          final ign = d.ignition?.toLowerCase() ?? '';
          return ign.contains('on') || ign == 'true' || ign == '1';
        }).length;
      default: return all.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final devices = _filtered(provider.devices);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refreshDevices(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search name, plate, IMEI...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final f in ['All', 'Online', 'Offline', 'Moving', 'Idle', 'Ignition On'])
                  _filterChip(f, _count(provider.devices, f)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.refreshDevices(),
              color: AppColors.primary,
              child: devices.isEmpty
                  ? const Center(child: Text('No vehicles found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: devices.length,
                      itemBuilder: (_, i) => _vehicleCard(context, devices[i], provider),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int count) {
    final selected = _filter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _filter = label),
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

  Widget _vehicleCard(BuildContext context, Device d, AppProvider provider) {
    final statusColor = d.isMoving
        ? AppColors.online
        : d.isOnline
            ? AppColors.idle
            : AppColors.offline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              provider.selectDevice(d);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => VehicleDetailScreen(device: d)),
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.directions_car_filled, color: statusColor, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        if (d.plateNumber != null && d.plateNumber!.isNotEmpty)
                          Text(d.plateNumber!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '${d.speed.toStringAsFixed(0)} km/h • ${d.statusLabel}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          d.statusLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                      if (d.time != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          d.time!.length > 16 ? d.time!.substring(11, 16) : d.time!,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (d.sensors.isNotEmpty || d.battery != null || d.ignition != null || d.fuel != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (d.battery != null) _sensorChip(Icons.battery_full, d.battery!),
                  if (d.ignition != null) _sensorChip(Icons.power_settings_new, 'Ign ${d.ignition}'),
                  if (d.fuel != null) _sensorChip(Icons.local_gas_station, d.fuel!),
                  for (final s in d.sensors.take(3))
                    if (!s.name.toLowerCase().contains('battery') &&
                        !s.name.toLowerCase().contains('ignition') &&
                        !s.name.toLowerCase().contains('fuel'))
                      _sensorChip(Icons.sensors, '${s.name}: ${s.value}'),
                ],
              ),
            ),
          // Address under sensors
          if (d.address != null && d.address != '-' && d.address!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      d.address!,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LiveTrackingScreen(device: d)),
                  );
                },
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Live Tracking'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
