import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/config/theme.dart';

void main() {
  test('accent seed drives the generated color scheme', () {
    final teal = buildAppTheme(
      brightness: Brightness.light,
      accent: AppAccentTheme.teal,
    );
    final clay = buildAppTheme(
      brightness: Brightness.light,
      accent: AppAccentTheme.clay,
    );

    expect(teal.colorScheme.primary, isNot(clay.colorScheme.primary));
    expect(teal.useMaterial3, isTrue);
    expect(AppAccentTheme.values.length, greaterThanOrEqualTo(4));
  });

  test('background preset overrides the scaffold per brightness', () {
    final light = buildAppTheme(
      brightness: Brightness.light,
      background: AppBackgroundTheme.paper,
    );
    final dark = buildAppTheme(
      brightness: Brightness.dark,
      background: AppBackgroundTheme.paper,
    );

    expect(light.scaffoldBackgroundColor, AppBackgroundTheme.paper.light);
    expect(dark.scaffoldBackgroundColor, AppBackgroundTheme.paper.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
  });

  test('surface opacity below 1 makes surfaces translucent and scaffold transparent', () {
    final plain = buildAppTheme(brightness: Brightness.light);
    final translucent = buildAppTheme(
      brightness: Brightness.light,
      surfaceAlpha: 0.6,
    );

    expect(translucent.scaffoldBackgroundColor, Colors.transparent);
    expect(plain.scaffoldBackgroundColor, isNot(Colors.transparent));
    expect(translucent.colorScheme.surface.a, closeTo(0.6, 0.001));
    expect(plain.colorScheme.surface.a, 1.0);
    expect(
      translucent.colorScheme.surfaceContainerLow.a,
      lessThan(1.0),
      reason: 'M3 的卡片用 surfaceContainerLow，透明度必须也作用到它',
    );
  });

  test('auto background keeps following the theme defaults', () {
    final auto = buildAppTheme(brightness: Brightness.light);
    final warm = buildAppTheme(
      brightness: Brightness.light,
      background: AppBackgroundTheme.warm,
    );

    expect(auto.scaffoldBackgroundColor, isNot(warm.scaffoldBackgroundColor));
  });
}