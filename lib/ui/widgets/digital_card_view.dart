// lib/ui/widgets/digital_card_view.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// Cartão digital do IPASEM com layout responsivo e degradê superior.
///
/// Parâmetros nomeados estáveis:
/// - nome, cpf, matricula, sexoTxt, nascimento (dd/mm/aaaa)
/// - token
/// - expiresAtEpoch (epoch em segundos)
/// - onClose (opcional)
/// - forceLandscape (força sempre horizontal)
/// - forceLandscapeOnWide (força horizontal apenas em telas largas; default: true)
class DigitalCardView extends StatefulWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final int? expiresAtEpoch; // epoch (segundos)
  final VoidCallback? onClose;

  /// Força SEMPRE o layout horizontal (independente da largura).
  final bool forceLandscape;

  /// Mantém o comportamento antigo: força horizontal se a tela for larga.
  final bool forceLandscapeOnWide;

  const DigitalCardView({
    super.key,
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.token,
    this.nascimento,
    this.expiresAtEpoch,
    this.onClose,
    this.forceLandscape = false,
    this.forceLandscapeOnWide = true,
  });

  @override
  State<DigitalCardView> createState() => _DigitalCardViewState();
}

class _DigitalCardViewState extends State<DigitalCardView> {
  static const double _cardRatio = 85.6 / 54.0; // CR80
  late Timer _t;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    _recalcLeft();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _remaining();
    if (next.inSeconds != _left.inSeconds) {
      setState(() => _left = next);
    }
  }

  Duration _remaining() {
    final exp = widget.expiresAtEpoch;
    if (exp == null || exp <= 0) return Duration.zero;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final leftSec = exp - now;
    return Duration(seconds: leftSec.clamp(0, 24 * 3600));
  }

  void _recalcLeft() => _left = _remaining();

  @override
  void didUpdateWidget(covariant DigitalCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAtEpoch != widget.expiresAtEpoch) {
      _recalcLeft();
    }
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  String? _fmtValidoAte() {
    final exp = widget.expiresAtEpoch;
    if (exp == null || exp <= 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    // Base “de design” (antes de escalar/rotacionar).
    const double designWPortrait = 640.0;
    const double designHPortrait = 520.0;
    const double designWLandscape = 980.0;
    const double designHLandscape = 620.0;

    final mq = MediaQuery.of(context);
    final viewport = mq.size;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final availableW = (box.maxWidth.isFinite ? box.maxWidth : viewport.width);
          final availableH = (box.maxHeight.isFinite ? box.maxHeight : viewport.height);

          final isWideByBox = box.maxWidth.isFinite && box.maxWidth >= 420.0;
          final isWideByAspect = availableW >= availableH * 0.9;
          final useLandscape =
              widget.forceLandscape || (widget.forceLandscapeOnWide && (isWideByBox || isWideByAspect));

          final bool viewportIsPortrait = availableH >= availableW;

          // Quando o layout é “landscape” mas a tela está em retrato,
          // tombamos o cartão 90° para reproduzir o efeito do site.
          final bool rotate90 = useLandscape && viewportIsPortrait;

          final double designW = useLandscape ? designWLandscape : designWPortrait;
          final double designH = useLandscape ? designHLandscape : designHPortrait;

          // Slot finito para o FittedBox.
          const outerPad = 16.0;
          final boxW = (availableW - outerPad * 2).clamp(280.0, 1100.0);
          final idealH = useLandscape ? (boxW / _cardRatio) : (availableH * 0.55);
          final boxH = idealH.clamp(260.0, availableH - outerPad * 2);

          final gradient = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF143C8D), Color(0xFF3257B4)],
          );
          final expired = _left.inSeconds <= 0;

          final mqNoTextScale = mq.copyWith(textScaler: const TextScaler.linear(1.0));

          final baseCard = SizedBox(
            width: designW,
            height: designH,
            child: _CardChrome(
              gradient: gradient,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: useLandscape
                    ? _LandscapeContent(
                  nome: widget.nome,
                  cpf: widget.cpf,
                  matricula: widget.matricula,
                  sexoTxt: widget.sexoTxt,
                  nascimento: widget.nascimento,
                  token: widget.token,
                  validoAte: _fmtValidoAte(),
                  expLeft: _left,
                  expired: expired,
                  onClose: widget.onClose,
                )
                    : _PortraitContent(
                  nome: widget.nome,
                  cpf: widget.cpf,
                  matricula: widget.matricula,
                  sexoTxt: widget.sexoTxt,
                  nascimento: widget.nascimento,
                  token: widget.token,
                  validoAte: _fmtValidoAte(),
                  expLeft: _left,
                  expired: expired,
                  onClose: widget.onClose,
                ),
              ),
            ),
          );

          // Invólucro que ajusta as dimensões de layout ao rotacionar,
          // para o FittedBox dimensionar/escala corretamente.
          final Widget cardForFit = rotate90
              ? _RotatedBoxWithBounds(
            width: designW,
            height: designH,
            quarterTurns: 3, // -90°
            child: baseCard,
          )
              : baseCard;

          return Padding(
            padding: const EdgeInsets.all(outerPad),
            child: Center(
              child: SizedBox(
                width: boxW,
                height: boxH,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: MediaQuery(data: mqNoTextScale, child: cardForFit),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Ajusta as dimensões externas quando se rotaciona 90°/180°/270°.
/// Para 90°/270°, a “caixa” externa tem width=heightOriginal e height=widthOriginal.
class _RotatedBoxWithBounds extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final int quarterTurns;

  const _RotatedBoxWithBounds({
    required this.child,
    required this.width,
    required this.height,
    required this.quarterTurns,
  });

  bool get _swap => quarterTurns.isOdd;

  @override
  Widget build(BuildContext context) {
    final outerW = _swap ? height : width;
    final outerH = _swap ? width : height;
    return SizedBox(
      width: outerW,
      height: outerH,
      child: Center(
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }
}

/// Moldura com cantos 20, sombra e “degradê superior”.
class _CardChrome extends StatelessWidget {
  final Widget child;
  final Gradient gradient;

  const _CardChrome({required this.child, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white,
        shadows: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x33000000)),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFF7F8FC)),
            Align(
              alignment: Alignment.topCenter,
              child: Container(height: 64, decoration: BoxDecoration(gradient: gradient)),
            ),
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Container(
                height: 24,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Colors.transparent],
                  ),
                ),
              ),
            ),
            child,
            Positioned(top: 12, right: 12, child: _Chip('Digital')),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x22000000))],
      ),
      child: Text(text, style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
    );
  }
}

class _PortraitContent extends StatelessWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final String? validoAte;
  final Duration expLeft;
  final bool expired;
  final VoidCallback? onClose;

  const _PortraitContent({
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.nascimento,
    required this.token,
    required this.validoAte,
    required this.expLeft,
    required this.expired,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          nome.toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dl('CPF', cpf)),
            const SizedBox(width: 16),
            Expanded(child: _dl('Matrícula', matricula)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _dl('Sexo', sexoTxt)),
            const SizedBox(width: 16),
            Expanded(child: _dl('Nascimento', nascimento ?? '-')),
          ],
        ),
        const SizedBox(height: 12),
        _tokenBlock(token: token, validoAte: validoAte, expLeft: expLeft, expired: expired),
        const Spacer(),
        _disclaimer(maxLines: 3),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF143C8D),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              elevation: 0,
            ),
            child: const Text('Sair'),
          ),
        ),
      ],
    );
  }
}

class _LandscapeContent extends StatelessWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final String? validoAte;
  final Duration expLeft;
  final bool expired;
  final VoidCallback? onClose;

  const _LandscapeContent({
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.nascimento,
    required this.token,
    required this.validoAte,
    required this.expLeft,
    required this.expired,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: .2,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 20,
                  runSpacing: 6,
                  children: [
                    _dl('CPF', cpf),
                    _dl('Matrícula', matricula),
                    _dl('Sexo', sexoTxt),
                    _dl('Nascimento', nascimento ?? '-'),
                  ],
                ),
                const Spacer(),
                _disclaimer(maxLines: 2),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 4),
              _tokenBlock(
                token: token,
                validoAte: validoAte,
                expLeft: expLeft,
                expired: expired,
                alignEnd: true,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF143C8D),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  elevation: 0,
                ),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Helpers visuais ---------------------------------------------------------

Widget _dl(String label, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    ],
  );
}

Widget _tokenBlock({
  required String token,
  required String? validoAte,
  required Duration expLeft,
  required bool expired,
  bool alignEnd = false,
}) {
  if (expired) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE53935),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: const Text(
          'TOKEN EXPIRADO - FECHE E TENTE NOVAMENTE',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  final left = expLeft.inSeconds > 0 ? _fmtLeftStatic(expLeft) : '00:00';
  return Align(
    alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x1A000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.2),
        child: Column(
          crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Token: ', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(token, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 2),
            if (validoAte != null) Text('válido até $validoAte'),
            Text('Expira em $left'),
          ],
        ),
      ),
    ),
  );
}

Widget _disclaimer({int? maxLines}) {
  return Text(
    'Esta Carteirinha é pessoal e intransferível. Somente tem VALIDADE '
        'junto a um documento de identidade com foto - RG. '
        'Mantenha seu cadastro SEMPRE atualizado.',
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.visible,
    style: const TextStyle(fontSize: 12.5, color: Colors.white, height: 1.25),
  );
}

String _fmtLeftStatic(Duration d) {
  final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hh = d.inHours;
  return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
}
