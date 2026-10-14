import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/app_user.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? profile;
  bool loading = true;

  void init() {
    SupabaseService.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user != null) {
        final map = await SupabaseService.fetchProfile(user.id);
        profile = map != null ? AppUser.fromMap(map) : null;
      } else {
        profile = null;
      }
      loading = false;
      notifyListeners();
    });
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await SupabaseService.signIn(email, password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<void> signOut() => SupabaseService.signOut();

  bool get isAdmin => profile?.role == UserRole.admin;
}
