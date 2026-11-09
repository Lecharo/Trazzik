import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Loads and caches embedded Roboto TrueType fonts so all generated PDFs
/// render full Unicode glyphs (Spanish accents, m², —, ×, °, bullets) offline.
class PdfThemeLoader {
  const PdfThemeLoader._();

  static pw.ThemeData? _cachedTheme;

  static Future<pw.ThemeData> loadTheme() async {
    final existing = _cachedTheme;
    if (existing != null) return existing;

    final regularData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    final italicData = await rootBundle.load('assets/fonts/Roboto-Italic.ttf');
    final boldItalicData =
        await rootBundle.load('assets/fonts/Roboto-BoldItalic.ttf');

    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularData),
      bold: pw.Font.ttf(boldData),
      italic: pw.Font.ttf(italicData),
      boldItalic: pw.Font.ttf(boldItalicData),
    );

    _cachedTheme = theme;
    return theme;
  }
}
