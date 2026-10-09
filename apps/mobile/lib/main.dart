import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialise the Supabase client when there is a real project to talk to
  // and we are not in preview/demo mode. Otherwise the app boots directly and
  // either shows the disabled sign-in (demo) or the config-missing screen.
  if (currentEnv.isConfigured && !currentEnv.isDemoMode) {
    await Supabase.initialize(
      url: currentEnv.supabaseUrl,
      anonKey: currentEnv.supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: SbtfApp()));
}
