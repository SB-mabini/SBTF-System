import 'package:flutter/material.dart';

import '../../core/branding.dart';
import '../../core/onboarding/language.dart';
import '../../core/onboarding/onboarding_content.dart';
import '../../core/onboarding/onboarding_state.dart';
import '../../core/onboarding/onboarding_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/brand_mark.dart';
import 'full_agreement_screen.dart';

/// The first-run journey.
///
/// Pages, in order: welcome, language, four introduction slides, the User
/// Agreement, and a completion summary. The flow never touches Supabase or the
/// existing auth/session logic; it only writes local preferences, and
/// `AgreementService` mirrors the acceptance after sign-in.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.store,
    required this.initialPage,
    required this.onFinished,
  });

  final OnboardingStore store;

  /// Resume position. Returning users with an outdated agreement start at the
  /// agreement instead of replaying the introduction.
  final int initialPage;

  final VoidCallback onFinished;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  late final PageController _pageController;
  late int _page;
  late String _languageCode;
  bool _accepted = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, OnboardingStep.finished);
    _languageCode = widget.store.state.languageCode;
    _pageController = PageController(initialPage: _page);
    if (_page < OnboardingStep.finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.store.saveStep(_page);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _needsAgreementUpdate =>
      widget.store.state.completed && !widget.store.state.agreementIsCurrent;

  bool get _showSkip =>
      _page >= OnboardingStep.introFirst && _page <= OnboardingStep.introLast;

  bool get _canGoBack => _page > 0 && _page < OnboardingStep.finished;

  bool get _primaryEnabled =>
      !_busy && (_page != OnboardingStep.agreement || _accepted);

  String get _primaryLabel {
    if (_page == OnboardingStep.welcome) return 'Get started';
    if (_page == OnboardingStep.language) return 'Continue';
    if (_page >= OnboardingStep.introFirst &&
        _page < OnboardingStep.introLast) {
      return 'Next';
    }
    if (_page == OnboardingStep.introLast) return 'Review agreement';
    if (_page == OnboardingStep.agreement) return 'Accept and continue';
    return 'Continue';
  }

  void _goTo(int page) {
    final target = page.clamp(0, OnboardingStep.finished);
    if (target == _page) return;
    if (_reduceMotion) {
      _pageController.jumpToPage(target);
    } else {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handlePageChanged(int page) {
    setState(() => _page = page);
    if (page < OnboardingStep.finished) {
      widget.store.saveStep(page).ignore();
    }
  }

  Future<void> _selectLanguage(String code) async {
    if (code == _languageCode) return;
    setState(() => _languageCode = code);
    await widget.store.setLanguage(code);
  }

  Future<void> _primaryAction() async {
    if (!_primaryEnabled) return;

    if (_page == OnboardingStep.agreement) {
      setState(() => _busy = true);
      await widget.store.acceptAgreement();
      if (!mounted) return;
      setState(() => _busy = false);
      _goTo(OnboardingStep.finished);
      return;
    }

    if (_page == OnboardingStep.finished) {
      setState(() => _busy = true);
      await widget.store.complete();
      if (!mounted) return;
      widget.onFinished();
      return;
    }

    _goTo(_page + 1);
  }

  void _openFullAgreement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FullAgreementScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              showSkip: _showSkip,
              onSkip: () => _goTo(OnboardingStep.agreement),
            ),
            ClipRect(
              child: LinearProgressIndicator(
                value: (_page + 1) / OnboardingStep.count,
                minHeight: 3,
                backgroundColor: AppColors.primaryTint,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _handlePageChanged,
                children: [
                  const _WelcomeStep(),
                  _LanguageStep(
                    languageCode: _languageCode,
                    onChanged: _selectLanguage,
                  ),
                  for (var i = 0; i < onboardingSlides.length; i++)
                    _IntroStep(slide: onboardingSlides[i], index: i),
                  _AgreementStep(
                    accepted: _accepted,
                    needsUpdate: _needsAgreementUpdate,
                    onChanged: (value) => setState(() => _accepted = value),
                    onReadFull: _openFullAgreement,
                  ),
                  _FinishedStep(
                    languageCode: _languageCode,
                    agreementAcceptedAt: widget.store.state.agreementAcceptedAt,
                  ),
                ],
              ),
            ),
            _Footer(
              showBack: _canGoBack,
              busy: _busy,
              enabled: _primaryEnabled,
              label: _primaryLabel,
              onBack: () => _goTo(_page - 1),
              onPrimary: _primaryAction,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.compact,
        AppSpacing.xs,
        AppSpacing.compact,
      ),
      child: Row(
        children: [
          const BrandMark(size: 30),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppBranding.appName,
                  style: TextStyle(
                    color: AppColors.inkStrong,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                Text(
                  AppBranding.officeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (showSkip)
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip'),
            )
          else
            const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.showBack,
    required this.busy,
    required this.enabled,
    required this.label,
    required this.onBack,
    required this.onPrimary,
  });

  final bool showBack;
  final bool busy;
  final bool enabled;
  final String label;
  final VoidCallback onBack;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.compact,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            children: [
              if (showBack) ...[
                SizedBox(
                  width: 96,
                  child: OutlinedButton(
                    onPressed: busy ? null : onBack,
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: enabled ? onPrimary : null,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(label),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared scrollable step body, width-capped for tablets and desktop browsers.
class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.child, this.center = false});

  final Widget child;
  final bool center;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(AppSpacing.md);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = (constraints.maxHeight - padding.vertical)
            .clamp(0.0, double.infinity);
        return SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 560, minHeight: minHeight),
              child: center ? Center(child: child) : child,
            ),
          ),
        );
      },
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.eyebrow,
    required this.title,
    required this.summary,
  });

  final String eyebrow;
  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accentStrong,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          summary,
          style: const TextStyle(
            color: AppColors.inkMuted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Welcome
// ---------------------------------------------------------------------------

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      center: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: AppRadius.hero,
              boxShadow: AppShadows.raised,
            ),
            child: Column(
              children: [
                const BrandMark(
                  size: 104,
                  borderColor: Color(0x40FFFFFF),
                  elevated: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'WELCOME TO',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  AppBranding.appName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppBranding.officeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Your franchise and driver registration, in one place',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkStrong,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.3,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'File and track your tricycle franchise application, manage your '
            'requirements, and keep your certificate and official updates '
            'within reach — from the Municipality of Mabini, Batangas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _Pill(icon: Icons.assignment_outlined, label: 'Applications'),
              _Pill(icon: Icons.track_changes_outlined, label: 'Tracking'),
              _Pill(icon: Icons.verified_outlined, label: 'Certificate'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'The next screens take less than a minute.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkMuted.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language
// ---------------------------------------------------------------------------

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({
    required this.languageCode,
    required this.onChanged,
  });

  final String languageCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            eyebrow: 'Step 1 of 3 · Language',
            title: 'Choose your language',
            summary: 'Pick the language used across the application. You can '
                'change this later in Settings.',
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                for (final language in AppLanguages.supported)
                  _LanguageTile(
                    language: language,
                    selected: language.code == languageCode,
                    onTap: () => onChanged(language.code),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.infoTint,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.info),
                SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'English is the only language fully available in this '
                    'release. The application will not offer a language it '
                    'cannot display.',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.compact,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryTint : AppColors.greyFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate_outlined,
                size: 20,
                color: selected ? AppColors.primary : AppColors.inkMuted,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.displayName,
                    style: const TextStyle(
                      color: AppColors.inkStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected ? 'Selected' : 'Tap to select',
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.inkMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.borderStrong,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Introduction slides
// ---------------------------------------------------------------------------

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.slide, required this.index});

  final OnboardingSlide slide;
  final int index;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final content = _StepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          _StepTitle(
            eyebrow: 'Step 2 of 3 · ${slide.eyebrow}',
            title: slide.title,
            summary: slide.summary,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final point in slide.points)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < onboardingSlides.length; i++)
                AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == index ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color:
                        i == index ? AppColors.primary : AppColors.borderStrong,
                    borderRadius: AppRadius.chip,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              '${index + 1} of ${onboardingSlides.length}',
              style: const TextStyle(
                color: AppColors.inkMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (reduceMotion) return content;

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(index),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - value)),
          child: child,
        ),
      ),
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// Agreement
// ---------------------------------------------------------------------------

class _AgreementStep extends StatelessWidget {
  const _AgreementStep({
    required this.accepted,
    required this.needsUpdate,
    required this.onChanged,
    required this.onReadFull,
  });

  final bool accepted;
  final bool needsUpdate;
  final ValueChanged<bool> onChanged;
  final VoidCallback onReadFull;

  @override
  Widget build(BuildContext context) {
    return _StepScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle(
            eyebrow: 'Step 3 of 3 · Terms',
            title: 'User Agreement',
            summary: 'Version ${AppBranding.agreementVersion} · effective '
                '${AppBranding.agreementEffectiveDate}',
          ),
          if (needsUpdate) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: AppRadius.card,
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'The User Agreement has been updated. Please review and '
                      'accept this revision to continue.',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < agreementSections.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _AgreementSummaryRow(section: agreementSections[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: onReadFull,
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Read the complete agreement'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            checked: accepted,
            child: InkWell(
              onTap: () => onChanged(!accepted),
              borderRadius: AppRadius.card,
              child: AnimatedContainer(
                duration:
                    MediaQuery.maybeOf(context)?.disableAnimations ?? false
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accepted ? AppColors.primaryTint : AppColors.surface,
                  borderRadius: AppRadius.card,
                  border: Border.all(
                    color: accepted ? AppColors.primary : AppColors.border,
                    width: accepted ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: accepted,
                        onChanged: (value) => onChanged(value ?? false),
                        activeColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.borderStrong,
                          width: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    const Expanded(
                      child: Text(
                        'I have read and understood the User Agreement, and I '
                        'accept its terms for using the SBTF System.',
                        style: TextStyle(
                          color: AppColors.inkStrong,
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'You must accept the agreement before you can continue.',
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreementSummaryRow extends StatelessWidget {
  const _AgreementSummaryRow({required this.section});

  final AgreementSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(section.icon, size: 17, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(
                    color: AppColors.inkStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  section.summary,
                  style: const TextStyle(
                    color: AppColors.inkMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Completion
// ---------------------------------------------------------------------------

class _FinishedStep extends StatelessWidget {
  const _FinishedStep({
    required this.languageCode,
    required this.agreementAcceptedAt,
  });

  final String languageCode;
  final DateTime? agreementAcceptedAt;

  @override
  Widget build(BuildContext context) {
    final language = AppLanguages.byCode(languageCode);
    final acceptedAt = agreementAcceptedAt?.toLocal();

    return _StepScroll(
      center: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.successTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 46,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            "You're all set",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkStrong,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Your preferences are saved on this device. You can review the '
            'agreement or change your language later in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                _SummaryRow(
                  icon: Icons.translate_outlined,
                  label: 'Language',
                  value: language.displayName,
                ),
                const Divider(height: 1),
                _SummaryRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Agreement',
                  value: 'Version ${AppBranding.agreementVersion} accepted',
                ),
                if (acceptedAt != null) ...[
                  const Divider(height: 1),
                  _SummaryRow(
                    icon: Icons.schedule_outlined,
                    label: 'Accepted on',
                    value: _formatDate(acceptedAt),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Next, sign in or create your driver account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.compact,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.inkMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.inkMuted,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.inkStrong,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour < 12 ? 'AM' : 'PM';
  return '${value.day} ${months[value.month - 1]} ${value.year}, '
      '$hour:$minute $period';
}
