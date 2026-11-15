import 'package:flutter/material.dart';

import '../theme.dart';

/// Raises a blocking alert for a validation or action failure.
///
/// Forms in this app scroll, so an inline banner anchored to the top of the
/// page is frequently off screen at the moment the driver taps Submit — the
/// message was technically rendered but never read. Every action handler
/// reports through this dialog instead: it appears over the current scroll
/// position, states the problem in full, and waits to be acknowledged.
///
/// Load failures keep their inline placeholders (a section that cannot load
/// says so where its content would be); this dialog is for things the driver
/// just did.
Future<void> showAppErrorDialog(
  BuildContext context,
  String message, {
  String title = 'Please check this',
  String dismissLabel = 'OK',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.error_outline,
        color: AppColors.danger,
        size: 32,
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.inkStrong,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.inkStrong,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dismissLabel),
        ),
      ],
    ),
  );
}

/// Reports the first invalid field of [form] the same way, then scrolls that
/// field into view once the driver dismisses the dialog.
///
/// `FormState.validate()` only returns a bool, which is why a failed submit
/// used to look like nothing happened whenever the offending field was below
/// the fold. `validateGranularly()` names the field, so the dialog can repeat
/// its error text and the form can reveal it.
Future<void> showFormValidationErrors(
  BuildContext context,
  FormState? form, {
  String title = 'Cannot submit yet',
}) async {
  final Set<FormFieldState<Object?>> invalid = form == null
      ? const <FormFieldState<Object?>>{}
      : form.validateGranularly();
  if (invalid.isEmpty) return;

  final field = invalid.first;
  final message =
      field.errorText ?? 'Please complete the highlighted fields.';

  await showAppErrorDialog(context, message, title: title);

  if (!field.mounted) return;
  // A field outside a scroll view has nowhere to scroll to.
  if (Scrollable.maybeOf(field.context) == null) return;
  await Scrollable.ensureVisible(
    field.context,
    duration: const Duration(milliseconds: 250),
    alignment: 0.2,
  );
}
