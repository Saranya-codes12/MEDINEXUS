import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';

enum Portal { admin, facilityUser }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  Portal portal = Portal.admin;
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool submitting = false;

  Future<void> handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => submitting = true);
    final auth = context.read<AuthProvider>();
    final error = await auth.signIn(emailCtrl.text.trim(), passwordCtrl.text);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: AppColors.rose));
    }
    if (mounted) setState(() => submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 26),
                      ),
                      const SizedBox(height: 12),
                      Text('MediNexus', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      const Text('District Health Society Portal', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(child: _portalTab('DDHS Admin', Icons.shield_outlined, Portal.admin, AppColors.teal)),
                            Expanded(child: _portalTab('Facility', Icons.local_hospital_outlined, Portal.facilityUser, AppColors.vital)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _label('Email'),
                      TextField(
                        controller: emailCtrl, keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(hintText: portal == Portal.admin ? 'admin@ddhs.gov.in' : 'facility.staff@health.gov.in'),
                      ),
                      const SizedBox(height: 16),
                      _label('Password'),
                      TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(hintText: '••••••••')),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: submitting ? null : handleLogin,
                          icon: submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward, size: 18),
                          label: Text(submitting ? 'Signing in…' : 'Sign in'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Accounts are provisioned by the District Health Society administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.5)),
        ),
      );

  Widget _portalTab(String label, IconData icon, Portal p, Color activeColor) {
    final active = portal == p;
    return GestureDetector(
      onTap: () => setState(() => portal = p),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? activeColor : AppColors.muted),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? activeColor : AppColors.muted))),
          ],
        ),
      ),
    );
  }
}