import 'package:supabase_flutter/supabase_flutter.dart';

import '../onboarding/onboarding_state.dart';

/// Mirrors the locally accepted User Agreement to the driver's profile.
///
/// Onboarding happens before sign-in, so acceptance is necessarily recorded on
/// the device first. Once a session exists, this service writes the same
/// version and timestamp to `public.user_agreements`, which gives the office a
/// server-side audit record that is tied to the correct profile.
///
/// The write is best effort. The table is created by
/// `20261112000300_user_agreements.sql`; if that migration has not been applied
/// yet, the failure is swallowed so onboarding and authentication never break.
class AgreementService {
  const AgreementService();

  Future<void> sync(OnboardingState state) async {
    final version = state.agreementVersion;
    if (version == null || version.isEmpty) return;

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final profile = await client
          .from('profiles')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();
      if (profile == null) return;

      final acceptedAt =
          (state.agreementAcceptedAt ?? DateTime.now().toUtc()).toUtc();
      final now = DateTime.now().toUtc();

      await client.from('user_agreements').upsert(
        <String, dynamic>{
          'profile_id': profile['id'],
          'agreement_version': version,
          'accepted_at': acceptedAt.toIso8601String(),
          'language_code': state.languageCode,
          'updated_at': now.toIso8601String(),
        },
        onConflict: 'profile_id',
      );
    } catch (_) {
      // Never block sign-in or onboarding on the audit mirror.
    }
  }
}
