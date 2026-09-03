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
  LatLng _displayPos = const LatLng(30.7, 76.7);
  double _displayCourse = 0;
  bool _follow = true;
  bool _firstFix = true;
  int _mapStyle = 0;

  static const _tiles = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  ];

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    if (_device.lat != 0) _displayPos = LatLng(_device.lat, _device.lng);
    _displayCourse = _device.course;
    _moveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _moveController!.addListener(() {
      if (_latAnim == null || _lngAnim == null) return;
      setState(() => _displayPos = LatLng(_latAnim!.value, _lngAnim!.value));
      if (_follow) _mapController.move(_displayPos, _mapController.camera.zoom);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final provider = context.read<AppProvider>();
      await provider.refreshDevices();
      Device? u;
      for (final d in provider.devices) {
        if (d.id == _device.id) { u = d; break; }
      }
      if (u == null || !mounted || (u.lat == 0 && u.lng == 0)) {
        if (u != null) setState(() => _device = u!);
        return;
      }
      final np = LatLng(u.lat, u.lng);
      final dist = const Distance().as(LengthUnit.Meter, _displayPos, np);
      if (dist < 2 && !_firstFix) {
        setState(() => _device = u!);
        return;
      }
      _moveController!.duration = Duration(milliseconds: (700 + dist * 2).clamp(700, 2000).round());
      _moveController!.stop();
      _latAnim = Tween(begin: _displayPos.latitude, end: np.latitude)
          .animate(CurvedAnimation(parent: _moveController!, curve: Curves.easeInOutCubic));
      _lngAnim = Tween(begin: _displayPos.longitude, end: np.longitude)
          .animate(CurvedAnimation(parent: _moveController!, curve: Curves.easeInOutCubic));
      setState(() {
        _device = u!;
        _displayCourse = u.course;
        _firstFix = false;
      });
      _moveController!.forward(from: 0);
    } catch (_) {}
  }

  Future<void> _share() async {
    final t = '\( {_device.name}\n \){_displayPos.latitude.toStringAsFixed(6)}, \( {_displayPos.longitude.toStringAsFixed(6)}\nhttps://maps.google.com/?q= \){_displayPos.latitude},${_displayPos.longitude}';
    await Clipboard.setData(ClipboardData(text: t));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location copied')));
  }

  Future<void> _maps() async {
    final u = Uri.parse('https://www.google.com/maps/search/?api=1&query=\( {_displayPos.latitude}, \){_displayPos.longitude}');
    if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _moveController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _device.isMoving ? AppColors.online : _device.isOnline ? AppColors.idle : AppColors.offline;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          // MAP takes all remaining space
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _displayPos,
                    initialZoom: 15,
                    onPositionChanged: (pos, g) {
                      if (g) setState(() => _follow = false);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _tiles[_mapStyle],
                      userAgentPackageName: 'com.dttrack.pro',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: _displayPos,
                        width: 48,
                        height: 48,
                        child: Transform.rotate(
                          angle: _displayCourse * math.pi / 180,
                          child: Container(
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 10)],
                            ),
                            child: const Icon(Icons.navigation, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
                // Top bar
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Row(
                      children: [
                        _circle(Icons.arrow_back, () => Navigator.pop(context)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Material(
                            color: Colors.white,
                            elevation: 2,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_device.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(_device.statusLabel, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right FABs
                Positioned(
                  right: 10,
                  top: MediaQuery.of(context).padding.top + 60,
                  child: Column(
                    children: [
                      _fab(Icons.layers, () => setState(() => _mapStyle = (_mapStyle + 1) % _tiles.length)),
                      const SizedBox(height: 8),
                      _fab(Icons.my_location, () {
                        setState(() => _follow = true);
                        _mapController.move(_displayPos, 15);
                      }, bg: _follow ? AppColors.primary : Colors.white, fg: _follow ? Colors.white : AppColors.primary),
                      const SizedBox(height: 8),
                      _fab(Icons.share_location, _share),
                      const SizedBox(height: 8),
                      _fab(Icons.map, _maps),
                      const SizedBox(height: 8),
                      _fab(Icons.history, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => HistoryScreen(device: _device)));
                      }),
                      const SizedBox(height: 8),
                      _fab(Icons.terminal, () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CommandsScreen(device: _device)));
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom info – fixed height, always visible
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPad),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(Icons.speed, '${_device.speed.toStringAsFixed(0)}', 'km/h'),
                    _stat(Icons.explore, '${_device.course.toStringAsFixed(0)}°', 'Course'),
                    _stat(Icons.battery_full, _device.battery ?? '--', 'Battery'),
                    _stat(Icons.power_settings_new, _device.ignition ?? '--', 'Ignition'),
                  ],
                ),
                if (_device.address != null && _device.address != '-') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(_device.address!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
                if (_device.time != null) ...[
                  const SizedBox(height: 4),
                  Text('Last update: ${_device.time}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(IconData i, VoidCallback onTap) => Material(
        color: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 40, height: 40, child: Icon(i, size: 20))),
      );

  Widget _fab(IconData i, VoidCallback onTap, {Color bg = Colors.white, Color fg = AppColors.primary}) => Material(
        color: bg,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 42, height: 42, child: Icon(i, color: fg, size: 20))),
      );

  Widget _stat(IconData i, String v, String l) => Column(
        children: [
          Icon(i, size: 18, color: AppColors.primary),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(l, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      );
}
