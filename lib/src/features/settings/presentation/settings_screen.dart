import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subtrack/src/features/authentication/data/auth_repository.dart';
import 'package:subtrack/src/features/authentication/data/user_profile_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final authRepo = ref.read(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: userProfileAsync.when(
        data: (profile) {
          final nameController = TextEditingController(
            text: profile.displayName,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'User Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () {
                      ref
                          .read(userProfileRepositoryProvider)
                          .updateDisplayName(profile.uid, nameController.text);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Name updated')),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: profile.currency,
                decoration: const InputDecoration(
                  labelText: 'Default Currency',
                ),
                items: ['THB', 'USD', 'EUR', 'JPY', 'GBP']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(userProfileRepositoryProvider)
                        .updateCurrency(profile.uid, val);
                  }
                },
              ),
              const SizedBox(height: 48),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  authRepo.signOut();
                  Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  ); // Go back to root (which will show SignIn)
                },
              ),
            ],
          );
        },
        error: (err, stack) => Center(child: Text('Error: $err')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
