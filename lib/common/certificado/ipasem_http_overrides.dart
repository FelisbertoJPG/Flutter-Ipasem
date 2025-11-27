// lib/certificado/ipasem_http_overrides.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class IpasemHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      final allow = host == 'www.ipasemnh.com.br';
      if (kDebugMode) {
        debugPrint(
          '[IpasemHttpOverrides] badCertificateCallback host=$host '
              'port=$port allow=$allow',
        );
      }
      return allow;
    };
    return client;
  }
}
