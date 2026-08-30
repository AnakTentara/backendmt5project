// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Produced by dashboard/scripts/export-dart-theme.ts from
// dashboard/src/design/tokens.ts. Regenerate with: npm run tokens:dart
//
// Editing this file directly will cause the Android app and the web dashboard to
// drift apart. Change the tokens and re-run the exporter instead.

import 'package:flutter/material.dart';

abstract final class AppSurface {
  static const Color base = Color(0xFF0A0E17);
  static const Color raised = Color(0xFF111725);
  static const Color overlay = Color(0xFF182032);
  static const Color hover = Color(0xFF1E283C);
  static const Color active = Color(0xFF25314A);
  static const Color border = Color(0xFF232D42);
  static const Color borderStrong = Color(0xFF33405C);
}

abstract final class AppText {
  static const Color primary = Color(0xFFE8EDF7);
  static const Color secondary = Color(0xFFA7B2C7);
  static const Color muted = Color(0xFF7A879E);
  static const Color disabled = Color(0xFF4E5A70);
  static const Color inverse = Color(0xFF08111F);
}

abstract final class AppMarket {
  static const Color bull = Color(0xFF00C9A7);
  static const Color bullSoft = Color(0xFF0B3E39);
  static const Color bullBorder = Color(0xFF12695F);
  static const Color bear = Color(0xFFFF7A45);
  static const Color bearSoft = Color(0xFF40211A);
  static const Color bearBorder = Color(0xFF8A3F27);
  static const Color flat = Color(0xFF7A879E);
  static const Color flatSoft = Color(0xFF1E283C);
}

abstract final class AppAccent {
  static const Color base = Color(0xFF3D8BFF);
  static const Color hover = Color(0xFF5A9DFF);
  static const Color pressed = Color(0xFF2E72D9);
  static const Color soft = Color(0xFF12233D);
  static const Color border = Color(0xFF2B5FA8);
}

abstract final class AppStatus {
  static const Color neutral = Color(0xFF7A879E);
  static const Color neutralSoft = Color(0xFF1E283C);
  static const Color info = Color(0xFF3D8BFF);
  static const Color infoSoft = Color(0xFF12233D);
  static const Color success = Color(0xFF00C9A7);
  static const Color successSoft = Color(0xFF0B3E39);
  static const Color warning = Color(0xFFF5B93B);
  static const Color warningSoft = Color(0xFF3D2F0F);
  static const Color danger = Color(0xFFFF7A45);
  static const Color dangerSoft = Color(0xFF40211A);
  static const Color critical = Color(0xFFFF4D6D);
  static const Color criticalSoft = Color(0xFF45141F);
}

abstract final class AppChart {
  static const Color grid = Color(0xFF1A2334);
  static const Color axis = Color(0xFF7A879E);
  static const Color crosshair = Color(0xFF5A9DFF);
  static const Color background = Color(0xFF111725);
}

abstract final class AppChartSeries {
  /// Categorical series colours. Order is significant and matches the web client.
  static const List<Color> palette = <Color>[
    Color(0xFF3D8BFF),
    Color(0xFF00C9A7),
    Color(0xFFF5B93B),
    Color(0xFFB07CFF),
    Color(0xFFFF7A45),
    Color(0xFF4ECDC4),
  ];
}

abstract final class AppSpacing {
  static const double s0 = 0.0;
  static const double s1 = 4.0;
  static const double s2 = 8.0;
  static const double s3 = 12.0;
  static const double s4 = 16.0;
  static const double s5 = 20.0;
  static const double s6 = 24.0;
  static const double s8 = 32.0;
  static const double s10 = 40.0;
  static const double s12 = 48.0;
  static const double s16 = 64.0;
}

abstract final class AppRadius {
  static const double none = 0.0;
  static const double sm = 4.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 9999.0;
}

abstract final class AppTypography {
  /// Numerals must use the mono family with tabular figures so values do not
  /// shift column width as they tick.
  static const String monoFamily = 'JetBrainsMono';
  static const String sansFamily = 'Inter';

  static const TextStyle caption = TextStyle(
    fontSize: 11.0,
    height: 1.455,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12.0,
    height: 1.500,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.0,
    height: 1.500,
  );

  static const TextStyle bodyLg = TextStyle(
    fontSize: 16.0,
    height: 1.500,
  );

  static const TextStyle metric = TextStyle(
    fontSize: 22.0,
    height: 1.273,
  );

  static const TextStyle metricLg = TextStyle(
    fontSize: 30.0,
    height: 1.200,
  );

  static const TextStyle display = TextStyle(
    fontSize: 40.0,
    height: 1.200,
  );
}

ThemeData buildTradeMachineTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppSurface.base,
    canvasColor: AppSurface.base,
    colorScheme: const ColorScheme.dark(
      surface: AppSurface.raised,
      primary: AppAccent.base,
      onPrimary: AppText.inverse,
      error: AppStatus.critical,
      outline: AppSurface.border,
    ),
    dividerColor: AppSurface.border,
    cardTheme: CardThemeData(
      color: AppSurface.raised,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppSurface.border),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: AppTypography.body,
      labelSmall: AppTypography.caption,
      headlineSmall: AppTypography.metric,
    ),
  );
}
