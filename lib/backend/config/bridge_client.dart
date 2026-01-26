// lib/core/bridge_client.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

String _b64HmacSha256(List<int> key, List<int> data) {
  final h = Hmac(sha256, key);
  final d = h.convert(data).bytes;
  return base64Encode(d);
}

/// Assina e envia um POST para a URL do bridge (ex.: http://host/bridge-api-dev?action=login_repo)
Future<Response<dynamic>> postSigned({
  required Dio dio,
  required Uri url,         // inclua ?action=...
  required String apiKey,   // mesma chave guardada no servidor
  required String secret,   // pode ser igual ou diferente
  Map<String, dynamic>? body,
}) async {
  final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final nonce = const Uuid().v4(); // <- aqui
  const method = 'POST';
  final path = url.path; // ex.: "/bridge-api-dev"

  final payload = utf8.encode(jsonEncode(body ?? const {}));
  final bodyHash = sha256.convert(payload).bytes;

  final base = <int>[]
    ..addAll(utf8.encode('$method|$path|$ts|$nonce|'))
    ..addAll(bodyHash);

  final sign = _b64HmacSha256(utf8.encode(secret), base);

  return dio.postUri(
    url,
    data: body,
    options: Options(headers: {
      'Content-Type': 'application/json',
      'X-API-Key': apiKey,
      'X-API-Timestamp': ts.toString(),
      'X-API-Nonce': nonce,
      'X-API-Sign': sign,
    }),
  );
}
