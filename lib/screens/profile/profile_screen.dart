import 'package:expense_tracker/providers/theme_provider.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                user?.email?[0].toUpperCase() ?? 'U',
                style: TextStyle(fontSize: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Text(user?.email ?? 'No Email', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.brightness_6),
                      title: const Text('Theme Mode'),
                      trailing: DropdownButton<ThemeMode>(
                        value: themeMode,
                        onChanged: (ThemeMode? newMode) {
                          if (newMode != null) {
                            ref.read(themeProvider.notifier).state = newMode;
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text('Logout', style: TextStyle(color: Colors.red)),
                      onTap: () => ref.read(authServiceProvider).signOut(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
