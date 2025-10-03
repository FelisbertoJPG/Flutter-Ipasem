// data/session_hook.dart
import 'package:flutter/material.dart';
import 'session_store.dart';

class SessionSnapshot {
  final bool isLoggedIn;
  final String? cpf;
  const SessionSnapshot(this.isLoggedIn, this.cpf);
}

Future<SessionSnapshot> loadSession() async {
  final s = SessionStore();
  final logged = await s.getIsLoggedIn();
  final cpf = await s.getSavedCpf();
  return SessionSnapshot(logged, cpf);
}
