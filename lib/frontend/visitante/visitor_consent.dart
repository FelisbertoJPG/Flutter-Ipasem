// lib/flows/visitor_consent.dart
import 'package:flutter/material.dart';
import '../../common/data/consent_store.dart';
import '../views/components/consent_dialog.dart';

/// Retorna true se aceitou (ou já estava aceito); false se negou/cancelou.
Future<bool> ensureVisitorConsent(BuildContext context) async {
  if (await ConsentStore.isAccepted()) return true;

  final accepted = await ConsentDialog.show(
    context,
    onOpenPrivacy: () => Navigator.of(context).pushNamed('/privacidade'),
    onOpenTerms:   () => Navigator.of(context).pushNamed('/termos'),
  );

  if (accepted == true) {
    await ConsentStore.setAccepted(true);
    return true;
  }
  return false;
}
