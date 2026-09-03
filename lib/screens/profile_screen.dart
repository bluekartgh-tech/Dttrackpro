import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showInfo(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
            TextField(controller: confCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (newCtrl.text != confCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password change – connect /api/edit_user endpoint if available')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    bool push = true, sound = true, email = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Notification Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(title: const Text('Push notifications'), value: push, onChanged: (v) => setLocal(() => push = v)),
              SwitchListTile(title: const Text('Sound'), value: sound, onChanged: (v) => setLocal(() => sound = v)),
              SwitchListTile(title: const Text('Email alerts'), value: email, onChanged: (v) => setLocal(() => email = v)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  void _showAppSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('App Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Distance unit: km'),
            Text('• Speed unit: km/h'),
            Text('• Map: OpenStreetMap'),
            Text('• Auto-refresh: 6–10 sec'),
            SizedBox(height: 8),
            Text('More options can be wired to /api/edit_setup_data'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.userData ?? {};
    final email = user['email']?.toString() ?? '—';
    final plan = user['plan']?.toString() ?? '—';
    final daysLeft = user['days_left']?.toString() ?? '—';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile / Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: const Icon(Icons.person, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(email, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Plan: $plan · $daysLeft days left',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _tile(Icons.person_outline, 'Profile Information', () {
            _showInfo(context, 'Profile Information',
                'Email: $email\nPlan: $plan\nDays left: $daysLeft\n\nUser data from /api/get_user_data');
          }),
          _tile(Icons.lock_outline, 'Change Password', () => _showChangePassword(context)),
          _tile(Icons.notifications_outlined, 'Notification Settings', () => _showNotifications(context)),
          _tile(Icons.settings_outlined, 'App Settings', () => _showAppSettings(context)),
          _tile(Icons.help_outline, 'Help & Support', () async {
            final url = Uri.parse('https://app.dttrack.com');
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            } else {
              _showInfo(context, 'Help & Support', 'Visit app.dttrack.com or contact your admin.');
            }
          }),
          _tile(Icons.info_outline, 'About DTTrack Pro', () {
            _showInfo(context, 'About DTTrack Pro',
                'DTTrack Pro\nGPS Tracking Solution\n\nBackend: app.dttrack.com\nAPI: GPSWOX-compatible\nVersion: 1.0.0');
          }),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size(double.infinity, 48),
            ),
            onPressed: () async {
              await provider.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
