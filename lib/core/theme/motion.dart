import 'package:flutter/animation.dart';

/// Langage de mouvement commun : mêmes durées et courbes partout pour une sensation cohérente.
class Motion {
  Motion._();
  static const quick = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 560);
  static const page = Duration(milliseconds: 380);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve spring = Curves.elasticOut;

  /// Décalage d'entrée en cascade pour les listes (plafonné pour rester vif).
  static Duration stagger(int index, {int step = 55, int max = 8}) =>
      Duration(milliseconds: step * (index > max ? max : index));
}
