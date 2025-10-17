// lib/ui/sheets/exame_detalhe_sheet.dart
import 'package:flutter/material.dart';
import '../../repositories/exames_repository.dart';
import '../../models/exame.dart';

/// Detalhe da autorização de exames.
/// Único botão: “PDF no app”. Habilita quando `status == 'A'`
/// ou quando `forcePodeImprimir == true`.
class ExameDetalheSheet extends StatefulWidget {
  final ExamesRepository repo;
  final int idMatricula;
  final int numero;

  final ExameResumo? resumo;
  final Future<void> Function(int numero)? onPdfNoApp;
  final bool forcePodeImprimir;

  const ExameDetalheSheet({
    super.key,
    required this.repo,
    required this.idMatricula,
    required this.numero,
    this.resumo,
    this.onPdfNoApp,
    this.forcePodeImprimir = false,
  });

  @override
  State<ExameDetalheSheet> createState() => _ExameDetalheSheetState();
}

class _ExameDetalheSheetState extends State<ExameDetalheSheet> {
  bool _loading = true;
  String? _error;
  ExameDetalhe? _detalhe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _detalhe = null; });
    try {
      final det = await widget.repo.consultarDetalhe(
        numero: widget.numero,
        idMatricula: widget.idMatricula,
      );
      if (!mounted) return;
      setState(() { _detalhe = det; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _detalhe = null; _loading = false; _error = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.resumo?.status ?? '').trim().toUpperCase();
    final podeImprimir = widget.forcePodeImprimir || status == 'A';

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, controller) {
          return Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('Dados da Autorização',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      IconButton(icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop()),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildBody(controller, podeImprimir),
                ),

                if (!_loading) _buildFooter(podeImprimir),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ScrollController controller, bool podeImprimir) {
    if (_detalhe == null && widget.resumo == null && _error != null) {
      return Center(child: Text('Erro ao carregar: $_error',
          style: const TextStyle(color: Colors.red)));
    }

    String coalesce(String a, String b) => a.trim().isNotEmpty ? a : b;

    final numeroStr = widget.numero.toString();
    final paciente  = coalesce(_detalhe?.paciente ?? '', widget.resumo?.paciente ?? '');
    final prestador = coalesce(_detalhe?.prestador ?? '', widget.resumo?.prestador ?? '');
    final especial  = coalesce(_detalhe?.especialidade ?? '', '');
    final dataEmis  = coalesce(_detalhe?.dataEmissao ?? '', widget.resumo?.dataHora ?? '');

    final endereco  = _detalhe?.endereco ?? '';
    final bairro    = _detalhe?.bairro ?? '';
    final cidade    = _detalhe?.cidade ?? '';
    final telefone  = _detalhe?.telefone ?? '';
    final observ    = _detalhe?.observacoes ?? '';
    final bairroCidade = [bairro, cidade].where((s) => s.trim().isNotEmpty).join(' - ');

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      children: [
        _kv('Número', numeroStr),
        _kv('Paciente', paciente),
        _kv('Prestador', prestador),
        _kv('Especialidade', especial),
        _kv('Data de Emissão', dataEmis),
        const Divider(),

        if (endereco.trim().isNotEmpty || bairroCidade.trim().isNotEmpty || telefone.trim().isNotEmpty) ...[
          _kv('Endereço', endereco),
          _kv('Bairro/Cidade', bairroCidade),
          if (telefone.trim().isNotEmpty) _kv('Telefone', telefone),
          if (observ.trim().isNotEmpty) ...[
            const Divider(),
            _kv('Observações', observ),
          ],
        ],

        if (!podeImprimir) ...[
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.hourglass_top_rounded, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Autorização ainda não liberada para impressão.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Você receberá a atualização assim que for analisada.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(bool podeImprimir) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF no app'),
          onPressed: (podeImprimir && widget.onPdfNoApp != null)
              ? () async => widget.onPdfNoApp!(widget.numero)
              : null,
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    final value = v.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(k, style: const TextStyle(color: Colors.black54))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
