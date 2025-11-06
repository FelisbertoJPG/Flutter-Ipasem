import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/comunicados_service.dart';
import '../../api/api_myadmin.dart' show Comunicado;

class ComunicadoDetailSheet extends StatefulWidget {
  final int id;
  final ComunicadosService service;

  const ComunicadoDetailSheet({
    super.key,
    required this.id,
    required this.service,
  });

  @override
  State<ComunicadoDetailSheet> createState() => _ComunicadoDetailSheetState();
}

class _ComunicadoDetailSheetState extends State<ComunicadoDetailSheet> {
  late Future<Comunicado> _future;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: FutureBuilder<Comunicado>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const Icon(Icons.error_outline),
                  const SizedBox(height: 8),
                  Text('Falha ao carregar comunicado.',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('${snap.error}', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                      });
                    },
                    child: const Text('Tentar novamente'),
                  ),
                ],
              );
            }

            final c = snap.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título + fechar
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.titulo,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 3,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Categoria + data
                  Row(
                    children: [
                      if ((c.categoria ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip(label: Text(c.categoria!.trim())),
                        ),
                      if (c.publicadoEm != null)
                        Text(
                          df.format(c.publicadoEm!.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Corpo (completo)
                  SelectableText(
                    c.corpo.trim(),
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
