import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      {'icon': Icons.route, 'title': 'Trips Report', 'desc': 'View trip history and details'},
      {'icon': Icons.summarize, 'title': 'Summary Report', 'desc': 'View daily summary'},
      {'icon': Icons.stop_circle, 'title': 'Stopped Report', 'desc': 'View stopped vehicle report'},
      {'icon': Icons.speed, 'title': 'Overspeed Report', 'desc': 'View overspeed events'},
      {'icon': Icons.fence, 'title': 'Geofence Report', 'desc': 'View geofence in/out report'},
      {'icon': Icons.straighten, 'title': 'Mileage Report', 'desc': 'View mileage and distance'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...reports.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    child: Icon(r['icon'] as IconData, color: AppColors.primary),
                  ),
                  title: Text(r['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(r['desc'] as String, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${r['title']} – connect report generation endpoint')),
                    );
                  },
                ),
              )),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Select a report type above')),
              );
            },
            icon: const Icon(Icons.file_download),
            label: const Text('Generate Report'),
          ),
        ],
      ),
    );
  }
}
