import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

/// App language, mirroring the web site's EN / FR / AR switcher.
///
/// Strings come from the same `lang/*.json` catalogs the web app uses, fetched
/// from `/api/translations/{locale}` and layered over English server-side, so a
/// missing key still renders readable text.
class I18n extends ChangeNotifier {
  static const supported = <String, String>{
    'en': 'English',
    'fr': 'Français',
    'ar': 'العربية',
  };

  final ApiService api;
  I18n(this.api);

  String _locale = 'en';
  Map<String, String> _messages = const {};

  String get locale => _locale;
  bool get isRtl => _locale == 'ar';
  TextDirection get direction => isRtl ? TextDirection.rtl : TextDirection.ltr;

  /// Translate [key]. The key IS the English text (same convention as the web
  /// app's JSON catalogs), so an untranslated key degrades to English.
  String t(String key) => _messages[key] ?? key;

  /// Restore the saved language and load its strings.
  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('locale');
    _locale = supported.containsKey(saved) ? saved! : 'en';
    await _load();
  }

  Future<void> setLocale(String locale) async {
    if (!supported.containsKey(locale) || locale == _locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', locale);
    await _load();
  }

  Future<void> _load() async {
    try {
      _messages = await api.translations(_locale);
    } catch (_) {
      // Offline or server down — fall back to the untranslated keys.
      _messages = const {};
    }
    notifyListeners();
  }
}

/// `context.t('Projects')` — concise lookup used throughout the UI.
extension I18nContext on BuildContext {
  String t(String key) {
    // listen: false keeps this usable inside callbacks; screens that must
    // rebuild on a language change watch I18n explicitly.
    return I18nScope.of(this).t(key);
  }
}

/// Small indirection so `context.t()` works without importing provider
/// everywhere.
class I18nScope extends InheritedNotifier<I18n> {
  const I18nScope({super.key, required I18n notifier, required super.child})
      : super(notifier: notifier);

  static I18n of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<I18nScope>();
    assert(scope != null, 'I18nScope is missing above this widget');
    return scope!.notifier!;
  }
}
