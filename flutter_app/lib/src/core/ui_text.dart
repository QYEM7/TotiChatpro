import 'dart:convert';
import 'package:flutter/services.dart';

/// Arabic copy lives in an asset, not in business logic or Dart UI code.
abstract final class UiText {
  static Map<String, String> _values = const {};

  static Future<void> load() async {
    final content = await rootBundle.loadString('assets/i18n/ar.json');
    final json = jsonDecode(content) as Map<String, dynamic>;
    _values = json.map((key, value) => MapEntry(key, value.toString()));
  }

  static String get(String key) => _values[key] ?? key;
}
