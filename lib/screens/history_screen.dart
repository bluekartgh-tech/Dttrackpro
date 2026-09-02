import 'dart:async';
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
  List<LatLng> _points = [];
  List<Map<String, dynamic>> _rawPoints = [];
  int _playIndex = 0;
  bool _playing = false;
  double _speed = 1.0;
  Timer? _playTimer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
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
    final pts = <LatLng>[];
    final raw = <Map<String, dynamic>>[];
    final data = provider.historyData;
    if (data != null && data['items'] is List) {
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
                  pts.add(LatLng(la, ln));
                  raw.add(Map<String, dynamic>.from(p));
                }
              }
            }
          }
        }
      }
    }
    setState(() {
      _points = pts;
      _rawPoints = raw;
      _playIndex = 0;
      _loaded = true;
      _playing = false;
    });
    if (pts.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bounds = LatLngBounds.fromPoints(pts);
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)));
      });
    }
  }

  void _togglePlay() {
    if (_points.isEmpty) return;
    if (_playing) {
      _playTimer?.cancel();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      _scheduleNext();
    }
  }

  void _scheduleNext() {
    _playTimer?.cancel();
    final ms = (600 / _speed).round().clamp(80, 2000);
    _playTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || !_playing) return;
      if (_playIndex >= _points.length - 1) {
        setState(() {
          _playing = false;
          _playIndex = 0;
        });
        return;
      }
      setState(() => _playIndex++);
      _mapController.move(_points[_playIndex], _mapController.camera.zoom);
      _scheduleNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final center = _points.isNotEmpty
        ? _points[_playIndex.clamp(0, _points.length - 1)]
        : LatLng(widget.device.lat, widget.device.lng);
    final currentSpeed = _rawPoints.isNotEmpty && _playIndex < _rawPoints.length
        ? (_rawPoints[_playIndex]['speed']?.toString() ?? '--')
        : '--';
    final currentTime = _rawPoints.isNotEmpty && _playIndex < _rawPoints.length
        ? (_rawPoints[_playIndex]['time']?.toString() ?? '')
        : '';

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
                Text(DateFormat('dd MMM yyyy').format(_date),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
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
          Expanded(
            flex: 3,
            child: provider.isLoading && !_loaded
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: _points.length > 1 ? 13 : 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.dttrack.pro',
                      ),
                      if (_points.length > 1)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: _points, color: AppColors.primary.withOpacity(0.7), strokeWidth: 4),
                          ],
                        ),
                      if (_points.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _points.first,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: const BoxDecoration(color: AppColors.online, shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                              ),
                            ),
                            if (_points.length > 1)
                              Marker(
                                point: _points.last,
                                width: 24,
                                height: 24,
                                child: Container(
                                  decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                                  child: const Icon(Icons.stop, color: Colors.white, size: 12),
                                ),
                              ),
                            Marker(
                              point: _points[_playIndex.clamp(0, _points.length - 1)],
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8),
                                  ],
                                ),
                                child: const Icon(Icons.navigation, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                if (_points.isNotEmpty)
                  Slider(
                    value: _playIndex.toDouble().clamp(0, (_points.length - 1).toDouble()),
                    min: 0,
                    max: (_points.length - 1).clamp(1, 99999).toDouble(),
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      _playTimer?.cancel();
                      setState(() {
                        _playIndex = v.round();
                        _playing = false;
                      });
                      _mapController.move(_points[_playIndex], _mapController.camera.zoom);
                    },
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(_playing ? Icons.pause_circle : Icons.play_circle, size: 42, color: AppColors.primary),
                      onPressed: _togglePlay,
                    ),
                    const SizedBox(width: 8),
                    for (final s in [1.0, 2.0, 4.0])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${s.toInt()}x'),
                          selected: _speed == s,
                          onSelected: (_) {
                            setState(() => _speed = s);
                            if (_playing) {
                              _playTimer?.cancel();
                              _scheduleNext();
                            }
                          },
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _speed == s ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (currentTime.isNotEmpty || currentSpeed != '--')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$currentTime  •  $currentSpeed km/h  •  \( {_playIndex + 1}/ \){_points.length}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (provider.historyData != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
