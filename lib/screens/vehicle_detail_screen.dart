import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/device.dart';
import '../utils/theme.dart';
import 'history_screen.dart';
import 'commands_screen.dart';
import 'live_tracking_screen.dart';

class VehicleDetailScreen extends StatelessWidget {
  final Device device;

  const VehicleDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final statusColor = device.isMoving
        ? AppColors.online
        : device.isOnline
            ? AppColors.idle
            : AppColors.offline;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(device.lat, device.lng),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.dttrack.pro',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(device.lat, device.lng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                        child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        device.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (device.time != null)
                  Text(
                    device.time!,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _infoRow(Icons.speed, 'Speed', '${device.speed.toStringAsFixed(0)} km/h'),
                _infoRow(Icons.battery_full, 'Battery', device.battery ?? '--'),
                _infoRow(Icons.power_settings_new, 'Ignition', device.ignition ?? '--'),
                _infoRow(Icons.local_gas_station, 'Fuel', device.fuel ?? '--'),
                if (device.plateNumber != null && device.plateNumber!.isNotEmpty)
                  _infoRow(Icons.confirmation_number, 'Plate', device.plateNumber!),
                if (device.imei != null)
                  _infoRow(Icons.sim_card, 'IMEI', device.imei!),
                if (device.driver != null)
                  _infoRow(Icons.person, 'Driver', device.driver!),
                if (device.protocol != null)
                  _infoRow(Icons.router, 'Protocol', device.protocol!),
                if (device.address != null && device.address != '-')
                  _infoRow(Icons.place, 'Address', device.address!),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveTrackingScreen(device: device),
                        ),
                      );
                    },
                    icon: const Icon(Icons.my_location),
                    label: const Text('Live Tracking'),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistoryScreen(device: device),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text('History'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CommandsScreen(device: device),
                            ),
                          );
                        },
                        icon: const Icon(Icons.terminal),
                        label: const Text('Command'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
