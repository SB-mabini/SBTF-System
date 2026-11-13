import 'package:flutter/material.dart';

import '../branding.dart';
import '../theme.dart';

/// The logo shown beside the app name everywhere in the app.
///
/// This is the official Sangguniang Bayan ng Mabini seal, not the launcher
/// icon: the tricycle/document mark is reserved for the homescreen/app icon.
/// The seal is presented on a white disc so its black ring and colours stay
/// legible on light surfaces and on the purple splash/hero backgrounds.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 32,
    this.borderColor,
    this.elevated = false,
  });

  final double size;
  final Color? borderColor;

  /// Adds the soft shadow used on gradient surfaces (splash, welcome hero).
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${AppBranding.officeName} official seal',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: borderColor ?? AppColors.border,
            width: size >= 64 ? 1.5 : 1,
          ),
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: size * 0.22,
                    offset: Offset(0, size * 0.09),
                  ),
                ]
              : null,
        ),
        child: Image.asset(
          AppBranding.logoAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
