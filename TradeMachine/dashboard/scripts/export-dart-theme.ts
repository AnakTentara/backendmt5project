/**
 * Dart theme exporter.
 *
 * Reads `src/design/tokens.ts` and emits a Flutter theme file. Run with:
 *   npm run tokens:dart
 *
 * WHY GENERATE RATHER THAN HAND-WRITE
 * -----------------------------------
 * The whole point of keeping tokens as data is that the web and Android clients
 * cannot drift apart. A hand-maintained Dart palette would be correct on the day
 * it was written and wrong a month later. Generating it means a colour change is
 * one edit plus one command.
 *
 * WHAT THIS DOES NOT DO
 * ---------------------
 * It exports colours, spacing, radii, and type scale — the values that are
 * genuinely shared. It does not attempt to translate layout, component
 * structure, or CSS shadows, because those have no faithful Flutter equivalent
 * and a fake mapping would be worse than none.
 */

import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tokens } from '../src/design/tokens';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const outputPath = resolve(scriptDir, '../generated/app_theme.dart');

/** `#RRGGBB` -> `0xFFRRGGBB`. Alpha is always opaque; tokens carry no alpha. */
function toDartColor(hex: string): string {
  const normalised = hex.replace('#', '').toUpperCase();
  if (!/^[0-9A-F]{6}$/.test(normalised)) {
    throw new Error(
      `Token colour "${hex}" is not a 6-digit hex string. ` +
        'The exporter requires plain #RRGGBB values; see the rules in tokens.ts.',
    );
  }
  return `0xFF${normalised}`;
}

/** Emits a class of `static const Color` fields from a flat token group. */
function emitColorClass(className: string, group: Record<string, string>): string {
  const fields = Object.entries(group)
    .map(([key, value]) => `  static const Color ${key} = Color(${toDartColor(value)});`)
    .join('\n');

  return `abstract final class ${className} {\n${fields}\n}\n`;
}

function emitSpacing(): string {
  const fields = Object.entries(tokens.spacing)
    .map(([key, value]) => `  static const double s${key} = ${value.toFixed(1)};`)
    .join('\n');

  return `abstract final class AppSpacing {\n${fields}\n}\n`;
}

function emitRadius(): string {
  const fields = Object.entries(tokens.radius)
    .map(([key, value]) => `  static const double ${key} = ${value.toFixed(1)};`)
    .join('\n');

  return `abstract final class AppRadius {\n${fields}\n}\n`;
}

function emitTypography(): string {
  const styles = Object.entries(tokens.typography.scale)
    .map(([key, [size, lineHeight]]) => {
      // Flutter expresses line height as a multiplier of font size, not an
      // absolute value, so the CSS pair is converted here.
      const heightMultiple = (lineHeight / size).toFixed(3);
      return `  static const TextStyle ${key} = TextStyle(
    fontSize: ${size.toFixed(1)},
    height: ${heightMultiple},
  );`;
    })
    .join('\n\n');

  return `abstract final class AppTypography {
  /// Numerals must use the mono family with tabular figures so values do not
  /// shift column width as they tick.
  static const String monoFamily = 'JetBrainsMono';
  static const String sansFamily = 'Inter';

${styles}
}
`;
}

function emitChartSeries(): string {
  const entries = tokens.chartSeries
    .map((hex) => `    Color(${toDartColor(hex)}),`)
    .join('\n');

  return `abstract final class AppChartSeries {
  /// Categorical series colours. Order is significant and matches the web client.
  static const List<Color> palette = <Color>[
${entries}
  ];
}
`;
}

/** Assembles a ThemeData wired to the exported palette. */
function emitThemeData(): string {
  return `ThemeData buildTradeMachineTheme() {
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
`;
}

const header = `// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Produced by dashboard/scripts/export-dart-theme.ts from
// dashboard/src/design/tokens.ts. Regenerate with: npm run tokens:dart
//
// Editing this file directly will cause the Android app and the web dashboard to
// drift apart. Change the tokens and re-run the exporter instead.

import 'package:flutter/material.dart';
`;

const output = [
  header,
  emitColorClass('AppSurface', tokens.surface),
  emitColorClass('AppText', tokens.text),
  emitColorClass('AppMarket', tokens.market),
  emitColorClass('AppAccent', tokens.accent),
  emitColorClass('AppStatus', tokens.status),
  emitColorClass('AppChart', tokens.chart),
  emitChartSeries(),
  emitSpacing(),
  emitRadius(),
  emitTypography(),
  emitThemeData(),
].join('\n');

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, output, 'utf8');

// eslint-disable-next-line no-console
console.warn(`[tokens:dart] Wrote ${outputPath}`);
