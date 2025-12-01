// ui/theme_helpers.dart
import 'package:flutter/material.dart';
import '../../../theme/colors.dart';

BoxDecoration blockDecoration() => BoxDecoration(
  color: kCardBg, borderRadius: BorderRadius.circular(16),
  border: Border.all(color: kCardBorder, width: 2),
);

EdgeInsets pagePaddingForWidth(double w) =>
    EdgeInsets.fromLTRB(w >= 640 ? 24 : 16, 16, w >= 640 ? 24 : 16, 24);
