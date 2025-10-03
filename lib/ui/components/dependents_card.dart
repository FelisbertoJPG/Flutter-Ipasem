import 'package:flutter/material.dart';
import '../../models/dependent.dart';
import '../../core/formatters.dart';
import '../../theme/colors.dart';

class DependentsCard extends StatelessWidget {
  const DependentsCard({
    super.key,
    required this.items,
    this.isLoading = false,
    this.error,
    this.compact = false,
    this.includeTitular = false, // <<< novo
    this.showMatricula = false,  // <<< novo
    this.onTap,
    this.showDivider = true,
  });

  final List<Dependent> items;
  final bool isLoading;
  final String? error;
  final bool compact;
  final bool includeTitular;
  final bool showMatricula;
  final void Function(Dependent dep)? onTap;
  final bool showDivider;

  bool _isTitular(Dependent d) => d.iddependente == 0;

  String _matriculaComposta(Dependent d) {
    final depSuf = d.iddependente.abs(); // cobre -1, -2...
    return '${d.idmatricula}-$depSuf';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = includeTitular
        ? items
        : items.where((d) => !_isTitular(d)).toList();

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kCardBorder, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('Dependentes'),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            )
          else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Nenhum dependente encontrado.'),
              )
            else
              ..._buildRows(filtered),
        ],
      ),
    );
  }

  List<Widget> _buildRows(List<Dependent> list) {
    final rows = <Widget>[];
    for (var i = 0; i < list.length; i++) {
      final d = list[i];
      final isTitular = _isTitular(d);
      final cpfTxt = (d.cpf == null || d.cpf!.isEmpty) ? '—' : fmtCpf(d.cpf!);
      final idadeTxt = (d.idade != null) ? '${d.idade} anos' : '—';
      final nascTxt = d.dtNasc == null || d.dtNasc!.isEmpty ? '—' : d.dtNasc!;
      final trailingTxt = isTitular ? 'Titular' : 'Dependente';
      final matriculaTxt = showMatricula ? _matriculaComposta(d) : null;

      rows.add(
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.family_restroom_outlined, color: Color(0xFF667085)),
          title: Text(
            d.nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF101828)),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CPF: $cpfTxt  •  Idade: $idadeTxt',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF475467)),
              ),
              Text(
                '• Nasc.: ${_fmtDataBr(nascTxt)}'
                    '${matriculaTxt != null ? '  •  Matr.: $matriculaTxt' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF475467)),
              ),
            ],
          ),
          trailing: Text(trailingTxt, style: const TextStyle(color: Color(0xFF667085))),
          minLeadingWidth: 0,
          onTap: onTap == null ? null : () => onTap!(d),
        ),
      );

      if (i != list.length - 1 && showDivider) {
        rows.add(const Divider(height: 8, thickness: 1, color: Color(0xFFE5E7EB)));
      }
    }
    return rows;
  }

  String _fmtDataBr(String ymd) {
    // espera "yyyy-MM-dd" do backend; se vier outro formato, só retorna original
    final parts = ymd.split('-');
    if (parts.length == 3) {
      return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
    }
    return ymd;
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF344054),
        ),
      ),
    );
  }
}
