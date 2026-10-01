import 'package:flutter/material.dart';

import '../models/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Account'),
          _buildTile(
            icon: Icons.person_outline,
            title: 'Profile',
            subtitle: 'Edit your contact details',
            onTap: () {},
          ),
          _buildTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Manage alerts and reminders',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Privacy'),
          _buildTile(
            icon: Icons.lock_outline,
            title: 'Privacy & Safety',
            subtitle: 'Control who can reach you',
            onTap: () {},
          ),
          _buildTile(
            icon: Icons.visibility_off_outlined,
            title: 'Hidden items',
            subtitle: 'Manage your saved items',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Support'),
          _buildTile(
            icon: Icons.help_outline,
            title: 'Help Center',
            subtitle: 'Tips and troubleshooting',
            onTap: () {},
          ),
          _buildTile(
            icon: Icons.logout,
            title: 'Log out',
            subtitle: 'Securely sign out of smartFind',
            color: Colors.red,
            onTap: () {
              AppState.signOut();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = const Color(0xFF5A55CA),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}
