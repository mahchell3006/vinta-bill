import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fr', 'DZ'));

  bool get isArabic => state.languageCode == 'ar';

  void setFrench() => state = const Locale('fr', 'DZ');
  void setArabic() => state = const Locale('ar', 'DZ');

  void toggle() {
    if (isArabic) {
      setFrench();
    } else {
      setArabic();
    }
  }
}
