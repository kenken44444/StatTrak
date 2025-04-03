// file: providers/SupabaseProvider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProvider with ChangeNotifier {
  late final SupabaseClient _client;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  SupabaseClient get client {
    if (!_initialized) {
      throw Exception('SupabaseProvider not initialized yet.');
    }
    return _client;
  }

  Future<void> init() async {
    const supabaseUrl = 'https://vxucbsuyrfgfemjbseoy.supabase.co';
    const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ4dWNic3V5cmZnZmVtamJzZW95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE1OTI1NzUsImV4cCI6MjA1NzE2ODU3NX0.IhGFySWQ7wDwCBoaJwrLwkzbGCoOuKR1HBpSbsd9mRY';

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _client = Supabase.instance.client;
    _initialized = true;
    notifyListeners();
  }

  /// 1) Sign up requires email confirmation. If user is not confirmed, return null.
  Future<User?> signUpUser({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    if (!isInitialized) {
      throw Exception('SupabaseProvider not initialized.');
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,

    );

    final user = response.user;
    final session = response.session;
    if (user == null || session == null) {
      return null; // Could be an unconfirmed user or error
    }

    // If user isn't confirmed, do not insert a profile row yet
    if (user.emailConfirmedAt == null) {
      return null;
    }

    // If user is confirmed, insert into `profiles` immediately
    try {
      await _client.from('profiles').insert({
        'id': user.id,
        'full_name': name,
        'phone': phone,
      });
      return user;
    } catch (error) {
      debugPrint('Error inserting profile: $error');
      return null;
    }
  }

  /// 2) Sign in. If user is confirmed, ensure they have a row in `profiles`.
  Future<User?> signInUser({
    required String email,
    required String password,
  }) async {
    if (!isInitialized) {
      throw Exception('SupabaseProvider not initialized.');
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;

      // If login fails or user is null, return null
      if (user == null) return null;

      // If user is not confirmed, you may want to block login or allow it
      // For example, you could do:
      // if (user.emailConfirmedAt == null) {
      //   // Show message "Please confirm your email before logging in."
      //   return null;
      // }

      // If user is confirmed, make sure there's a row in `profiles`
      if (user.emailConfirmedAt != null) {
        await _createProfileIfNotExists(user.id);
      }

      return user;
    } catch (error) {
      debugPrint('Sign in error: $error');
      return null;
    }
  }

  /// Helper: Create a `profiles` row only if it doesn't exist
  Future<void> _createProfileIfNotExists(String userId) async {
    try {
      final existing = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // If no row found, insert
      if (existing == null) {
        await _client.from('profiles').insert({
          'id': userId,
          'full_name': 'Unknown', // or any placeholder
        });
      }
    } catch (e) {
      debugPrint('Error checking/inserting profile: $e');
    }
  }
}
