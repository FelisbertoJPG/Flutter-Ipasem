// lib/services/notifier.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Serviço único para notificações locais.
class AppNotifier {
  AppNotifier._();
  static final AppNotifier I = AppNotifier._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Canal padrão (Android)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'app_default_channel',
    'Notificações',
    description: 'Alertas do aplicativo',
    importance: Importance.high,
    playSound: true,
  );

  /// Inicializa o plugin e garante permissão (Android 13+/iOS/macOS).
  Future<void> init() async {
    if (_initialized) return;

    // 1) Pede permissão de forma cross-platform
    await _ensurePermission();

    // 2) Inicialização por plataforma
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const darwinInit = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        // TODO: tratar clique (payload) se quiser
      },
    );

    // 3) Cria canal no Android
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    _initialized = true;
  }

  /// Solicita/garante permissão usando `permission_handler`.
  Future<void> _ensurePermission() async {
    if (kIsWeb) return; // web não usa este serviço

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  /// Notificação simples (heads-up no Android).
  Future<void> showSimple({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!_initialized) await init();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/launcher_icon',
      ),
      iOS: const DarwinNotificationDetails(presentSound: true),
      macOS: const DarwinNotificationDetails(presentSound: true),
    );

    final notifId =
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _plugin.show(notifId, title, body, details, payload: payload);
  }

  /// Azulejo pronto para “exame liberado”.
  Future<void> notifyExameLiberado({
    required int numero,
    String? paciente,
    String? prestador,
  }) {
    final parts = <String>[
      'Exame nº $numero',
      if ((paciente ?? '').isNotEmpty) '• $paciente',
      if ((prestador ?? '').isNotEmpty) '• $prestador',
    ];
    return showSimple(
      title: 'Autorização liberada',
      body: parts.join(' '),
      payload: 'exame:$numero',
    );
  }
}
