import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/device.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class HistoryScreen extends StatefulWidget {
  final Device device;

  const HistoryScreen({super.key, required this.device});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _date = DateTime.now();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    await provider.loadHistory(
      deviceId: widget.device.id,
      fromDate: dateStr,
      fromTime: '00:00:00',
      toDate: dateStr,
      toTime: '23:59:59',
    );
    setState(() => _loaded = true);
  }

  List<LatLng> _extractPoints(Map<String, dynamic>? data) {
    final points = <LatLng>[];
    if (data == null || data['items'] is! List) return points;
    for (final segment in data['items']) {
      if (segment is Map && segment['items'] is List) {
        for (final p in segment['items']) {
          if (p is Map) {
            final lat = p['lat'] ?? p['latitude'];
            final lng = p['lng'] ?? p['longitude'];
            if (lat != null && lng != null) {
              final la = double.tryParse(lat.toString());
              final ln = double.tryParse(lng.toString());
              if (la != null && ln != null && la != 0) {
                points.add(LatLng(la, ln));
              }
            }
          }
        }
      }
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final points = _extractPoints(provider.historyData);
    final center = points.isNotEmpty
        ? points.first
        : LatLng(widget.device.lat, widget.device.lng);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('History / Playback'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _date = picked;
                  _loaded = false;
                });
                await _load();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _date = _date.subtract(const Duration(days: 1));
                      _loaded = false;
                    });
                    _load();
                  },
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(_date),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _date.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                      ? () {
                          setState(() {
                            _date = _date.add(const Duration(days: 1));
                            _loaded = false;
                          });
                          _load();
                        }
                      : null,
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            flex: 3,
            child: provider.isLoading && !_loaded
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: points.length > 1 ? 12 : 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.dttrack.pro',
                      ),
                      if (points.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              color: AppColors.primary,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      if (points.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: points.first,
                              width: 28,
                              height: 28,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.online,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                              ),
                            ),
                            if (points.length > 1)
                              Marker(
                                point: points.last,
                                width: 28,
                                height: 28,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.stop, color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
          // Summary
          if (provider.historyData != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('Distance', '${provider.historyData!['distance_sum'] ?? '--'}'),
                  _stat('Top Speed', '${provider.historyData!['top_speed'] ?? '--'}'),
                  _stat('Moving', '${provider.historyData!['move_duration'] ?? '--'}'),
                  _stat('Stopped', '${provider.historyData!['stop_duration'] ?? '--'}'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
