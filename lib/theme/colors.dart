// lib/theme/colors.dart
import 'package:flutter/material.dart';

/// Marca principal
const kBrand = Color(0xFF143C8D);            // Azul IPASEM

/// Superfícies
// Antes: 0xFFEFF6F9 → muito claro; escurecemos e tiramos um pouco do azulado
const kCardBg      = Color(0xFFE8EEF2);      // Cards/tiles
// Antes: 0xFFF4F5F7 → deixamos um cinza um pouco mais “presente”
const kPanelBg     = Color(0xFFE9EBEF);      // Painéis/avisos

/// Contornos (borders/dividers)
// Antes: 0xFFE2ECF2 → quase sumia em telas claras
const kCardBorder  = Color(0xFFCBD5DF);      // Borda de cards/tiles
// Antes: 0xFFE5E8EE → pouco contraste
const kPanelBorder = Color(0xFFCDD2DA);      // Borda de painéis

/// Texto “neutro” (para casos pontuais onde você precisa de referência de cor)
const kTextPrimary   = Color(0xFF101828);
const kTextSecondary = Color(0xFF475467);
const kIconMuted     = Color(0xFF667085);

/// Helper para decorar blocos com aparência padrão do app
BoxDecoration blockDecoration() => BoxDecoration(
  color: kCardBg,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: kCardBorder, width: 2),
);

/// Divisor padrão (pode ser usado em containers customizados)
const kDividerColor = Color(0xFFCED6DE);
