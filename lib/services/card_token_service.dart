// lib/services/card_token_service.dart
import 'dart:async';

import '../models/card_token_models.dart';
import 'carteirinha_service.dart';

/// Orquestra a vida útil do token (contador e expurgo).
class CardTokenController {
  final CarteirinhaService service;
  final CardTokenData data;

  Timer? _ticker;
  final _secondsLeft = StreamController<int>.broadcast();
  bool _expurgoAgendado = false;

  Stream<int> get secondsLeftStream => _secondsLeft.stream;

  CardTokenController({required this.service, required this.data});

  void start() {
    // agenda expurgo uma única vez
    if (!_expurgoAgendado) {
      _expurgoAgendado = true;
      // fire-and-forget; erros não quebram a UI
      service.agendarExpurgo(data.dbToken).catchError((_) {});
    }

    // dispara primeiro valor já compensado
    var left = data.secondsLeft();
    _secondsLeft.add(left);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      left -= 1;
      if (left <= 0) {
        _secondsLeft.add(0);
        stop();
      } else {
        _secondsLeft.add(left);
      }
    });
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void dispose() {
    stop();
    _secondsLeft.close();
  }
}
