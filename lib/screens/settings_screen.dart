import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.dark_mode_outlined, color: AppColors.teal),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Dark mode', style: Theme.of(context).textTheme.titleMedium)),
                  Switch(value: themeProvider.mode == ThemeMode.dark, onChanged: (_) => context.read<ThemeProvider>().toggle(), activeThumbColor: AppColors.teal),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_outlined, color: AppColors.teal),
                  SizedBox(width: 12),
                  Expanded(child: Text('Password changes are managed through Supabase Auth. Use "Forgot password" on the sign-in screen.', style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}