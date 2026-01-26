import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CpfPrompt {
  static Future<String?> show(BuildContext context, {String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final focus = FocusNode();
    String? error;
    var didInit = false;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          if (!didInit) {
            didInit = true;
            Future.delayed(const Duration(milliseconds: 180), () {
              if (focus.canRequestFocus) focus.requestFocus();
            });
          }

          final media = MediaQuery.of(ctx);
          final sheetHeight = media.size.height * 0.30;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16, bottom: media.viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: sheetHeight.clamp(260.0, 420.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE5EE), borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('Insira seu CPF',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    focusNode: focus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: InputDecoration(
                      hintText: '00000000000',
                      errorText: error,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final digits = ctrl.text.replaceAll(RegExp(r'\D'), '');
                            if (digits.length != 11) {
                              setState(() => error = 'CPF deve ter 11 dígitos');
                              return;
                            }
                            Navigator.pop(ctx, digits);
                          },
                          child: const Text('Continuar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
