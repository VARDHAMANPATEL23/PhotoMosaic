import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  Brightness _brightness = Brightness.light;

  Brightness get brightness => _brightness;
  bool get isDarkMode => _brightness == Brightness.dark;

  void toggleTheme() {
    _brightness = _brightness == Brightness.light ? Brightness.dark : Brightness.light;
    notifyListeners();
  }
}
