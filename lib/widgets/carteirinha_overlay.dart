import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';       // UserProfile, Dep, ApiService
import 'digital_card.dart';                 // seu widget do cartão digital

/// Função helper para exibir o overlay e permitir fechar
Future<void> showCarteirinhaOverlay(
    BuildContext context, {
      required ApiService api,
    }) async {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => CarteirinhaOverlay(
      api: api,
      onClose: () => entry.remove(),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
}

class CarteirinhaOverlay extends StatefulWidget {
  final ApiService api;
  final VoidCallback onClose;

  const CarteirinhaOverlay({
    super.key,
    required this.api,
    required this.onClose,
  });

  @override
  State<CarteirinhaOverlay> createState() => _CarteirinhaOverlayState();
}

class _CarteirinhaOverlayState extends State<CarteirinhaOverlay> {
  Future<(UserProfile, List<Dep>)>? _future;

  static const _brandBlue = Color(0xFF143C8D);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(UserProfile, List<Dep>)> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token_login');
    if (token == null || token.isEmpty) {
      throw Exception('Faça login pelo app para carregar a carteirinha.');
    }
    return widget.api.fetchCarteirinha(tokenLogin: token);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cardWidth = w * 0.92;
    final cardMaxWidth = cardWidth > 420 ? 420.0 : cardWidth;

    return Material(
      color: Colors.black38,
      child: Center(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          tween: Tween(begin: .95, end: 1),
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // CARTÃO
              Container(
                width: cardMaxWidth,
                constraints: const BoxConstraints(maxHeight: 560),
                padding: const EdgeInsets.fromLTRB(16, 44, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(blurRadius: 20, color: Colors.black26, offset: Offset(0, 10)),
                  ],
                ),
                child: FutureBuilder<(UserProfile, List<Dep>)>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const _LoadingContent();
                    }
                    if (snap.hasError) {
                      return _ErrorContent(
                        message: '${snap.error}',
                        onClose: widget.onClose,
                      );
                    }

                    final (user, deps) = snap.data!;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Título “Minha carteirinha”
                        const Text(
                          'Minha carteirinha',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 12),

                        // Titular
                        DigitalCard(
                          nome: user.nome,
                          cpf: user.cpf,
                          matricula: user.matricula,
                          plano: user.plano,
                          validade: user.validade,
                        ),

                        const SizedBox(height: 12),

                        // Dependentes (rolável se tiver vários)
                        if (deps.isNotEmpty)
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              itemCount: deps.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final d = deps[i];
                                return DigitalCard(
                                  nome: d.nome,
                                  cpf: d.cpf,
                                  matricula: user.matricula,
                                  plano: user.plano,
                                  validade: user.validade,
                                );
                              },
                            ),
                          ),
                        if (deps.isEmpty) const SizedBox(height: 4),

                        const SizedBox(height: 8),
                        // Botão fechar
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: widget.onClose,
                            icon: const Icon(Icons.close),
                            label: const Text('Fechar'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // BADGE menor (estilo do seu alert) no topo do cartão
              Positioned(
                top: -20,
                left: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 20,                    // <= badge menor
                  backgroundColor: _brandBlue,
                  child: const Icon(Icons.badge_outlined, color: Colors.white, size: 18),
                ),
              ),

              // Botão “X” flutuante (canto superior direito do cartão)
              Positioned(
                top: -8,
                right: -8,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                    tooltip: 'Fechar',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 36, width: 36, child: CircularProgressIndicator(strokeWidth: 4)),
          SizedBox(height: 12),
          Text('Carregando carteirinha...'),
        ],
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final String message;
  final VoidCallback onClose;

  const _ErrorContent({super.key, required this.message, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onClose, child: const Text('Fechar')),
        ],
      ),
    );
  }
}
