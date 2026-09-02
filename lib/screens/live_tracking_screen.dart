import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Device device;
  const LiveTrackingScreen({super.key, required this.device});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late Device _device;
  Timer? _pollTimer;
  AnimationController? _moveController;
  Animation<double>? _latAnim;
  Animation<double>? _lngAnim;
  LatLng _displayPos = const LatLng(0, 0);
  double _displayCourse = 0;
  bool _follow = true;
  bool _firstFix = true;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _displayPos = LatLng(_device.lat, _device.lng);
    _displayCourse = _device.course;
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
        if (_latAnim != null && _lngAnim != null) {
          setState(() {
            _displayPos = LatLng(_latAnim!.value, _lngAnim!.value);
          });
          if (_follow) {
            _mapController.move(_displayPos, _mapController.camera.zoom);
          }
        }
      });
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final provider = context.read<AppProvider>();
      await provider.refreshDevices();
      Device? updated;
      for (final d in provider.devices) {
        if (d.id == _device.id) {
          updated = d;
          break;
        }
      }
      if (updated == null || !mounted) return;

      final newPos = LatLng(updated.lat, updated.lng);
      final oldPos = _displayPos;
      final dist = const Distance().as(LengthUnit.Meter, oldPos, newPos);
      if (dist < 3 && !_firstFix) {
        setState(() => _device = updated!);
        return;
      }

      _moveController?.stop();
      _latAnim = Tween<double>(begin: oldPos.latitude, end: newPos.latitude)
          .animate(CurvedAnimation(parent: _moveController!, curve: Curves.easeInOut));
      _lngAnim = Tween<double>(begin: oldPos.longitude, end: newPos.longitude)
          .animate(CurvedAnimation(parent: _moveController!, curve: Curves.easeInOut));

      setState(() {
        _device = updated!;
        _displayCourse = updated.course;
        _firstFix = false;
      });
      _moveController?.forward(from: 0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _moveController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _device.isMoving
        ? AppColors.online
        : _device.isOnline
            ? AppColors.idle
            : AppColors.offline;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _displayPos,
              initialZoom: 16,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _follow = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dttrack.pro',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _displayPos,
                    width: 48,
                    height: 48,
                    child: Transform.rotate(
                      angle: (_displayCourse * math.pi / 180),
                      child: Container(
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.navigation, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_device.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          Text(
                            _device.statusLabel,
                            style: TextStyle(
                                fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: _follow ? AppColors.primary : Colors.white,
                    child: IconButton(
                      icon: Icon(Icons.my_location,
                          color: _follow ? Colors.white : AppColors.primary),
                      onPressed: () {
                        setState(() => _follow = true);
                        _mapController.move(_displayPos, 16);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 28,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _info(Icons.speed, '${_device.speed.toStringAsFixed(0)}', 'km/h'),
                      _info(Icons.explore, '${_device.course.toStringAsFixed(0)}°', 'Course'),
                      _info(Icons.battery_full, _device.battery ?? '--', 'Battery'),
                      _info(Icons.power_settings_new, _device.ignition ?? '--', 'Ignition'),
                    ],
                  ),
                  if (_device.address != null && _device.address != '-') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _device.address!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_device.time != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Last update: ${_device.time}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
