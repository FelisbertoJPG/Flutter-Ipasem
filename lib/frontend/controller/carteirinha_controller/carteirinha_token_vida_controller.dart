// lib/ui/controllers/vida_token_controller.dart
import 'dart:async';

import '../../../common/models/card_token.dart';
import '../../../common/services/carterinha_service/carteirinha_service.dart';

/// Controla a "vida útil" de um token de carteirinha para a UI:
/// - Agenda expurgo no backend (best-effort).
/// - Publica no stream os segundos restantes até expirar.
///   - -1  => sem expiração conhecida.
///   - >0  => segundos restantes.
///   - 0   => expirado (ticker para).
///
/// Uso típico na UI:
/// final controller = VidaTokenController(service: svc, data: tokenData);
/// controller.start();
/// controller.secondsLeftStream.listen(...);
/// ...
/// controller.dispose();
class VidaTokenController {
  final CarteirinhaService service;
  final CardTokenData data;

  Timer? _ticker;
  Stopwatch? _sw; // cronômetro para compensar o tempo
  int? _baseNowEpoch; // epoch (s) usado como "agora" inicial
  bool _expurgoAgendado = false;
  bool _disposed = false;

  final _secondsLeft = StreamController<int>.broadcast();
  Stream<int> get secondsLeftStream => _secondsLeft.stream;

  VidaTokenController({
    required this.service,
    required this.data,
  });

  /// Inicia o controle:
  /// - agenda o expurgo (se houver dbToken);
  /// - começa a emitir segundos restantes enquanto houver expiração.
  void start() {
    if (_disposed) return;

    // Agenda expurgo (best-effort) uma única vez, somente se houver dbToken.
    if (!_expurgoAgendado && data.dbToken != null) {
      _expurgoAgendado = true;
      // fire-and-forget
      service.agendarExpurgo(data.dbToken!).catchError((_) {});
    }

    final exp = data.expiresAtEpoch;
    // Sem expiração -> emite -1 e não inicia ticker.
    if (exp == null || exp <= 0) {
      _safeAdd(-1);
      return;
    }

    // Define "agora" de referência: usa serverNowEpoch se existir.
    _baseNowEpoch =
        data.serverNowEpoch ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    _sw?.stop();
    _sw = Stopwatch()..start();

    // Emite valor inicial já compensado.
    _safeAdd(_computeLeft());

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _computeLeft();
      _safeAdd(left);
      if (left <= 0) {
        stop(); // encerra no zero
      }
    });
  }

  /// Recalcula segundos restantes a cada tick com base no relógio do servidor.
  int _computeLeft() {
    final exp = data.expiresAtEpoch!;
    final base = _baseNowEpoch ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final elapsed = _sw?.elapsed.inSeconds ?? 0;
    final nowEst = base + elapsed; // "agora" avançado
    final left = exp - nowEst;
    return left <= 0 ? 0 : left;
  }

  /// Para o ticker (não fecha o stream).
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _sw?.stop();
    _sw = null;
  }

  /// Libera recursos: para o ticker e fecha o stream.
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
    _secondsLeft.close();
  }

  void _safeAdd(int v) {
    if (_disposed) return;
    try {
      _secondsLeft.add(v);
    } catch (_) {
      // ignora se stream já foi fechada
    }
  }
}
