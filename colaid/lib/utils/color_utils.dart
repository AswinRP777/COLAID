import 'dart:ui';

String getColorName(Color color) {
  final r = color.r;
  final g = color.g;
  final b = color.b;

  final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
  final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
  final delta = maxC - minC;

  double hue = 0;

  // Hue calculation
  if (delta != 0) {
    if (maxC == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (maxC == g) {
      hue = 60 * (((b - r) / delta) + 2);
    } else {
      hue = 60 * (((r - g) / delta) + 4);
    }
  }

  if (hue < 0) hue += 360;

  final saturation = maxC == 0 ? 0 : delta / maxC;
  final value = maxC;

  // --- BLACK / WHITE / GRAY ---
  if (value < 0.15) return "Black";
  if (value > 0.9 && saturation < 0.15) return "White";
  if (saturation < 0.2) return "Gray";

  // --- COLOR BY HUE ---
  if (hue >= 0 && hue < 15) return "Red";
  if (hue >= 15 && hue < 45) return "Orange";
  if (hue >= 45 && hue < 65) return "Yellow";
  if (hue >= 65 && hue < 170) return "Green";
  if (hue >= 170 && hue < 260) return "Blue";
  if (hue >= 260 && hue < 290) return "Purple";
  if (hue >= 290 && hue < 345) return "Pink";
  if (hue >= 345) return "Red";

  return "Unknown color";
}
