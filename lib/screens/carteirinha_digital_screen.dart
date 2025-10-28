// lib/screens/carteirinha/carteirinha_digital_screen.dart
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../models/card_token_models.dart';
import '../../services/card_token_service.dart';
import '../../ui/widgets/digital_card_view.dart';

/// Screen “fina” que emite o token e renderiza o widget do card.
/// Use em rotas internas: 'carteirinha-digital'
class CarteirinhaDigitalScreen extends StatefulWidget {
  final int idMatricula;
  final int idDependente;

  const CarteirinhaDigitalScreen({
    super.key,
    required this.idMatricula,
    this.idDependente = 0,
  });

  @override
  State<CarteirinhaDigitalScreen> createState() => _CarteirinhaDigitalScreenState();
}

class _CarteirinhaDigitalScreenState extends State<CarteirinhaDigitalScreen> {
  final _service = CardTokenService(dio: Dio());
  CardTokenResponse? _card;
  String? _err;

  @override
  void initState() {
    super.initState();
    _emit();
  }

  Future<void> _emit() async {
    setState(() => _err = null);
    try {
      final resp = await _service.issueCardToken(
        matricula: widget.idMatricula,
        idDependente: widget.idDependente,
        generateOnClient: true, // cliente sugere token; backend valida/persiste
      );
      if (!mounted) return;
      setState(() => _card = resp);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_card != null) {
      return DigitalCardView(card: _card!, service: _service);
    }
    if (_err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carteirinha Digital')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Erro ao emitir:\n$_err', textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _emit, child: const Text('Tentar novamente')),
          ]),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
