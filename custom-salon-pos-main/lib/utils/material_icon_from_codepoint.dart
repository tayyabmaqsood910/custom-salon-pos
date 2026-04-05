import 'package:flutter/material.dart';

import '../models/models.dart';

/// Maps stored Material code points to const [IconData] so `flutter build web`
/// can tree-shake icon fonts (dynamic [IconData] is rejected).
IconData materialIconFromCodePoint(int codePoint) {
  if (codePoint == Icons.content_cut.codePoint) return Icons.content_cut;
  if (codePoint == Icons.cut.codePoint) return Icons.cut;
  if (codePoint == Icons.child_care.codePoint) return Icons.child_care;
  if (codePoint == Icons.color_lens.codePoint) return Icons.color_lens;
  if (codePoint == Icons.face.codePoint) return Icons.face;
  if (codePoint == Icons.face_retouching_natural.codePoint) {
    return Icons.face_retouching_natural;
  }
  if (codePoint == Icons.spa.codePoint) return Icons.spa;
  if (codePoint == Icons.water_drop.codePoint) return Icons.water_drop;
  if (codePoint == Icons.back_hand.codePoint) return Icons.back_hand;
  if (codePoint == Icons.star.codePoint) return Icons.star;
  if (codePoint == Icons.edit.codePoint) return Icons.edit;
  return Icons.category;
}

extension ServiceItemMaterialIcon on ServiceItem {
  IconData get icon => materialIconFromCodePoint(iconCodePoint);
}
