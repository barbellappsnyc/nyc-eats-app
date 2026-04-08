import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class TelemetryService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Fire and forget. Logs user interactions for the V2 Algorithm.
  static Future<void> logInteraction({
    required String actionType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _client.auth.currentUser;
      // We only want to train the algorithm on authenticated users to ensure data quality
      if (user == null) return;

      await _client.from('interaction_logs').insert({
        'user_id': user.id,
        'action_type': actionType,
        'metadata': metadata ?? {},
      });
      debugPrint('📡 Telemetry Logged: $actionType');
    } catch (e) {
      // We catch and swallow errors here.
      // Telemetry should NEVER crash the app or interrupt the user.
      debugPrint('📡 Telemetry Error: $e');
    }
  }
}
