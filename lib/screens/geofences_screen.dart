import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class GeofencesScreen extends StatefulWidget {
  const GeofencesScreen({super.key});

  @override
  State<GeofencesScreen> createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends State<GeofencesScreen> {
  List<Map<String, dynamic>> _geofences = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AppProvider>().api;
      final res = await api.getGeofences();
      final items = res['items'];
      if (items is Map && items['geofences'] is List) {
        _geofences = List<Map<String, dynamic>>.from(items['geofences']);
      } else if (items is List) {
        _geofences = List<Map<String, dynamic>>.from(items);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Geofences'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () {}),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
              : _geofences.isEmpty
                  ? const Center(child: Text('No geofences found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _geofences.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final g = _geofences[i];
                          final name = g['name']?.toString() ?? 'Unnamed';
                          final type = g['type']?.toString() ?? 'circle';
                          final active = g['active'] == 1 || g['active'] == true;
                          final radius = g['radius'];
                          final center = g['center'];
                          String subtitle = type.toUpperCase();
                          if (radius != null) {
                            final r = (radius is num) ? radius.toDouble() : double.tryParse(radius.toString()) ?? 0;
                            subtitle += ' · Radius: ${r.toStringAsFixed(0)} m';
                          }
                          if (center is Map) {
                            subtitle += '\n${center['lat']}, ${center['lng']}';
                          }
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: active
                                    ? AppColors.primary.withOpacity(0.15)
                                    : Colors.grey.shade200,
                                child: Icon(
                                  Icons.fence,
                                  color: active ? AppColors.primary : Colors.grey,
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                              trailing: Switch(
                                value: active,
                                activeColor: AppColors.primary,
                                onChanged: (_) {},
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
