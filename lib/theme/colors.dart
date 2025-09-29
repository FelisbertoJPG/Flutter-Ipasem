import 'package:flutter/material.dart';

const kBrand       = Color(0xFF143C8D);
const kCardBg      = Color(0xFFEFF6F9);
const kCardBorder  = Color(0xFFE2ECF2);
const kPanelBg     = Color(0xFFF4F5F7);
const kPanelBorder = Color(0xFFE5E8EE);

BoxDecoration blockDecoration() => BoxDecoration(
  color: kCardBg,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: kCardBorder, width: 2),
);
