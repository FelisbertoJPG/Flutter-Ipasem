// lib/services/card_token_service.dart
import 'dart:async';

import '../models/card_token_models.dart';
import 'carteirinha_service.dart';

/// Controla vida útil do token: agenda expurgo e publica segundos restantes.
/// Convenções:
/// - Quando não houver expiração, o stream emite -1 e o ticker não roda.
/// - Quando expira, o stream emite 0 e o ticker é parado.
class CardTokenController {
  final CarteirinhaService service;
  final CardTokenData data;

  Timer? _ticker;
  Stopwatch? _sw;             // cronômetro para compensar o tempo
  int? _baseNowEpoch;         // epoch (s) usado como "agora" inicial (preferindo serverNowEpoch)
  bool _expurgoAgendado = false;
  bool _disposed = false;

  final _secondsLeft = StreamController<int>.broadcast();
  Stream<int> get secondsLeftStream => _secondsLeft.stream;

  CardTokenController({required this.service, required this.data});

  void start() {
    if (_disposed) return;

    // Agenda expurgo (best-effort) uma única vez, somente se houver dbToken
    if (!_expurgoAgendado && data.dbToken != null) {
      _expurgoAgendado = true;
      // fire-and-forget
      service.agendarExpurgo(data.dbToken!).catchError((_) {});
    }

    // Sem expiração -> emite -1 e não inicia ticker
    final exp = data.expiresAtEpoch;
    if (exp == null || exp <= 0) {
      _safeAdd(-1);
      return;
    }

    // Define "agora" de referência: usa serverNowEpoch se existir
    _baseNowEpoch = data.serverNowEpoch ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    _sw?.stop();
    _sw = Stopwatch()..start();

    // Emite valor inicial já compensado
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
    final base = _baseNowEpoch ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final elapsed = _sw?.elapsed.inSeconds ?? 0;
    final nowEst = base + elapsed; // "agora" avançado
    final left = exp - nowEst;
    return left <= 0 ? 0 : left;
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _sw?.stop();
    _sw = null;
  }

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
