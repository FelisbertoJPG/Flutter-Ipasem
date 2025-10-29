import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/dev_api.dart';

class CarteirinhaDigitalScreen extends StatefulWidget {
  final int idMatricula;
  final int idDependente; // 0 = titular
  final String? nomeTitular;
  final DevApi? api;

  const CarteirinhaDigitalScreen({
    Key? key,
    required this.idMatricula,
    this.idDependente = 0,
    this.nomeTitular,
    this.api,
  }) : super(key: key);

  @override
  State<CarteirinhaDigitalScreen> createState() => _CarteirinhaDigitalScreenState();
}

class _CarteirinhaDigitalScreenState extends State<CarteirinhaDigitalScreen> {
  final DevApi _fallbackApi = DevApi(
    const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98'),
  );

  DevApi get _api => widget.api ?? _fallbackApi;

  bool _loading = true;
  String? _error;

  // dados renderizados no card
  String _nome = '';
  String _cpf = '';
  String _sexoTxt = '';
  String? _nascimento;

  // token/expiração
  String _token = '';
  int? _expiresEpoch;
  int? _serverNowEpoch;

  Timer? _tick;

  Duration get _remaining {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final end = _expiresEpoch ?? now;
    final diff = end - now;
    return Duration(seconds: diff < 0 ? 0 : diff);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _issueAndLoad();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _issueAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.postAction<dynamic>(
        'carteirinha_pessoa',
        data: {
          'matricula': widget.idMatricula,
          'iddependente': widget.idDependente,
        },
      );

      final m = (res.data as Map).cast<String, dynamic>();
      if (m['ok'] != true) {
        throw Exception('Falha na emissão do token.');
      }
      final data = (m['data'] as Map).cast<String, dynamic>();

      setState(() {
        _nome = _extrairLinha(data['string'] ?? '', 0) ?? '';
        _cpf = _extrairCampo(data['string'] ?? '', 'CPF:') ?? '';
        _sexoTxt = (data['sexo_txt'] as String?) ?? '';
        _nascimento = _extrairCampo(data['string'] ?? '', 'Nascimento:');

        _token = (data['token'] as String?) ?? '';
        _expiresEpoch = (data['expires_at_epoch'] as num?)?.toInt();
        _serverNowEpoch = (data['server_now_epoch'] as num?)?.toInt();
        _loading = false;
      });

      // agenda expurgo
      try {
        await _api.postAction<dynamic>(
          'carteirinha_agendar_expurgo',
          data: {'db_token': data['db_token']},
        );
      } catch (_) {
        // falha no agendamento não deve travar a UI
      }

      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Falha ao emitir token da carteirinha.';
      });
    }
  }

  // Util: a primeira linha do "string" vem com "Titular: NOME" ou "Beneficiário: NOME".
  String? _extrairLinha(String s, int index) {
    final lines = s.split('\n').where((e) => e.trim().isNotEmpty).toList();
    if (index < 0 || index >= lines.length) return null;
    final ln = lines[index];
    final i = ln.indexOf(':');
    return i >= 0 ? ln.substring(i + 1).trim() : ln.trim();
  }

  String? _extrairCampo(String s, String rotulo) {
    for (final ln in s.split('\n')) {
      if (ln.startsWith(rotulo)) {
        return ln.substring(rotulo.length).trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carteirinha Digital'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _CardCarteirinha(
          nome: _nome.toUpperCase(),
          cpf: _cpf,
          matricula: '${widget.idMatricula}',
          sexoTxt: _sexoTxt,
          nascimento: _nascimento,
          token: _token,
          validoAte: _expiresEpoch != null
              ? DateFormat('HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch((_expiresEpoch!) * 1000),
          )
              : '--:--',
          expiraEm: _fmt(_remaining),
        ),
      ),
    );
  }
}

class _CardCarteirinha extends StatelessWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final String validoAte; // HH:mm
  final String expiraEm;  // mm:ss

  const _CardCarteirinha({
    Key? key,
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.nascimento,
    required this.token,
    required this.validoAte,
    required this.expiraEm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFF143C8D);

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [brand.withOpacity(0.92), brand.withOpacity(0.72)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // topo: logo (opcional) + selo "Digital"
            Row(
              children: [
                // se tiver seu asset de logo, descomente:
                // Image.asset('assets/images/icons/logo_ipasem.png', height: 22),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Digital', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              nome,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _kv('CPF', cpf),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _kv('Matrícula', matricula),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _kv('Sexo', sexoTxt)),
                const SizedBox(width: 12),
                Expanded(child: _kv('Nascimento', nascimento ?? '--/--/----')),
              ],
            ),
            const SizedBox(height: 12),

            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white),
                children: [
                  const TextSpan(text: 'Token: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: token, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const TextSpan(text: '   (válido até '),
                  TextSpan(text: validoAte, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: ')   Expira em '),
                  TextSpan(text: expiraEm, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Esta Carteirinha é pessoal e intransferível. Somente tem VALIDADE junto a um documento de identidade com foto - RG. '
                  'Mantenha seu cadastro SEMPRE atualizado.',
              style: TextStyle(color: Colors.white, height: 1.25),
            ),

            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: brand,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Sair'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: '$k: ', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          TextSpan(text: v, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
