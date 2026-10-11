import 'package:flutter/material.dart';

/// Identité « Signal » : un bleu royal lumineux (la vague Wi-Fi) sur des fonds clairs bleutés,
/// des cartes blanches très arrondies, une encre bleu nuit pour le mode sombre et un jaune « volt » pour les appels à l'action.
class WM {
  WM._();

  static const ink = Color(0xFF0A1220);
  static const midnight = Color(0xFF0F1B33);
  static const night = Color(0xFF16254A);

  static const signal = Color(0xFF4F86FF);
  static const signalDeep = Color(0xFF2456E5);
  static const wave = Color(0xFF1E48D6);
  static const volt = Color(0xFFFFD43B);
  static const coral = Color(0xFFE5484D);
  static const mint = Color(0xFFE4ECFF);
  static const success = Color(0xFF12915B);

  static const paper = Color(0xFFEEF3FF);
  static const line = Color(0xFFDDE5F5);
  static const slate = Color(0xFF5F6F8C);

  static const signalGradient = LinearGradient(
    colors: [signal, signalDeep, wave],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Ombre douce des cartes blanches.
  static List<BoxShadow> softShadow([double alpha = .08]) => [
        BoxShadow(color: const Color(0xFF2456E5).withValues(alpha: alpha), blurRadius: 24, offset: const Offset(0, 10)),
      ];

  static const nightGradient = LinearGradient(
    colors: [signal, signalDeep, wave],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
