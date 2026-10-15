import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/franchise_application.dart';
import '../application/application_list_screen.dart';
import 'application_documents_screen.dart';

/// The driver's documents across their applications — slice 5's entry point.
///
/// Reuses [ApplicationListScreen] as the application chooser, swapping its
/// destination: a row opens [ApplicationDocumentsScreen] (which can replace a
/// rejected or pending copy) instead of the read-only tracker.
class DocumentManagerScreen extends ConsumerWidget {
  const DocumentManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ApplicationListScreen(
      title: 'My documents',
      onOpenApplication: (context, FranchiseApplication application) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ApplicationDocumentsScreen(
              application: application,
            ),
          ),
        );
      },
    );
  }
}
