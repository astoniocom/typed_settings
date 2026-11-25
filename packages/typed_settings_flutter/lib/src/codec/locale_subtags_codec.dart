import 'dart:ui';

import 'package:typed_settings/typed_settings_extend.dart';

/// Stores a [Locale] as its language, script and region: `en`, `en-US`,
/// `zh-Hans-CN`.
///
/// A [Locale] has no variant or extension, and a tag that carries one
/// (`de-DE-1996`, `en-US-u-ca-gregory`) is not a value of this codec.
/// [encode] throws a [FormatException] when the locale's own subtags are
/// not that triple, so the assignment fails before anything is stored.
/// [decode] throws one for any other tag, including a variant or an
/// extension, and the setting then falls back to its default. `_` is
/// accepted as a separator where `Platform.localeName` writes it.
final class LocaleSubtagsCodec implements SettingCodec<Locale, String> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const LocaleSubtagsCodec();

  static final _separator = RegExp('[-_]');
  static final _language = RegExp(r'^[a-zA-Z]{2,8}$');
  static final _script = RegExp(r'^[a-zA-Z]{4}$');
  static final _region = RegExp(r'^([a-zA-Z]{2}|\d{3})$');

  @override
  Locale decode(String raw) {
    final subtags = raw.split(_separator);
    if (!_language.hasMatch(subtags.first)) throw FormatException('Expected a language tag', raw);
    var next = 1;
    String? take(RegExp pattern) => next < subtags.length && pattern.hasMatch(subtags[next]) ? subtags[next++] : null;
    final script = take(_script);
    final region = take(_region);
    if (next < subtags.length) {
      throw FormatException('Expected a language, an optional script and an optional region', raw);
    }
    return Locale.fromSubtags(languageCode: subtags.first, scriptCode: script, countryCode: region);
  }

  @override
  String encode(Locale value) {
    final language = value.languageCode;
    final script = _present(value.scriptCode);
    final region = _present(value.countryCode);
    if (!_language.hasMatch(language) ||
        (script != null && !_script.hasMatch(script)) ||
        (region != null && !_region.hasMatch(region))) {
      throw FormatException(
        'Expected a language, an optional script and an optional region',
        value.toLanguageTag(),
      );
    }
    final tag = StringBuffer(language);
    if (script != null) tag.write('-$script');
    if (region != null) tag.write('-$region');
    return tag.toString();
  }

  /// [subtag] when it carries a value, or null for an absent one. An empty
  /// country is how [Locale] spells "no region".
  static String? _present(String? subtag) => subtag == null || subtag.isEmpty ? null : subtag;
}
