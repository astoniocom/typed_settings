import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The locale to give `MaterialApp`, resolved from a [ValueListenable] of
/// `Locale?`.
///
/// [value] is [setting]'s value when one is chosen. When [setting] holds
/// `null`, "follow the device", [value] is the locale
/// [basicLocaleListResolution] picks from the device locales and
/// [supportedLocales]. Which of the two it is stays on [setting]: a chosen
/// locale can equal the one the device would resolve to, so [value] alone
/// cannot tell the picker "follow the device" from that language. A
/// `LocaleNullableSetting` is such a listenable; so is any other source
/// with that meaning of `null`.
///
/// Listeners are called when [setting] changes, including when [value]
/// stays the same, and when the device locales change while [setting]
/// holds null. A `MaterialApp` that listens here follows a language change
/// in the system settings. A device-locale change drops the resolved
/// locale even while a locale is chosen: returning to "follow the device"
/// afterwards must not reuse it.
///
/// The constructor reads [WidgetsBinding.instance], so a binding must
/// already exist. [dispose] drops the observer and the subscription to
/// [setting]. It does not dispose [setting].
final class AppliedLocale extends ChangeNotifier with WidgetsBindingObserver implements ValueListenable<Locale> {
  /// The resolution of [setting] over [supportedLocales].
  ///
  /// An [ArgumentError] when [supportedLocales] is empty.
  AppliedLocale({required this.setting, required Iterable<Locale> supportedLocales})
    : supportedLocales = List.unmodifiable(supportedLocales) {
    if (this.supportedLocales.isEmpty) {
      throw ArgumentError.value(supportedLocales, 'supportedLocales', 'must list at least one locale');
    }
    setting.addListener(notifyListeners);
    WidgetsBinding.instance.addObserver(this);
  }

  /// The choice this view follows. `null` means "follow the device".
  final ValueListenable<Locale?> setting;

  /// The translations the application ships, in the order
  /// [basicLocaleListResolution] should prefer them.
  final List<Locale> supportedLocales;

  /// The device locales observed since the resolution was last dropped,
  /// or null when the next [value] must read them again.
  List<Locale>? _deviceLocales;

  Locale? _resolved;
  var _disposed = false;

  /// The locale to give `MaterialApp.locale`.
  ///
  /// [setting]'s value when one is chosen, otherwise the locale resolved
  /// from the device and [supportedLocales].
  @override
  Locale get value => setting.value ?? _systemLocale;

  Locale get _systemLocale {
    final resolved = _resolved;
    if (resolved != null) return resolved;
    final locales = _deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales;
    final picked = basicLocaleListResolution(locales, supportedLocales);
    _resolved = picked;
    return picked;
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    _deviceLocales = locales;
    _resolved = null;
    if (setting.value == null) notifyListeners();
  }

  /// Drops the device-locale observer and the subscription to [setting].
  /// [setting] stays usable.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    setting.removeListener(notifyListeners);
    super.dispose();
  }
}
