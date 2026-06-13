import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton accessor — call after Supabase.initialize() in main.dart
SupabaseClient get supabase => Supabase.instance.client;
