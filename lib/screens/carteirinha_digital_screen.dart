// lib/screens/carteirinha_digital_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../services/dev_api.dart';
import '../ui/widgets/digital_card_view.dart';

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
  // --- API base resolution ---
  // 1) Usa a API passada pelo caller (widget.api)
  // 2) Senão, usa AppConfig(params.baseApiUrl) do app em execução (main ou main_local)
  // 3) Senão, cai no env var/API_BASE com default PRODUCTION
  late final DevApi _api;
  bool _bootstrapped = false;

  static String _resolveBaseApi(BuildContext ctx) {
    final cfg = AppConfig.maybeOf(ctx);
    if (cfg != null && cfg.params.baseApiUrl.isNotEmpty) {
      return cfg.params.baseApiUrl;
    }
    // Default sempre PROD; o main_local já injeta o host .98 em AppConfig.
    return const String.fromEnvironment(
      'API_BASE',
      defaultValue: 'https://assistweb.ipasemnh.com.br',
    );
  }

  // --- UI state ---
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;

    _api = widget.api ?? DevApi(_resolveBaseApi(context));
    _bootstrapped = true;

    _emitirECarregar();
  }

  Future<void> _emitirECarregar() async {
    _setBusy();

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
      final info = _Parsed.fromBackendString(data['string'] as String?);

      _setReady(() {
        _nome = (info.nome ?? widget.nomeTitular ?? '').trim();
        _cpf = info.cpf ?? '';
        _sexoTxt = info.sexoTxt ?? '';
        _nascimento = info.nascimento; // já em dd/MM/yyyy
        _token = (data['token'] ?? '').toString();
        _expiresEpoch = _asInt(data['expires_at_epoch']);
      });

      // agenda expurgo (best-effort, não bloqueia a UI)
      try {
        final dbToken = _asInt(data['db_token']);
        if (dbToken != null) {
          await _api.postAction<dynamic>(
            'carteirinha_agendar_expurgo',
            data: {'db_token': dbToken},
          );
        }
      } catch (_) {/* silencioso */}
    } catch (_) {
      _setError('Falha ao emitir token da carteirinha.');
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
            matricula: '${widget.idMatricula}',
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

/// Parser simples do campo "string" devolvido pelo backend.
class _Parsed {
  final String? nome;
  final String? cpf;
  final String? sexoTxt;
  final String? nascimento;

  const _Parsed({this.nome, this.cpf, this.sexoTxt, this.nascimento});

  factory _Parsed.fromBackendString(String? s) {
    if (s == null || s.isEmpty) return const _Parsed();
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
        nasc = _fmtBr(v);
        continue;
      }
    }
    return _Parsed(nome: nome, cpf: cpf, sexoTxt: sexo, nascimento: nasc);
  }

  static String? _fmtBr(String v) {
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
}
