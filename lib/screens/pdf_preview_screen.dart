// lib/screens/pdf_preview_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';

import '../pdf/autorizacao_pdf_data.dart';
import '../pdf/pdf_autorizacao_builder.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    super.key,
    required this.data,
    required this.fileName,
  });

  final AutorizacaoPdfData data;
  final String fileName; // ex: "ordem_2977666.pdf"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        actions: [
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.share_outlined),
            onPressed: () async {
              final bytes = await buildAutorizacaoPdf(data);
              await Printing.sharePdf(bytes: bytes, filename: fileName);
            },
          ),
          IconButton(
            tooltip: 'Imprimir',
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final bytes = await buildAutorizacaoPdf(data);
              await Printing.layoutPdf(onLayout: (format) async => bytes);
            },
          ),
          IconButton(
            tooltip: 'Baixar',
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              final bytes = await buildAutorizacaoPdf(data);
              final savedPath = await _saveWithSystemPicker(bytes, fileName);
              if (context.mounted) {
                if (savedPath != null && savedPath.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Arquivo salvo em: $savedPath')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Não foi possível salvar o arquivo.')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => buildAutorizacaoPdf(data),
        allowSharing: false,
        allowPrinting: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: fileName,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.open_in_new),
        label: const Text('Abrir arquivo…'),
        onPressed: () async {
          final bytes = await buildAutorizacaoPdf(data);
          final path = await _saveWithSystemPicker(bytes, fileName);
          if (path != null && path.isNotEmpty) {
            await OpenFilex.open(path);
          }
        },
      ),
    );
  }

  /// Abre o seletor nativo (SAF no Android) para o usuário escolher onde salvar.
  /// Retorna o caminho salvo quando disponível.
  Future<String?> _saveWithSystemPicker(Uint8List bytes, String name) async {
    try {
      final String? savedPath = await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
      return savedPath;
    } catch (_) {
      return null;
    }
  }
}
