import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                children: [
                  CircleAvatar(radius: 32, backgroundColor: AppColors.tealLight, child: Text(profile?.fullName.isNotEmpty == true ? profile!.fullName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.teal))),
                  const SizedBox(height: 12),
                  Text(profile?.fullName ?? '', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(auth.isAdmin ? 'DDHS Administrator' : 'Facility Staff', style: const TextStyle(fontSize: 12.5, color: AppColors.vital, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.email_outlined, size: 16, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Flexible(child: Text(profile?.email ?? '', style: const TextStyle(fontSize: 13, color: AppColors.muted), overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.read<AuthProvider>().signOut(),
                icon: const Icon(Icons.logout, size: 18, color: AppColors.rose),
                label: const Text('Log out', style: TextStyle(color: AppColors.rose)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: AppColors.rose)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}