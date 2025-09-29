import 'package:intl/intl.dart';

String fmtData(DateTime d) {
  // Ajuste locale conforme seu app (ex.: 'pt_BR')
  final f = DateFormat('dd/MM/yyyy');
  return f.format(d);
}

String fmtCpf(String digits) {
  final d = digits.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return digits;
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}
