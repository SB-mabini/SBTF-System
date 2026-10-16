import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/constants.dart';
import '../../core/date_format.dart';
import '../../core/models/franchise_application.dart';
import '../../core/models/franchise_document.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/status_chip.dart';

/// Manages the documentary requirements of one application — slice 5.
///
/// Lists all four requirements in canonical order with their verification
/// state, and lets the driver replace a copy staff rejected (or one that is
/// still pending) while the application is under review.
///
/// Both limits are the server's, mirrored here so the buttons explain
/// themselves before a network call: `rpc_driver_replace_document` refuses a
/// document on a non-`pending` application and refuses a `verified` copy. The
/// replacement uploads to the caller's own storage folder first, exactly as the
/// RPC requires, then resets verification to `pending`.
class ApplicationDocumentsScreen extends ConsumerStatefulWidget {
  const ApplicationDocumentsScreen({super.key, required this.application});

  final FranchiseApplication application;

  @override
  ConsumerState<ApplicationDocumentsScreen> createState() =>
      _ApplicationDocumentsScreenState();
}

class _ApplicationDocumentsScreenState
    extends ConsumerState<ApplicationDocumentsScreen> {
  /// The document currently being replaced, so only its button shows a spinner.
  String? _busyDocumentId;

  /// The last refusal, shown above the list.
  String? _error;

  FranchiseApplication get _application => widget.application;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(applicationDetailProvider(_application.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () =>
              ref.refresh(applicationDetailProvider(_application.id).future),
          child: detailAsync.when(
            loading: () => _Body(
              application: _application,
              loading: true,
              busyDocumentId: _busyDocumentId,
              error: _error,
              onView: _view,
              onReplace: _replace,
            ),
            error: (error, _) => CenteredScrollView(
              child: ErrorView(
                error: error,
                onRetry: () =>
                    ref.invalidate(applicationDetailProvider(_application.id)),
              ),
            ),
            data: (detail) => _Body(
              application: detail ?? _application,
              loading: false,
              busyDocumentId: _busyDocumentId,
              error: _error,
              onView: _view,
              onReplace: _replace,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _view(FranchiseDocument document) {
    return showDialog<void>(
      context: context,
      builder: (_) => _DocumentPreviewDialog(document: document),
    );
  }

  Future<void> _replace(FranchiseDocument document) async {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) {
      setState(() =>
          _error = 'Your profile is still loading. Please wait and try again.');
      return;
    }

    final picked = await ref.read(documentPickerProvider).pick();
    if (!mounted || picked == null) return; // cancelled

    if (!picked.isAcceptedType) {
      setState(() => _error = 'Choose a PDF, JPEG or PNG file.');
      return;
    }
    if (!picked.isWithinSizeLimit) {
      setState(() => _error = 'Each document must not exceed 10 MB.');
      return;
    }

    setState(() {
      _busyDocumentId = document.id;
      _error = null;
    });

    final service = ref.read(documentServiceProvider);
    try {
      // The corrected file must be in the caller's own folder before the RPC
      // will accept it, so upload first and hand the path to replaceDocument.
      final path = await service.uploadDocument(
        profileId: profile.id,
        documentType: document.documentType,
        bytes: picked.bytes,
        fileName: picked.fileName,
        mimeType: picked.mimeType,
        applicationId: document.applicationId,
      );
      if (!mounted) return;

      await service.replaceDocument(
        documentId: document.id,
        storagePath: path,
        fileName: picked.fileName,
        fileSizeBytes: picked.sizeBytes,
        mimeType: picked.mimeType,
      );
      if (!mounted) return;

      setState(() => _busyDocumentId = null);
      // Re-fetch the documents, and refresh the trackers so the new state shows
      // everywhere the application is rendered.
      ref.invalidate(applicationDetailProvider(_application.id));
      ref.invalidate(myApplicationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document replaced. It will be reviewed again.'),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busyDocumentId = null;
        _error = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busyDocumentId = null;
        _error = 'Could not replace the document. Check your connection and '
            'try again.';
      });
    }
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.application,
    required this.loading,
    required this.busyDocumentId,
    required this.error,
    required this.onView,
    required this.onReplace,
  });

  final FranchiseApplication application;
  final bool loading;
  final String? busyDocumentId;
  final String? error;
  final ValueChanged<FranchiseDocument> onView;
  final ValueChanged<FranchiseDocument> onReplace;

  @override
  Widget build(BuildContext context) {
    final byType = <String, FranchiseDocument>{
      for (final document in application.documents)
        document.documentType: document,
    };
    final message = error;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xs),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Header(application: application),
        const SizedBox(height: AppSpacing.sm),
        if (message != null) ...[
          _ErrorBanner(message: message),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!application.isPending && !loading) ...[
          _Notice(
            icon: Icons.lock_outline,
            text: 'This application is ${application.status}. Documents can '
                'only be replaced while it is under review.',
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (loading)
          const _InlineLoading()
        else
          for (final type in requiredDocumentTypes) ...[
            _DocumentCard(
              label: documentLabels[type] ?? type,
              document: byType[type],
              replacing:
                  byType[type] != null && busyDocumentId == byType[type]!.id,
              canReplace:
                  application.isPending && (byType[type]?.canReplace ?? false),
              blockedNote:
                  application.isPending && (byType[type]?.isVerified ?? false)
                      ? 'Verified copies cannot be replaced.'
                      : null,
              onView: onView,
              onReplace: onReplace,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.application});

  final FranchiseApplication application;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  application.applicationNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              applicationStatusChip(application.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Upload a corrected copy of any requirement that was rejected.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.label,
    required this.document,
    required this.replacing,
    required this.canReplace,
    required this.blockedNote,
    required this.onView,
    required this.onReplace,
  });

  final String label;
  final FranchiseDocument? document;
  final bool replacing;
  final bool canReplace;
  final String? blockedNote;
  final ValueChanged<FranchiseDocument> onView;
  final ValueChanged<FranchiseDocument> onReplace;

  @override
  Widget build(BuildContext context) {
    final doc = document;
    final note = blockedNote;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.inkStrong,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (doc == null)
                  missingDocumentChip()
                else
                  documentStatusChip(doc.verificationStatus),
              ],
            ),
            const SizedBox(height: 3),
            if (doc == null)
              const Text(
                'No file has been recorded for this requirement.',
                style: TextStyle(color: AppColors.inkMuted, fontSize: 12),
              )
            else ...[
              if (doc.uploadedAt != null)
                Text(
                  'Uploaded ${formatDateTime(doc.uploadedAt)}',
                  style:
                      const TextStyle(color: AppColors.inkMuted, fontSize: 11),
                ),
              if (doc.isRejected && (doc.remarks ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  doc.remarks!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onView(doc),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('View'),
                    ),
                  ),
                  if (canReplace) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: replacing ? null : () => onReplace(doc),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: replacing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Replace'),
                      ),
                    ),
                  ],
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A modal preview of a stored document.
///
/// Files are private, so the dialog asks for a short-lived signed URL and, for
/// an image, renders it inline. A PDF cannot be rendered without a plugin the
/// app does not carry yet, so it says so plainly instead of failing.
class _DocumentPreviewDialog extends ConsumerStatefulWidget {
  const _DocumentPreviewDialog({required this.document});

  final FranchiseDocument document;

  @override
  ConsumerState<_DocumentPreviewDialog> createState() =>
      _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState
    extends ConsumerState<_DocumentPreviewDialog> {
  late final Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = ref
        .read(documentServiceProvider)
        .signedDocumentUrl(widget.document.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      document.shortLabel,
                      style: const TextStyle(
                        color: AppColors.inkStrong,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              FutureBuilder<String?>(
                future: _url,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _PreviewBox(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final url = snapshot.data;
                  if (url == null) {
                    return const _PreviewBox(
                      child: _PreviewMessage(
                        icon: Icons.error_outline,
                        text: 'Could not open this document right now. '
                            'Please try again.',
                      ),
                    );
                  }
                  if (_isImageDocument(document)) {
                    return ClipRRect(
                      borderRadius: AppRadius.box,
                      child: Image.network(
                        url,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) =>
                            const _PreviewBox(
                          child: _PreviewMessage(
                            icon: Icons.broken_image_outlined,
                            text:
                                'The preview could not be loaded. It may have '
                                'expired — reopen to refresh.',
                          ),
                        ),
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const _PreviewBox(
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                      ),
                    );
                  }
                  return const _PreviewBox(
                    child: _PreviewMessage(
                      icon: Icons.picture_as_pdf_outlined,
                      text: 'PDF preview is not available in the app yet. The '
                          'file is stored securely and staff can open it.',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: AppRadius.box,
      ),
      child: Center(child: child),
    );
  }
}

class _PreviewMessage extends StatelessWidget {
  const _PreviewMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: AppColors.inkMuted),
        const SizedBox(height: AppSpacing.xs),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.inkMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// True when the stored file is an image the app can render inline.
///
/// Falls back to the file extension when the row carries no MIME type.
bool _isImageDocument(FranchiseDocument document) {
  final mime = document.mimeType;
  if (mime != null && mime.isNotEmpty) {
    return mime == 'image/jpeg' || mime == 'image/png';
  }
  final name = document.fileName.toLowerCase();
  return name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.png');
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.greyFill,
        borderRadius: AppRadius.box,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dangerTint,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.box,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: LinearProgressIndicator(),
      ),
    );
  }
}
