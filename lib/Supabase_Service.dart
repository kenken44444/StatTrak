import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final SupabaseClient client;

  /// Initialize Supabase using values from the .env file.
  Future<void> init() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    client = Supabase.instance.client;
  }

  /// Signs up a user and creates a profile in the 'user_profiles' table.
  Future<User?> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await client.auth.signUp(email: email, password: password);
    if (response.user == null) {
      return null;
    }
    final user = response.user!;

    final insertResponse = await client.from('profiles').insert({
      'user_id': user.id,
      'name': name,
    });

    if (insertResponse.error != null) {
      return null;
    }
    return user;
  }
}
