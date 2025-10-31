// lib/screens/carteirinha_digital_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_router.dart';
import '../services/dev_api.dart';
import '../ui/widgets/digital_card_view.dart';

class CarteirinhaDigitalScreen extends StatefulWidget {
  final int idMatricula;
  final int idDependente; // 0 = titular
  final String? nomeTitular;

  const CarteirinhaDigitalScreen({
    Key? key,
    required this.idMatricula,
    this.idDependente = 0,
    this.nomeTitular,
  }) : super(key: key);

  @override
  State<CarteirinhaDigitalScreen> createState() => _CarteirinhaDigitalScreenState();
}

class _CarteirinhaDigitalScreenState extends State<CarteirinhaDigitalScreen> {
  late final DevApi _api = ApiRouter.client();

  bool _loading = true;
  String? _error;

  // dados do cartão
  String _nome = '';
  String _cpf = '';
  String _sexoTxt = '';
  String? _nascimento; // dd/MM/yyyy
  String _token = '';
  int? _expiresEpoch; // epoch (segundos)

  @override
  void initState() {
    super.initState();
    _emitirECarregar();
  }

  Future<void> _emitirECarregar() async {
    _setBusy();

    try {
      // ---------- 1) Tenta carteirinha_emitir ----------
      Map<String, dynamic>? data = await _tryEmitir();

      // ---------- 2) Fallback: carteirinha_pessoa ----------
      data ??= await _tryPessoa();

      if (data == null) {
        throw Exception('Falha na emissão do token.');
      }

      // Preenche UI
      final parsed = _Parsed.fromEither(data, fallbackNome: widget.nomeTitular);
      _setReady(() {
        _nome        = parsed.nome?.trim() ?? '';
        _cpf         = parsed.cpf ?? '';
        _sexoTxt     = parsed.sexoTxt ?? '';
        _nascimento  = parsed.nascimento;
        _token       = parsed.token ?? '';
        _expiresEpoch= parsed.expiresEpoch;
      });

      // ---------- 3) Agenda expurgo (best-effort) ----------
      try {
        final dbToken = _asInt(data['db_token']);
        if (dbToken != null) {
          await _api.postAction<dynamic>(
            'carteirinha_agendar_expurgo',
            data: {'db_token': dbToken},
          );
        }
      } catch (_) {/* silencioso */}
    } catch (e) {
      _setError('Falha ao emitir token da carteirinha.');
    }
  }

  // Tenta o endpoint novo (ou usado no seu fluxo modal)
  Future<Map<String, dynamic>?> _tryEmitir() async {
    try {
      final res = await _api.postAction<dynamic>(
        'carteirinha_emitir',
        data: {
          // Envia ambos para compatibilidade entre gateways
          'idmatricula': widget.idMatricula,
          'matricula': widget.idMatricula,
          'iddependente': widget.idDependente,
        },
      );
      final m = (res.data as Map).cast<String, dynamic>();
      if (m['ok'] == true && m['data'] is Map) {
        final data = (m['data'] as Map).cast<String, dynamic>();
        // Considera sucesso se veio token ou db_token ou string
        if ((data['token'] ?? '').toString().isNotEmpty ||
            (data['db_token'] != null) ||
            (data['string'] ?? '').toString().isNotEmpty) {
          return data;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Tenta o endpoint legado que você usou nos logs
  Future<Map<String, dynamic>?> _tryPessoa() async {
    try {
      final res = await _api.postAction<dynamic>(
        'carteirinha_pessoa',
        data: {
          'matricula': widget.idMatricula,
          'iddependente': widget.idDependente,
        },
      );
      final m = (res.data as Map).cast<String, dynamic>();
      if (m['ok'] == true && m['data'] is Map) {
        return (m['data'] as Map).cast<String, dynamic>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Carteirinha Digital')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _emitirECarregar,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: DigitalCardView(
            forceLandscape: true, // força horizontal
            nome: _nome.toUpperCase(),
            cpf: _cpf,
            matricula: '${widget.idMatricula}-${widget.idDependente}',
            sexoTxt: _sexoTxt,
            nascimento: _nascimento,
            token: _token,
            expiresAtEpoch: _expiresEpoch,
            onClose: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
    );
  }

  // ---------------- helpers ----------------

  void _setBusy() {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
  }

  void _setReady(void Function() apply) {
    if (!mounted) return;
    setState(() {
      apply();
      _loading = false;
      _error = null;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// Parser compatível com os dois formatos de resposta.
/// - Se vier "data.string", extrai linhas (Titular, CPF, Sexo, Nascimento)
/// - Se vierem campos soltos, usa-os diretamente.
/// - Também coleta token e expires_at_epoch quando existirem.
class _Parsed {
  final String? nome;
  final String? cpf;
  final String? sexoTxt;
  final String? nascimento;
  final String? token;
  final int? expiresEpoch;

  const _Parsed({this.nome, this.cpf, this.sexoTxt, this.nascimento, this.token, this.expiresEpoch});

  factory _Parsed.fromEither(Map<String, dynamic> data, {String? fallbackNome}) {
    String? nome, cpf, sexo, nasc, token;
    int? exp;

    token = (data['token'] ?? '').toString();
    exp   = _asInt(data['expires_at_epoch']);

    // 1) Se vierem campos diretos
    nome = (data['nome'] ?? fallbackNome)?.toString();
    cpf  = data['cpf']?.toString();
    sexo = data['sexo_txt']?.toString();
    nasc = _fmtBrSafe(data['nascimento']?.toString());

    // 2) Se vier "string", parseia e sobrescreve o que faltar
    final s = data['string']?.toString();
    if (s != null && s.isNotEmpty) {
      final p = _fromBackendString(s);
      nome ??= p.nome ?? fallbackNome;
      cpf  ??= p.cpf;
      sexo ??= p.sexoTxt;
      nasc ??= p.nascimento;
    }

    return _Parsed(
      nome: nome ?? fallbackNome,
      cpf: cpf,
      sexoTxt: sexo,
      nascimento: nasc,
      token: token?.isNotEmpty == true ? token : null,
      expiresEpoch: exp,
    );
  }

  // ---------- helpers ----------
  static _Parsed _fromBackendString(String s) {
    String? nome, cpf, sexo, nasc;
    for (final raw in s.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('Titular:')) {
        nome = line.replaceFirst('Titular:', '').trim();
        continue;
      }
      if (line.startsWith('Beneficiário:')) {
        nome = line.replaceFirst('Beneficiário:', '').trim();
        continue;
      }
      if (line.startsWith('CPF:')) {
        cpf = line.replaceFirst('CPF:', '').trim();
        continue;
      }
      if (line.startsWith('Sexo:')) {
        sexo = line.replaceFirst('Sexo:', '').trim();
        continue;
      }
      if (line.startsWith('Nascimento:')) {
        final v = line.replaceFirst('Nascimento:', '').trim();
        nasc = _fmtBrSafe(v);
        continue;
      }
    }
    return _Parsed(nome: nome, cpf: cpf, sexoTxt: sexo, nascimento: nasc);
  }

  static String? _fmtBrSafe(String? v) {
    if (v == null || v.isEmpty) return v;
    DateTime? dt;
    final mBr = RegExp(r'^(\d{2})[\/-](\d{2})[\/-](\d{4})$').firstMatch(v);
    if (mBr != null) {
      dt = DateTime(
        int.parse(mBr.group(3)!),
        int.parse(mBr.group(2)!),
        int.parse(mBr.group(1)!),
      );
    } else {
      dt = DateTime.tryParse(v);
    }
    if (dt == null) return v;
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
