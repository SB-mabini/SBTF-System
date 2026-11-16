/// The app's UI kit entry point.
///
/// Every widget file imports this instead of `package:flutter/material.dart`.
/// It re-exports Material but replaces [Text] with a localising wrapper, so any
/// literal rendered by the app is translated to the active language without
/// changing the hundreds of call sites.
///
/// Strings that come from the server (announcements, remarks, names) must opt
/// out with `translate: false` so backend content always stays as delivered.
library;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material;

import 'l10n/app_localizations.dart';

export 'package:flutter/material.dart' hide Text;

export 'l10n/app_localizations.dart' show AppLocalizations, tr;

/// A [material.Text] that renders its [data] (or span text) in the active
/// language.
///
/// The constructor mirrors the Material widget so existing `const Text(...)`
/// call sites keep compiling. Widget tests that build a bare `MaterialApp`
/// resolve to English, so the default test experience is unchanged.
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.translate = true,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.translate = true,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  /// Set to false for server-provided or user-provided content that must not be
  /// touched by the UI dictionary.
  final bool translate;

  @override
  Widget build(BuildContext context) {
    final l10n = translate ? AppLocalizations.of(context) : null;

    if (data != null) {
      return material.Text(
        l10n == null ? data! : l10n.t(data!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel:
            semanticsLabel == null || l10n == null ? semanticsLabel : l10n.t(semanticsLabel!),
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }

    return material.Text.rich(
      l10n == null ? textSpan! : _localiseSpan(textSpan!, l10n),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel:
          semanticsLabel == null || l10n == null ? semanticsLabel : l10n.t(semanticsLabel!),
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }

  static InlineSpan _localiseSpan(InlineSpan span, AppLocalizations l10n) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text == null ? null : l10n.t(span.text!),
      children: span.children
          ?.map((child) => _localiseSpan(child, l10n))
          .toList(growable: false),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel:
          span.semanticsLabel == null ? null : l10n.t(span.semanticsLabel!),
      locale: span.locale,
    );
  }
}
