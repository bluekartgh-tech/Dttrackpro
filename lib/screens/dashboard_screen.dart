import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';
import 'vehicle_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      if (p.devices.isEmpty) p.loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final today = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadDashboard(),
        color: AppColors.primary,
        child: provider.isLoading && provider.devices.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date chip
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(today, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      _statCard('Total Vehicles', '${provider.totalVehicles}', Icons.directions_car, AppColors.info),
                      const SizedBox(width: 10),
                      _statCard('Online', '${provider.onlineCount}', Icons.check_circle, AppColors.online),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard('Offline', '${provider.offlineCount}', Icons.cancel, AppColors.offline),
                      const SizedBox(width: 10),
                      _statCard('Alerts', '${provider.alertsCount}', Icons.warning_amber, AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Today's Overview
                  _sectionTitle("Today's Overview"),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _overviewItem(Icons.route, 'Total Distance', '${_calcTotalDistance(provider)} km'),
                            _overviewItem(Icons.speed, 'Avg. Speed', '${_calcAvgSpeed(provider)} km/h'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _overviewItem(Icons.timer, 'Engine Hours', '--'),
                            _overviewItem(Icons.local_gas_station, 'Fuel Consumed', '--'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick counts
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _miniCount(Icons.fence, 'Geofences', '${provider.geofences.length}'),
                      _miniCount(Icons.route, 'Trips', '--'),
                      _miniCount(Icons.terminal, 'Commands', '--'),
                      _miniCount(Icons.people, 'Drivers', '--'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent Vehicles
                  _sectionTitle('Vehicles'),
                  const SizedBox(height: 10),
                  ...provider.devices.take(6).map((d) => _vehicleTile(context, d, provider)),
                  if (provider.devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No vehicles found', style: TextStyle(color: AppColors.textSecondary))),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _miniCount(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
    );
  }

  Widget _vehicleTile(BuildContext context, dynamic d, AppProvider provider) {
    final statusColor = d.isMoving
        ? AppColors.online
        : d.isOnline
            ? AppColors.idle
            : AppColors.offline;

    return GestureDetector(
      onTap: () {
        provider.selectDevice(d);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VehicleDetailScreen(device: d)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.directions_car, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${d.speed.toStringAsFixed(0)} km/h • ${d.statusLabel}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
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
          ],
        ),
      ),
    );
  }

  String _calcTotalDistance(AppProvider p) {
    // Approximate from raw if available
    double total = 0;
    for (final d in p.devices) {
      final td = d.raw['total_distance'];
      if (td is num) total += td;
    }
    return total > 0 ? total.toStringAsFixed(1) : '--';
  }

  String _calcAvgSpeed(AppProvider p) {
    if (p.devices.isEmpty) return '--';
    final moving = p.devices.where((d) => d.speed > 0).toList();
    if (moving.isEmpty) return '0';
    final avg = moving.map((d) => d.speed).reduce((a, b) => a + b) / moving.length;
    return avg.toStringAsFixed(0);
  }
}
