import 'package:flutter/material.dart';
import '../api.dart';
import '../models.dart';

class ProfileScreen extends StatelessWidget {
  final SessionUser user;
  final ApiClient api;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.api,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // User info card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Account section
        const Text(
          'حسابي',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        // Roles card
        Card(
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings),
            title: const Text('الأدوار'),
            subtitle: Text(
              user.roles.isEmpty ? 'بدون أدوار' : user.roles.join('، '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Permissions card
        Card(
          child: ExpansionTile(
            leading: const Icon(Icons.security),
            title: const Text('الصلاحيات'),
            subtitle: Text(
              '${user.permissions.length} صلاحيات',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      user.permissions
                          .map(
                            (p) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // Logout
        FilledButton.tonalIcon(
          onPressed: () => _showLogoutDialog(context),
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج'),
        ),
      ],
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await api.logout();
      onLogout();
    }
  }
}
