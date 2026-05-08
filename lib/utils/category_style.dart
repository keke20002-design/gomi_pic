import 'package:flutter/material.dart';

import '../models/classification.dart';

const _burnableColor = Color(0xFFFF8A65);
const _nonBurnableColor = Color(0xFF78909C);
const _recyclableColor = Color(0xFF43A047);
const _oversizedColor = Color(0xFF9575CD);
const _otherColor = Color(0xFF9E9E9E);

Color categoryColor(GarbageCategory category) {
  switch (category) {
    case GarbageCategory.burnable:
      return _burnableColor;
    case GarbageCategory.nonBurnable:
      return _nonBurnableColor;
    case GarbageCategory.recyclable:
      return _recyclableColor;
    case GarbageCategory.oversized:
      return _oversizedColor;
    case GarbageCategory.other:
      return _otherColor;
  }
}
