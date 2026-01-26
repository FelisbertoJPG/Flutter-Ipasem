import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PdfOpenHelper {
  PdfOpenHelper._();

  static String _sanitizeFilename(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  static Future<void> openBytes(
      Uint8List bytes, {
        String filename = 'documento.pdf',
      }) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;

    final safe = _sanitizeFilename(
      filename.toLowerCase().endsWith('.pdf') ? filename : '$filename.pdf',
    );

    final file = File('${dir.path}/$stamp-$safe');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }
}
