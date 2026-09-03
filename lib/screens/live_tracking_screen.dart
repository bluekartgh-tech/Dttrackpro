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

  // Displayed (smoothed) position
  LatLng _displayPos = const LatLng(30.7, 76.7);
  double _displayCourse = 0;

  // Last real GPS fix from server
  LatLng _lastGps = const LatLng(30.7, 76.7);
  DateTime _lastGpsTime = DateTime.now();
  double _lastSpeedKmh = 0;
  double _lastCourse = 0;

  bool _follow = true;
  bool _firstFix = true;
  int _mapStyle = 0;

  Timer? _pollTimer;
  Timer? _tickTimer; // \~15 fps for smooth movement
  AnimationController? _courseController;
  Animation<double>? _courseAnim;

  static const _tiles = [
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  ];

  static const _earthRadius = 6371000.0; // meters

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    if (_device.lat != 0) {
      _displayPos = LatLng(_device.lat, _device.lng);
      _lastGps = _displayPos;
    }
    _displayCourse = _device.course;
    _lastCourse = _device.course;
    _lastSpeedKmh = _device.speed;

    _courseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // High-frequency tick for smooth motion between GPS updates
    _tickTimer = Timer.periodic(const Duration(milliseconds: 66), (_) => _onTick());

    // Poll server – faster when moving
    _schedulePoll();
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    final interval = _device.isMoving ? 4 : 8;
    _pollTimer = Timer.periodic(Duration(seconds: interval), (_) => _refresh());
    // immediate first refresh after short delay
    Future.delayed(const Duration(milliseconds: 800), _refresh);
  }

  /// Move point by distanceMeters along bearing degrees
  LatLng _offset(LatLng from, double bearingDeg, double distanceMeters) {
    if (distanceMeters < 0.1) return from;
    final lat1 = from.latitude * math.pi / 180;
    final lon1 = from.longitude * math.pi / 180;
    final brng = bearingDeg * math.pi / 180;
    final dr = distanceMeters / _earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(dr) + math.cos(lat1) * math.sin(dr) * math.cos(brng),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(brng) * math.sin(dr) * math.cos(lat1),
          math.cos(dr) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  void _onTick() {
    if (!mounted) return;

    // Dead-reckon only while vehicle is moving and we have a recent fix
    final moving = _lastSpeedKmh > 1.5;
    if (!moving) return;

    final elapsed = DateTime.now().difference(_lastGpsTime).inMilliseconds / 1000.0;
    // Don't project more than \~12 seconds ahead of last GPS
    if (elapsed > 12) return;

    final speedMs = _lastSpeedKmh / 3.6;
    final projected = _offset(_lastGps, _lastCourse, speedMs * elapsed);

    // Soft blend toward projected position (avoid overshoot)
    final blend = 0.35;
    final newLat = _displayPos.latitude + (projected.latitude - _displayPos.latitude) * blend;
    final newLng = _displayPos.longitude + (projected.longitude - _displayPos.longitude) * blend;
    final next = LatLng(newLat, newLng);

    setState(() => _displayPos = next);

    if (_follow) {
      // Smooth camera: only small moves each tick
      try {
        final cam = _mapController.camera;
        final targetZoom = cam.zoom < 14 ? 15.0 : cam.zoom;
        _mapController.move(next, targetZoom);
      } catch (_) {}
    }
  }

  Future<void> _refresh() async {
    try {
      final provider = context.read<AppProvider>();
      await provider.refreshDevices();
      Device? u;
      for (final d in provider.devices) {
        if (d.id == _device.id) {
          u = d;
          break;
        }
      }
      if (u == null || !mounted) return;
      if (u.lat == 0 && u.lng == 0) {
        setState(() => _device = u!);
        return;
      }

      final newGps = LatLng(u.lat, u.lng);
      final dist = const Distance().as(LengthUnit.Meter, _lastGps, newGps);

      // Ignore tiny GPS noise when almost stopped
      if (dist < 2.5 && u.speed < 2 && !_firstFix) {
        setState(() {
          _device = u!;
          _lastSpeedKmh = u.speed;
        });
        return;
      }

      // Smooth course turn
      final newCourse = u.course;
      _courseController?.stop();
      _courseAnim = Tween<double>(begin: _displayCourse, end: newCourse).animate(
        CurvedAnimation(parent: _courseController!, curve: Curves.easeInOut),
      );
      _courseController?.forward(from: 0).then((_) {
        if (mounted) setState(() => _displayCourse = newCourse);
      });
      _courseController?.addListener(() {
        if (_courseAnim != null && mounted) {
          setState(() => _displayCourse = _courseAnim!.value);
        }
      });

      setState(() {
        _device = u!;
        _lastGps = newGps;
        _lastGpsTime = DateTime.now();
        _lastSpeedKmh = u.speed;
        _lastCourse = newCourse;
        _firstFix = false;
        // Gently pull display toward real GPS (correction)
        final pull = dist > 80 ? 0.55 : 0.25;
        _displayPos = LatLng(
          _displayPos.latitude + (newGps.latitude - _displayPos.latitude) * pull,
          _displayPos.longitude + (newGps.longitude - _displayPos.longitude) * pull,
        );
      });

      // Reschedule poll rate if moving state changed
      _schedulePoll();
    } catch (_) {}
  }

  Future<void> _share() async {
    final t =
        '\( {_device.name}\n \){_displayPos.latitude.toStringAsFixed(6)}, \( {_displayPos.longitude.toStringAsFixed(6)}\n \){_device.speed.toStringAsFixed(0)} km/h\nhttps://maps.google.com/?q=\( {_displayPos.latitude}, \){_displayPos.longitude}';
    await Clipboard.setData(ClipboardData(text: t));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location copied')));
    }
  }

  Future<void> _maps() async {
    final u = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=\( {_displayPos.latitude}, \){_displayPos.longitude}');
    if (await canLaunchUrl(u)) {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _courseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _device.isMoving
        ? AppColors.online
        : _device.isOnline
            ? AppColors.idle
            : AppColors.offline;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _displayPos,
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & \~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture) setState(() => _follow = false);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _tiles[_mapStyle],
                      userAgentPackageName: 'com.dttrack.pro',
                      // Keep tiles warm for smoother panning
                      maxNativeZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _displayPos,
                          width: 52,
                          height: 52,
                          child: Transform.rotate(
                            angle: _displayCourse * math.pi / 180,
                            child: Container(
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.withOpacity(0.45),
                                    blurRadius: 12,
                                    spreadRadius: 1,
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
                                  Text(
                                    _device.name,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _device.statusLabel,
                                    style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600),
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
                  right: 10,
                  top: MediaQuery.of(context).padding.top + 60,
                  child: Column(
                    children: [
                      _fab(Icons.layers, () => setState(() => _mapStyle = (_mapStyle + 1) % _tiles.length)),
                      const SizedBox(height: 8),
                      _fab(
                        Icons.my_location,
                        () {
                          setState(() => _follow = true);
                          _mapController.move(_displayPos, 16);
                        },
                        bg: _follow ? AppColors.primary : Colors.white,
                        fg: _follow ? Colors.white : AppColors.primary,
                      ),
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
                  const SizedBox(height: 4),
                  Text(
                    'Last update: ${_device.time}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
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
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(i, size: 20)),
        ),
      );

  Widget _fab(IconData i, VoidCallback onTap, {Color bg = Colors.white, Color fg = AppColors.primary}) =>
      Material(
        color: bg,
        elevation: 2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(i, color: fg, size: 20)),
        ),
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
