import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLang {
  hi,
  en,
}

class LanguageService {
  static final LanguageService instance = LanguageService._internal();
  LanguageService._internal();

  static const String _prefKey = 'app_language';
  final ValueNotifier<AppLang> currentLanguage = ValueNotifier<AppLang>(AppLang.hi);

  bool get isHindi => currentLanguage.value == AppLang.hi;
  bool get isEnglish => currentLanguage.value == AppLang.en;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'hi';
      currentLanguage.value = code == 'en' ? AppLang.en : AppLang.hi;
    } catch (_) {
      currentLanguage.value = AppLang.hi;
    }
  }

  Future<void> setLanguage(AppLang lang) async {
    currentLanguage.value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang == AppLang.en ? 'en' : 'hi');
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    final next = currentLanguage.value == AppLang.hi ? AppLang.en : AppLang.hi;
    await setLanguage(next);
  }
}
