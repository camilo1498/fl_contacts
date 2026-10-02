import 'package:flutter/material.dart';

/// Gradient palette assigned deterministically from any seed string.
class AvatarPalette {
  const AvatarPalette._();

  static const _gradients = [
    [Color(0xFF7C4DFF), Color(0xFF448AFF)],
    [Color(0xFF00BFA5), Color(0xFF64DD17)],
    [Color(0xFFFF6E40), Color(0xFFFFD740)],
    [Color(0xFFE040FB), Color(0xFF7C4DFF)],
    [Color(0xFF00B0FF), Color(0xFF00E5FF)],
    [Color(0xFFFF5252), Color(0xFFFFAB40)],
    [Color(0xFF69F0AE), Color(0xFF00BFA5)],
    [Color(0xFFB388FF), Color(0xFF8C9EFF)],
  ];

  /// Gradient pair for [seed] (usually the display name).
  static List<Color> of(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _gradients[hash % _gradients.length];
  }
}
