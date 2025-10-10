import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart' as pdf;


// Android: para salvar em /Download
// ignore: depend_on_referenced_packages
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';

import '../pdf/autorizacao_pdf_data.dart';
import '../pdf/pdf_autorizacao.dart';
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
              final savedPath = await _saveWithBestEffort(bytes, fileName);
              if (context.mounted) {
                if (savedPath != null) {
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
        allowSharing: false, // já colocamos nosso botão de compartilhar no AppBar
        allowPrinting: false, // idem
        canChangePageFormat: false,
        canChangeOrientation: false,
        initialPageFormat: pdf.PdfPageFormat.a4,//erro aqui
        pdfFileName: fileName,
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.open_in_new),
        label: const Text('Abrir arquivo…'),
        onPressed: () async {
          final bytes = await buildAutorizacaoPdf(data);
          final tmp = await _saveTemp(bytes, fileName);
          await OpenFilex.open(tmp);
        },
      ),
    );
  }

  // Salva em local “bonito” (Downloads/…) quando possível; senão cai para Documents do app
  Future<String?> _saveWithBestEffort(Uint8List bytes, String name) async {
    try {
      String? fullPath;

      if (Platform.isAndroid) {
        // tenta permissão de armazenamento (<= Android 12)
        final status = await Permission.storage.request();
        if (status.isGranted || status.isLimited) {
          final dlDir = await DownloadsPathProvider.downloadsDirectory;
          if (dlDir != null) {
            final dir = Directory('${dlDir.path}/IPASEM');
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            final file = File('${dir.path}/$name');
            await file.writeAsBytes(bytes);
            fullPath = file.path;
          }
        }
      } else if (Platform.isIOS || Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        final downloads = await _desktopDownloadsFallback();
        if (downloads != null) {
          final dir = Directory('${downloads.path}/IPASEM');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final file = File('${dir.path}/$name');
          await file.writeAsBytes(bytes);
          fullPath = file.path;
        }
      }

      // Fallback: pasta de documentos do app (sempre funciona)
      if (fullPath == null) {
        final docs = await getApplicationDocumentsDirectory();
        final dir = Directory('${docs.path}/IPASEM');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes);
        fullPath = file.path;
      }

      return fullPath;
    } catch (_) {
      return null;
    }
  }

  // salva temporário pra abrir imediatamente com outro app (se o usuário quiser)
  Future<String> _saveTemp(Uint8List bytes, String name) async {
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  // “Downloads” em desktop (quando disponível)
  Future<Directory?> _desktopDownloadsFallback() async {
    try {
      // path_provider só dá Downloads em desktop/web (em mobile, geralmente não)
      // então aqui tentamos uma pasta "Downloads" ao lado de Documents do usuário.
      final docs = await getApplicationDocumentsDirectory();
      final home = Directory(docs.path).parent.parent; // .../User/<you>/
      final d1 = Directory('${home.path}/Downloads');
      return await d1.exists() ? d1 : null;
    } catch (_) {
      return null;
    }
  }
}
