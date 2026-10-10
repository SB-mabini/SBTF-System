import 'package:flutter_test/flutter_test.dart';
import 'package:sbtf_mobile/core/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('spacing constants follow the 8px grid', () {
    expect(AppSpacing.unit, 8);
    expect(AppSpacing.xs % AppSpacing.unit, 0);
    expect(AppSpacing.sm % AppSpacing.unit, 0);
    expect(AppSpacing.md % AppSpacing.unit, 0);
    expect(AppSpacing.lg % AppSpacing.unit, 0);
  });

  test('the theme is Material 3 with the municipal palette', () {
    final theme = AppTheme.light;
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
  });
}
