import 'package:flutter/material.dart';

import '../branding.dart';

/// One page of the system introduction.
///
/// Every claim below is backed by a screen or service that exists in this
/// build: the request-first application wizard, the status tracker, the
/// document manager, certificates/QR verification, notifications, announcements
/// and appointments. Nothing aspirational is listed.
class OnboardingSlide {
  const OnboardingSlide({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.summary,
    required this.points,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String summary;
  final List<String> points;
}

const List<OnboardingSlide> onboardingSlides = <OnboardingSlide>[
  OnboardingSlide(
    icon: Icons.assignment_outlined,
    eyebrow: 'Franchise applications',
    title: 'File a new or renewal application',
    summary:
        'Start from your phone and complete the same process the office uses.',
    points: <String>[
      'Request an application form, then complete it once the office issues it.',
      'Enter operator, vehicle, TODA and barangay details in a guided wizard.',
      'Upload the four required documents directly from your device.',
    ],
  ),
  OnboardingSlide(
    icon: Icons.track_changes_outlined,
    eyebrow: 'Status tracking',
    title: 'Follow every step of your case',
    summary:
        'See where your application is and what the office needs from you.',
    points: <String>[
      'Live application status and staff remarks on each document.',
      'A timeline of submissions, reviews and decisions.',
      'Appointments and hearings booked by the franchising office.',
    ],
  ),
  OnboardingSlide(
    icon: Icons.verified_outlined,
    eyebrow: 'Documents & certificates',
    title: 'Keep your records within reach',
    summary:
        'Manage requirements and present your franchise certificate anytime.',
    points: <String>[
      'Replace a rejected document while the application is under review.',
      'Open your franchise certificate and its QR code.',
      'Scan a certificate QR to verify it against the official record.',
    ],
  ),
  OnboardingSlide(
    icon: Icons.campaign_outlined,
    eyebrow: 'Updates',
    title: 'Stay informed by the office',
    summary:
        'Notices and decisions arrive in the app, so you do not miss a step.',
    points: <String>[
      'Announcements published by the Sangguniang Bayan office.',
      'A notification feed with an unread count.',
      'Updates appear in real time while the app is open.',
    ],
  ),
];

/// A section of the User Agreement.
class AgreementSection {
  const AgreementSection({
    required this.icon,
    required this.title,
    required this.summary,
    required this.paragraphs,
  });

  final IconData icon;
  final String title;

  /// One-sentence version shown on the review screen.
  final String summary;

  /// Complete wording shown on the full agreement screen.
  final List<String> paragraphs;
}

const List<AgreementSection> agreementSections = <AgreementSection>[
  AgreementSection(
    icon: Icons.key_outlined,
    title: 'Authorized access',
    summary: 'Use only your own account and only for legitimate franchise and '
        'driver registration transactions.',
    paragraphs: <String>[
      'Access to the SBTF System is limited to drivers, operators and '
          'authorized Sangguniang Bayan personnel who need it for franchising '
          'and tricycle driver registration.',
      'Your account credentials are personal. Do not share your password, '
          'one-time code or signed-in device with another person, and do not '
          'use an account that does not belong to you.',
      'Report any unauthorized access, lost device or suspicious activity to '
          'the Sangguniang Bayan office immediately so the account can be '
          'secured.',
    ],
  ),
  AgreementSection(
    icon: Icons.fact_check_outlined,
    title: 'Accurate information',
    summary:
        'You are responsible for the truth, completeness and legality of every '
        'detail and document you submit.',
    paragraphs: <String>[
      'All information you enter — names, contact details, vehicle and plate '
          'numbers, TODA and barangay information — must be true, current and '
          'complete.',
      'Documents you upload must be authentic, readable and lawfully obtained. '
          'Uploading a falsified, altered or borrowed document is prohibited.',
      'Submitting false information may result in rejection of the '
          'application, suspension or deactivation of your account, and may '
          'expose you to liability under applicable laws and municipal '
          'ordinances.',
    ],
  ),
  AgreementSection(
    icon: Icons.gavel_outlined,
    title: 'Proper use of the system',
    summary:
        'Use the features as intended and do not interfere with the service or '
        'other users.',
    paragraphs: <String>[
      'Use the application, document, certificate, announcement and '
          'notification features only for their intended purpose.',
      'Do not attempt to bypass security controls, access another person’s '
          'records, disrupt the service, or use automated tools to scrape or '
          'overload the system.',
      'The system supports the franchising process; it does not guarantee '
          'approval of an application. Decisions remain with the authorized '
          'office and are made under existing rules and ordinances.',
    ],
  ),
  AgreementSection(
    icon: Icons.shield_outlined,
    title: 'Confidentiality and data privacy',
    summary:
        'Personal data is processed under ${AppBranding.privacyLaw} and only '
        'for official franchising purposes.',
    paragraphs: <String>[
      'The system collects and processes personal information and sensitive '
          'personal information — including identity details, contact '
          'information and documentary requirements — for franchise and driver '
          'registration, verification, notifications and related official '
          'purposes.',
      'Access is limited by role and by row-level security. Only you and '
          'authorized Sangguniang Bayan personnel can read your records; '
          'uploaded files are served through short-lived signed links.',
      'Your data is retained only as long as necessary for the official '
          'purpose and applicable records-retention rules. You may ask the '
          'Sangguniang Bayan office about your rights under the Data Privacy '
          'Act, including access, correction and other rights provided by law.',
    ],
  ),
  AgreementSection(
    icon: Icons.block_outlined,
    title: 'Prohibited activities',
    summary:
        'Impersonation, forged documents, malware, harassment and unauthorized '
        'access are grounds for account action.',
    paragraphs: <String>[
      'The following are prohibited: impersonating another person, creating '
          'accounts with false identities, forging or tampering with documents, '
          'uploading malware, and using the system to harass or defraud '
          'another person.',
      'Attempting to access, modify or delete records you are not authorized '
          'to access is prohibited, whether through the interface or by direct '
          'technical means.',
      'Violations may lead to suspension or deactivation of the account and '
          'may be referred to the appropriate authorities.',
    ],
  ),
  AgreementSection(
    icon: Icons.update_outlined,
    title: 'Agreement updates',
    summary:
        'Accepting this revision is required before you can use the system; a '
        'new revision must be accepted when published.',
    paragraphs: <String>[
      'This is version ${AppBranding.agreementVersion} of the User Agreement, '
          'effective ${AppBranding.agreementEffectiveDate}.',
      'The Sangguniang Bayan office may update this agreement when the system '
          'or applicable rules change. A new revision must be accepted before '
          'you continue using the system.',
      'Your acceptance — the agreement version and the time you accepted it — '
          'is recorded on this device and, for a signed-in account, also stored '
          'with your profile so the office has an audit record.',
    ],
  ),
];
