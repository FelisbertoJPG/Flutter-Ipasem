// lib/services/dependent_utils.dart
import '../models/profile.dart';
import '../models/dependent.dart';

String _digits(String? s) => (s ?? '').replaceAll(RegExp(r'\D'), '');

/// A SP devolve titular + dependentes. Removemos o titular da lista.
List<Dependent> removeTitularFromList(Profile? prof, List<Dependent> list) {
  if (list.isEmpty) return list;

  final profCpf = _digits(prof?.cpf);

  final filtered = list.where((d) {
    final isTitularById  = (d.iddependente ?? 0) == 0;
    final isTitularByCpf = profCpf.isNotEmpty && _digits(d.cpf) == profCpf;
    return !(isTitularById || isTitularByCpf);
  }).toList();

  // fallback: se nada marcou titular, assume o 1º item é titular
  if (filtered.length == list.length && list.isNotEmpty) {
    return list.sublist(1);
  }
  return filtered;
}
