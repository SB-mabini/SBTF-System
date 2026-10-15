import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_error.dart';
import '../env.dart';

/// Shared plumbing for the per-slice data services.
///
/// Two responsibilities, kept in one place so every service behaves the same:
///
///  1. **Preview-mode write blocking.** In `SBTF_DEMO_MODE` the app has no
///     database, so a write must fail loudly with [AppFailure.demoBlocked]
///     rather than reaching `Supabase.instance` and crashing.
///  2. **Error classification.** Every Supabase call is wrapped in [guard] so
///     screens receive an [AppFailure] (a presentable message plus a
///     `blocking` flag) instead of a raw `PostgrestException`.
///
/// Reads are not blocked in preview mode; the screens that own them simply are
/// never shown without a connection (see `AuthGate`). Only writes call
/// [ensureWritable].
abstract class SupabaseService {
  SupabaseService(this.client);

  final SupabaseClient client;

  /// Throws [AppFailure.demoBlocked] when preview mode is active.
  void ensureWritable() {
    if (currentEnv.isDemoMode) throw AppFailure.demoBlocked;
  }

  /// Runs [action], translating any thrown error through
  /// [classifyAppError] so callers always catch an [AppFailure].
  Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      throw classifyAppError(error);
    }
  }
}
