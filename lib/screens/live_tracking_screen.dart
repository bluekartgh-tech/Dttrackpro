import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/device.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';
import 'history_screen.dart';
import 'commands_screen.dart';

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
  int _mapStyle = 0;

  static const _tileUrls = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  ];

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _displayPos = LatLng(
      _device.lat != 0 ? _device.lat : 30.7,
      _device.lng != 0 ? _device.lng : 76.7,
    );
    _displayCourse = _device.course;
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
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
      if (updated.lat == 0 && updated.lng == 0) {
        setState(() => _device = updated!);
        return;
      }

      final newPos = LatLng(updated.lat, updated.lng);
      final oldPos = _displayPos;
      final dist = const Distance().as(LengthUnit.Meter, oldPos, newPos);

      if (dist < 2 && !_firstFix) {
        setState(() => _device = updated!);
        return;
      }

      final ms = (800 + (dist * 2).clamp(0, 1200)).round();
      _moveController?.duration = Duration(milliseconds: ms);
      _moveController?.stop();
      _latAnim = Tween<double>(begin: oldPos.latitude, end: newPos.latitude)
          .animate(CurvedAnimation(parent: _moveController!, curve: Curves.easeInOutCubic));
      _lngAnim = Tween<double>(begin: oldPos.longitude, end: newPos.longitude)
          .animate(CurvedAnimation(parent: _moveController!, curve: Curves.easeInOutCubic));

      setState(() {
        _device = updated!;
        _displayCourse = updated.course;
        _firstFix = false;
      });
      _moveController?.forward(from: 0);
    } catch (_) {}
  }

  Future<void> _shareLocation() async {
    final text =
        '${_device.name}\nLat: ${_displayPos.latitude.toStringAsFixed(6)}\nLng: ${_displayPos.longitude.toStringAsFixed(6)}\nSpeed: \( {_device.speed.toStringAsFixed(0)} km/h\nhttps://maps.google.com/?q= \){_displayPos.latitude},${_displayPos.longitude}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location copied to clipboard')),
      );
    }
  }

  Future<void> _openInMaps() async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=\( {_displayPos.latitude}, \){_displayPos.longitude}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showMore() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.history, color: AppColors.primary),
              title: const Text('History / Playback'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(device: _device)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.terminal, color: AppColors.primary),
              title: const Text('Send Command'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => CommandsScreen(device: _device)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.map, color: AppColors.primary),
              title: const Text('Open in Google Maps'),
              onTap: () {
                Navigator.pop(ctx);
                _openInMaps();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppColors.primary),
              title: const Text('Share Location'),
              onTap: () {
                Navigator.pop(ctx);
                _shareLocation();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
          Positioned.fill(
            child: FlutterMap(
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
                  urlTemplate: _tileUrls[_mapStyle],
                  subdomains: _mapStyle == 2 ? const ['a', 'b', 'c'] : const [],
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
                                color: statusColor.withOpacity(0.45),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.navigation, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  _roundBtn(Icons.arrow_back, () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      elevation: 3,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _device.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _device.statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 70,
            child: Column(
              children: [
                _fab(Icons.layers, () {
                  setState(() => _mapStyle = (_mapStyle + 1) % _tileUrls.length);
                }),
                const SizedBox(height: 10),
                _fab(
                  Icons.my_location,
                  () {
                    setState(() => _follow = true);
                    _mapController.move(_displayPos, 16);
                  },
                  color: _follow ? AppColors.primary : Colors.white,
                  iconColor: _follow ? Colors.white : AppColors.primary,
                ),
                const SizedBox(height: 10),
                _fab(Icons.share_location, _shareLocation),
                const SizedBox(height: 10),
                _fab(Icons.map, _openInMaps),
                const SizedBox(height: 10),
                _fab(Icons.sos, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SOS – wire alert API if needed')),
                  );
                }, color: AppColors.danger, iconColor: Colors.white),
                const SizedBox(height: 10),
                _fab(Icons.more_horiz, _showMore),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.place, size: 15, color: AppColors.primary),
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
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 22)),
      ),
    );
  }

  Widget _fab(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white,
    Color iconColor = AppColors.primary,
  }) {
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: color,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: iconColor, size: 22),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
