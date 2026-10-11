import 'package:flutter/material.dart';

/// Identité « Signal » : un teal électrique qui glisse vers un bleu profond (la vague Wi-Fi),
/// une encre bleu nuit pour les fonds sombres et un ambre « volt » réservé aux promotions.
class WM {
  WM._();

  static const ink = Color(0xFF0A1220);
  static const midnight = Color(0xFF0F1B33);
  static const night = Color(0xFF16254A);

  static const signal = Color(0xFF00C2A8);
  static const signalDeep = Color(0xFF0A7F73);
  static const wave = Color(0xFF2F6BFF);
  static const volt = Color(0xFFFFB300);
  static const coral = Color(0xFFFF5D5D);
  static const mint = Color(0xFFD9FBF4);

  static const paper = Color(0xFFF4F7FB);
  static const line = Color(0xFFE2E8F2);
  static const slate = Color(0xFF5B6B84);

  static const signalGradient = LinearGradient(
    colors: [signal, wave],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const nightGradient = LinearGradient(
    colors: [ink, night],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
