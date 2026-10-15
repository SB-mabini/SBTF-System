import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/app_error.dart';
import 'package:sbtf_mobile/core/models/franchise_application.dart';
import 'package:sbtf_mobile/core/providers.dart';
import 'package:sbtf_mobile/features/application/application_detail_screen.dart';
import 'package:sbtf_mobile/features/application/application_list_screen.dart';

/// Builds an application from a minimal map; `fromMap` fills every unspecified
/// column with the same safe defaults the data layer uses, so a test only has
/// to name the fields it asserts on.
FranchiseApplication application({
  required String id,
  required String number,
  String status = ApplicationStatus.pending,
  String? submittedAt,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) {
  return FranchiseApplication.fromMap({
    'id': id,
    'application_number': number,
    'status': status,
    if (submittedAt != null) 'submitted_at': submittedAt,
    ...extra,
  });
}

Widget harness({
  required Stream<List<FranchiseApplication>> stream,
  FranchiseApplication? detail,
}) {
  return ProviderScope(
    overrides: [
      myApplicationsStreamProvider.overrideWith((ref) => stream),
      if (detail != null)
        applicationDetailProvider.overrideWith((ref, id) => detail),
    ],
    child: const MaterialApp(home: ApplicationListScreen()),
  );
}

void main() {
  testWidgets('lists each application with its status chip', (tester) async {
    await tester.pumpWidget(
      harness(
        stream: Stream.value([
          application(id: 'app-1', number: 'SBTF-2026-0001'),
          application(
            id: 'app-2',
            number: 'SBTF-2026-0002',
            status: ApplicationStatus.approved,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SBTF-2026-0001'), findsOneWidget);
    expect(find.text('SBTF-2026-0002'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('shows the newest submission first', (tester) async {
    await tester.pumpWidget(
      harness(
        stream: Stream.value([
          application(
            id: 'app-old',
            number: 'SBTF-2026-0001',
            submittedAt: '2026-09-01T00:00:00Z',
          ),
          application(
            id: 'app-new',
            number: 'SBTF-2026-0002',
            submittedAt: '2026-10-01T00:00:00Z',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final newest = tester.getTopLeft(find.text('SBTF-2026-0002')).dy;
    final oldest = tester.getTopLeft(find.text('SBTF-2026-0001')).dy;
    expect(newest, lessThan(oldest));
  });

  testWidgets('prompts to start one when there is nothing yet', (tester) async {
    await tester.pumpWidget(
      harness(stream: Stream.value(const <FranchiseApplication>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('No applications yet'), findsOneWidget);
    expect(find.text('Start a new application'), findsOneWidget);
  });

  testWidgets('surfaces a classified failure with a retry', (tester) async {
    await tester.pumpWidget(
      harness(
        stream: Stream<List<FranchiseApplication>>.error(
          const AppFailure(
            kind: AppFailureKind.unreachable,
            message: 'Could not reach the municipal service. '
                'Check your connection and try again.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not reach'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('opens the tracker with the reason, documents and history',
      (tester) async {
    final summary = application(
      id: 'app-1',
      number: 'SBTF-2026-0001',
      status: ApplicationStatus.rejected,
      submittedAt: '2026-09-01T00:00:00Z',
    );

    final detail = application(
      id: 'app-1',
      number: 'SBTF-2026-0001',
      status: ApplicationStatus.rejected,
      submittedAt: '2026-09-01T00:00:00Z',
      extra: {
        'rejection_reason': 'The plate number does not match the OR/CR.',
        'documents': [
          {
            'id': 'doc-1',
            'application_id': 'app-1',
            'document_type': 'or_cr',
            'verification_status': 'rejected',
            'remarks': 'Blurred copy.',
            'storage_path': 'profile-1/1.pdf',
            'file_name': 'or.pdf',
          },
        ],
        'timeline': [
          {
            'id': 'event-1',
            'application_id': 'app-1',
            'event': 'created',
            'created_at': '2026-09-01T00:00:00Z',
          },
          {
            'id': 'event-2',
            'application_id': 'app-1',
            'event': 'rejected',
            'note': 'Plate mismatch',
            'created_at': '2026-09-05T00:00:00Z',
          },
        ],
      },
    );

    await tester.pumpWidget(
      harness(stream: Stream.value([summary]), detail: detail),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('SBTF-2026-0001'));
    await tester.pumpAndSettle();

    final trackerScrollable = find.descendant(
      of: find.byType(ApplicationDetailScreen),
      matching: find.byType(Scrollable),
    );

    // The header and rejection banner fit without scrolling.
    expect(find.text('This application was rejected'), findsOneWidget);
    expect(
      find.text('The plate number does not match the OR/CR.'),
      findsOneWidget,
    );

    // Documents and history sit further down the tracker.
    await tester.scrollUntilVisible(
      find.text('OR / CR'),
      300,
      scrollable: trackerScrollable,
    );
    expect(find.text('OR / CR'), findsOneWidget);
    expect(find.text('Blurred copy.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Application rejected'),
      300,
      scrollable: trackerScrollable,
    );
    expect(find.text('Application rejected'), findsOneWidget);
  });
}
