import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';
import 'geofences_screen.dart';
import 'commands_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final email = provider.userData?['email']?.toString() ?? 'User';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DTTrack Pro',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'GPS Tracking Solution',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _item(context, Icons.dashboard, 'Dashboard', null),
                  _item(context, Icons.map, 'Live Map', null),
                  _item(context, Icons.my_location, 'Live Tracking', null),
                  _item(context, Icons.directions_car, 'Vehicles', null),
                  _item(context, Icons.history, 'History / Playback', null),
                  _item(context, Icons.fence, 'Geofences', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GeofencesScreen()));
                  }),
                  _item(context, Icons.notifications, 'Alerts', null),
                  _item(context, Icons.terminal, 'Commands', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CommandsScreen()));
                  }),
                  _item(context, Icons.assessment, 'Reports', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                  }),
                  _item(context, Icons.people, 'Users', null),
                  _item(context, Icons.settings, 'Settings', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  }),
                  const Divider(height: 24),
                  _item(context, Icons.logout, 'Logout', () async {
                    await provider.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
                    }
                  }, color: AppColors.danger),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, VoidCallback? onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: color ?? AppColors.textPrimary,
        ),
      ),
      trailing: color == null ? const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary) : null,
      onTap: onTap ?? () {},
    );
  }
}
