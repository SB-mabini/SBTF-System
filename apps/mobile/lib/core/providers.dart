import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/profile.dart';

/// The shared Supabase client.
///
/// Reads only when the app actually connected to a project (see `main.dart`).
/// In preview/demo mode this provider is never watched, because nothing is
/// allowed to touch a database there.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Emits every auth transition (sign-in, sign-out, token refresh, initial
/// session restore). The [AuthGate] maps these to screens.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});

/// The signed-in driver's own `profiles` row, fetched through RLS with the
/// caller's own token. Returns null when there is no session yet.
///
/// The profile is what decides whether the session may proceed: roles and
/// account status live here, and Row Level Security only ever returns the
/// caller's own row, so this read cannot leak another account.
///
/// It watches [authStateChangesProvider] so it re-fetches whenever the session
/// changes (sign-in, sign-out, restore), rather than returning a stale null.
final profileProvider = FutureProvider<Profile?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.valueOrNull?.session?.user ?? client.auth.currentUser;
  if (user == null) return null;

  final row = await client
      .from('profiles')
      .select()
      .eq('auth_user_id', user.id)
      .maybeSingle();

  if (row == null) return null;
  return Profile.fromMap(row);
});
