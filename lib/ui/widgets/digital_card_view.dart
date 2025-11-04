// lib/ui/widgets/digital_card_view.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';

import '../../services/carteirinha_service.dart';

/// Cartão digital do IPASEM com layout responsivo.
/// Conteúdo DENTRO do card: Nome, CPF, Sexo, Matrícula, Nascimento, Token
/// (ou tarja de expirado) e texto institucional (seção separada).
class DigitalCardView extends StatefulWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;

  /// db_token retornado na emissão. Usado para agendar/invalidar no backend.
  final int? dbToken;

  /// Expiração em EPOCH **segundos** (do backend).
  final int? expiresAtEpoch;

  /// Epoch **segundos** que o servidor reportou como "agora" no momento da emissão.
  /// Quando presente, o contador usa (server_now + elapsed) em vez do relógio do aparelho.
  final int? serverNowEpoch;

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
    this.dbToken,
    this.nascimento,
    this.expiresAtEpoch,
    this.serverNowEpoch,
    this.onClose,
    this.forceLandscape = false,
    this.forceLandscapeOnWide = true,
  });

  @override
  State<DigitalCardView> createState() => _DigitalCardViewState();
}

class _DigitalCardViewState extends State<DigitalCardView> {
  // ====== GAPS AJUSTÁVEIS ====================================================
  static const double kGapNameToGrid = 30;        // Nome -> CPF/Matrícula
  static const double kGapBetweenGridRows = 20;   // Linha 1 -> Linha 2 da grade
  static const double kGapGridToToken = 30;       // (Sexo/Nasc) -> Token
  static const double kGapTokenToText = 40;       // Token -> Texto institucional
  static const Color kAlertColor = Color(0xFFFFB300); // âmbar (alerta)

  // ====== FONTES AJUSTÁVEIS ==================================================
  static const double kNameFont = 36;
  static const double kLabelFont = 16;
  static const double kValueFont = 22;
  static const double kTokenFont = 25;
  static const double kTokenExpiredFont = 20;
  static const double kDisclaimerFont = 26;

  // ====== TAMANHO/INSETS DO CARD ============================================
  static const double _cardRatio = 85.6 / 54.0;   // CR80
  static const double _headerHeight = 70.0;       // faixa decorativa
  static const EdgeInsets _cardBodyInsets =
  EdgeInsets.fromLTRB(24, _headerHeight + 10, 24, 24);

  late final Stopwatch _sw = Stopwatch()..start();
  late Timer _t;

  // Usamos -1 para “desconhecido/sem expiração”.
  int _leftSec = -1;

  // Controle de chamadas únicas.
  int? _expurgoAgendadoPara;   // lembra qual dbToken já agendou
  bool _excluiuViaApp = false; // garante exclusão única ao expirar/fechar

  @override
  void initState() {
    super.initState();
    _recalcLeft();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    // Agenda expurgo após o primeiro frame exibindo o cartão.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAgendarExpurgoOnce();
    });
  }

  @override
  void didUpdateWidget(covariant DigitalCardView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recalcula contagem quando backend reportar novos tempos.
    if (oldWidget.expiresAtEpoch != widget.expiresAtEpoch ||
        oldWidget.serverNowEpoch != widget.serverNowEpoch) {
      _sw
        ..reset()
        ..start();
      _recalcLeft();
    }

    // Se mudou o dbToken, tente agendar para o novo token.
    if (oldWidget.dbToken != widget.dbToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryAgendarExpurgoOnce();
      });
    }
  }

  @override
  void dispose() {
    _t.cancel();

    // Se por algum motivo estiver expirado e ainda não excluímos, tenta excluir.
    if (_leftSec == 0) {
      _tryExcluirOnExpireOnce();
    }

    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final next = _computeLeftSeconds();
    if (next != _leftSec) {
      setState(() => _leftSec = next);

      // Quando o contador chega em 0 (e há expiração definida), dispare exclusão imediata via app.
      if (next == 0 && widget.expiresAtEpoch != null && widget.expiresAtEpoch! > 0) {
        _tryExcluirOnExpireOnce();
      }
    }
  }

  void _recalcLeft() {
    _leftSec = _computeLeftSeconds();
  }

  /// Calcula segundos restantes sem depender do relógio do aparelho
  /// quando serverNowEpoch estiver disponível.
  int _computeLeftSeconds() {
    final exp = widget.expiresAtEpoch;
    if (exp == null || exp <= 0) return -1; // sem expiração -> não expira na UI

    final baseNow =
        widget.serverNowEpoch ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    // avança “agora” do servidor pelo tempo decorrido localmente
    final nowEst = baseNow + _sw.elapsed.inSeconds;
    final left = exp - nowEst;
    // clamp apenas inferior (não travar em 24h artificialmente)
    return left < 0 ? 0 : left;
  }

  String? _fmtValidoAte() {
    final exp = widget.expiresAtEpoch;
    if (exp == null || exp <= 0) return null;
    final dt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Agenda expurgo do token **apenas uma vez por dbToken** (best-effort no backend).
  void _tryAgendarExpurgoOnce() async {
    final token = widget.dbToken;
    if (!mounted || token == null || token <= 0) return;
    if (_expurgoAgendadoPara == token) return; // já foi para este token

    _expurgoAgendadoPara = token;
    try {
      await CarteirinhaService.fromContext(context).agendarExpurgo(token);
      debugPrint('DigitalCardView: agendarExpurgo OK (db_token=$token)');
    } catch (e) {
      // Não quebra a UI; apenas loga.
      debugPrint('DigitalCardView: agendarExpurgo falhou: $e');
    }
  }

  /// Tenta excluir o token no backend quando a contagem zera (uma única vez).
  void _tryExcluirOnExpireOnce() async {
    if (_excluiuViaApp) return;
    _excluiuViaApp = true;

    final token = widget.dbToken;
    if (token == null || token <= 0) return;

    try {
      await CarteirinhaService.fromContext(context)
          .excluirToken(dbToken: token);
      debugPrint('DigitalCardView: excluirToken OK (db_token=$token)');
    } catch (e) {
      debugPrint('DigitalCardView: excluirToken falhou: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tamanhos de design (antes de escalar/rotacionar).
    const double designWPortrait = 640.0;
    const double designHPortrait = 520.0;
    const double designWLandscape = 980.0;
    const double designHLandscape = 620.0;

    final mq = MediaQuery.of(context);
    final viewport = mq.size;

    final hasExpiry = widget.expiresAtEpoch != null && widget.expiresAtEpoch! > 0;
    // Regra: só mostra “EXPIRADO” quando há expiração definida.
    final expired = hasExpiry && _leftSec == 0;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final availableW =
          (box.maxWidth.isFinite ? box.maxWidth : viewport.width);
          final availableH =
          (box.maxHeight.isFinite ? box.maxHeight : viewport.height);

          final isWideByBox = box.maxWidth.isFinite && box.maxWidth >= 420.0;
          final isWideByAspect = availableW >= availableH * 0.9;
          final useLandscape = widget.forceLandscape ||
              (widget.forceLandscapeOnWide && (isWideByBox || isWideByAspect));

          final bool viewportIsPortrait = availableH >= availableW;
          final bool rotate90 = useLandscape && viewportIsPortrait;

          final double designW =
          useLandscape ? designWLandscape : designWPortrait;
          final double designH =
          useLandscape ? designHLandscape : designHPortrait;

          // Slot para o FittedBox — card maior e mais para cima.
          const double padX = 0.0; // sem margens laterais
          const double padTop = 0.0; // cola no topo
          const double padBottomExtra = 36; // folga mínima p/ bottom bar

          final slotW = (availableW - padX * 2).clamp(280.0, 4000.0);
          final double slotH;
          if (rotate90) {
            slotH = (availableH - padTop - padBottomExtra)
                .clamp(280.0, availableH - padTop - padBottomExtra);
          } else {
            final idealH =
            useLandscape ? (slotW / _cardRatio) : (availableH * 0.98);
            slotH = idealH.clamp(260.0, availableH - padTop - padBottomExtra);
          }

          final baseCard = SizedBox(
            width: designW,
            height: designH,
            child: _CardChrome(
              child: Padding(
                padding: _cardBodyInsets,
                child: _CardSections(
                  nome: widget.nome,
                  cpf: widget.cpf,
                  matricula: widget.matricula,
                  sexoTxt: widget.sexoTxt,
                  nascimento: widget.nascimento,
                  token: widget.token,
                  validoAte: _fmtValidoAte(),
                  // Quando _leftSec == -1: sem contador (não mostra “Expira em …”)
                  leftSeconds: _leftSec >= 0 ? _leftSec : null,
                  expired: expired,
                  onClose: widget.onClose,
                ),
              ),
            ),
          );

          final mqNoTextScale =
          mq.copyWith(textScaler: const TextScaler.linear(1.0));
          final Widget cardForFit = rotate90
              ? _RotatedBoxWithBounds(
            width: designW,
            height: designH,
            quarterTurns: 3, // -90°
            child: baseCard,
          )
              : baseCard;

          return Padding(
            padding:
            const EdgeInsets.fromLTRB(padX, padTop, padX, padBottomExtra),
            child: Align(
              alignment: const Alignment(0, -0.94),
              child: SizedBox(
                width: slotW,
                height: slotH,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
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

/// Moldura com cantos 20, sombra e faixa superior apenas decorativa.
class _CardChrome extends StatelessWidget {
  final Widget child;
  const _CardChrome({required this.child});

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF143C8D), Color(0xFF3257B4)],
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white,
        shadows: const [
          BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x33000000))
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
              child: Container(
                height: _DigitalCardViewState._headerHeight,
                decoration: const BoxDecoration(gradient: gradient),
              ),
            ),
            const Positioned(
              top: _DigitalCardViewState._headerHeight - 4,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22000000), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            child,
            const Positioned(top: 12, right: 12, child: _Chip('Digital')),
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
        boxShadow: const [
          BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x22000000))
        ],
      ),
      child: Text(text,
          style: TextStyle(color: c.primary, fontWeight: FontWeight.w700)),
    );
  }
}

/// Seções internas: Cabeçalho/Grade/Token **e** Texto institucional.
/// Botão "Sair" fixo no rodapé do corpo do card.
class _CardSections extends StatelessWidget {
  final String nome;
  final String cpf;
  final String matricula;
  final String sexoTxt;
  final String? nascimento;
  final String token;
  final String? validoAte;

  /// Null = sem contador (“Expira em …” oculto).
  final int? leftSeconds;

  final bool expired;
  final VoidCallback? onClose;

  const _CardSections({
    required this.nome,
    required this.cpf,
    required this.matricula,
    required this.sexoTxt,
    required this.nascimento,
    required this.token,
    required this.validoAte,
    required this.leftSeconds,
    required this.expired,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // ======= SEÇÃO A: Cabeçalho (Nome) + Grade =======
    final topInfo = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nome.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              fontSize: _DigitalCardViewState.kNameFont,
              height: 1.04,
            ),
          ),
          SizedBox(height: _DigitalCardViewState.kGapNameToGrid),
          Table(
            columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              TableRow(children: [
                _dl('CPF', cpf, _DigitalCardViewState.kLabelFont,
                    _DigitalCardViewState.kValueFont),
                _dl('Matrícula', matricula, _DigitalCardViewState.kLabelFont,
                    _DigitalCardViewState.kValueFont),
              ]),
              const TableRow(children: [
                SizedBox(height: _DigitalCardViewState.kGapBetweenGridRows),
                SizedBox(height: _DigitalCardViewState.kGapBetweenGridRows),
              ]),
              TableRow(children: [
                _dl('Sexo', sexoTxt.toUpperCase(),
                    _DigitalCardViewState.kLabelFont,
                    _DigitalCardViewState.kValueFont),
                _dl(
                    'Nascimento',
                    (nascimento ?? '-'),
                    _DigitalCardViewState.kLabelFont,
                    _DigitalCardViewState.kValueFont),
              ]),
            ],
          ),
        ],
      ),
    );

    // ======= SEÇÃO B: Token (com gap vindo da grade) =======
    final tokenSection = Padding(
      padding: EdgeInsets.only(top: _DigitalCardViewState.kGapGridToToken),
      child: expired
          ? _tokenExpiredPill()
          : _tokenLine(
          token: token, validoAte: validoAte, leftSeconds: leftSeconds),
    );

    // ======= SEÇÃO C: Texto institucional =======
    final disclaimerSection = Padding(
      padding: EdgeInsets.only(top: _DigitalCardViewState.kGapTokenToText),
      child: _disclaimerBig(),
    );

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                topInfo,
                tokenSection,
                disclaimerSection,
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF143C8D),
              shape: const StadiumBorder(),
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
            ),
            child: const Text('Sair'),
          ),
        ),
      ],
    );
  }
}

// --- Helpers visuais ---------------------------------------------------------

Widget _dl(String label, String value, double labelSize, double valueSize) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: labelSize, color: Colors.black45)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: valueSize,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
          height: 1.04,
        ),
      ),
    ],
  );
}

Widget _tokenExpiredPill() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFE53935),
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))
      ],
    ),
    child: Text(
      'TOKEN EXPIRADO - FECHE E TENTE NOVAMENTE',
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: _DigitalCardViewState.kTokenExpiredFont,
      ),
    ),
  );
}

Widget _tokenLine({
  required String token,
  required String? validoAte,
  required int? leftSeconds,
}) {
  String fmtLeft(int s) {
    final d = Duration(seconds: s);
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2))
      ],
    ),
    child: DefaultTextStyle(
      style: TextStyle(
          color: Colors.black87,
          fontSize: _DigitalCardViewState.kTokenFont,
          height: 1.24),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 2,
        children: [
          const Text('Token:', style: TextStyle(fontWeight: FontWeight.w600)),
          Text(token, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (validoAte != null) Text('(válido até $validoAte)'),
          if (leftSeconds != null) Text('Expira em ${fmtLeft(leftSeconds)}'),
        ],
      ),
    ),
  );
}

Widget _disclaimerBig() {
  const base = TextStyle(
    fontSize: _DigitalCardViewState.kDisclaimerFont,
    height: 1.35,
    color: Colors.black87,
  );
  const alert = TextStyle(
    fontSize: _DigitalCardViewState.kDisclaimerFont,
    height: 1.35,
    color: _DigitalCardViewState.kAlertColor,
    fontWeight: FontWeight.w700,
  );
  const alertStrong = TextStyle(
    fontSize: _DigitalCardViewState.kDisclaimerFont,
    height: 1.35,
    color: _DigitalCardViewState.kAlertColor,
    fontWeight: FontWeight.w900,
  );

  return Text.rich(
    const TextSpan(
      children: [
        TextSpan(
          text:
          'Esta Carteirinha é pessoal e intransferível. Somente tem VALIDADE '
              'junto a um documento de identidade com foto - RG.\n',
          style: base,
        ),
        TextSpan(text: 'Mantenha seu cadastro ', style: alert),
        TextSpan(text: 'SEMPRE ', style: alertStrong),
        TextSpan(text: 'atualizado.', style: alert),
      ],
    ),
  );
}
