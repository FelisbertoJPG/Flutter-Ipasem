import 'package:flutter/material.dart';

/// Linha divisória usada entre itens do menu.
const kMenuDivider = BorderSide(color: Color(0xFFE6E9EF), width: 0.8);

/// Constrói itens de menu com uma borda inferior sutil (exceto no último).
List<DropdownMenuItem<T>> buildMenuItems<T>({
  required List<T> data,
  required String Function(T) labelOf,
}) {
  final out = <DropdownMenuItem<T>>[];
  for (var i = 0; i < data.length; i++) {
    final e = data[i];
    final isLast = i == data.length - 1;
    out.add(
      DropdownMenuItem<T>(
        value: e,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: isLast ? null : const Border(bottom: kMenuDivider),
          ),
          child: Text(labelOf(e), maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
  return out;
}

/// Define como o item selecionado aparece no campo fechado
/// (alinhado à esquerda e com ellipsis).
List<Widget> buildSelecteds<T>({
  required List<T> data,
  required String Function(T) labelOf,
}) {
  return data
      .map((e) => Align(
    alignment: Alignment.centerLeft,
    child: Text(labelOf(e), maxLines: 1, overflow: TextOverflow.ellipsis),
  ))
      .toList();
}
