// services/file_upload_manager.dart
import 'package:file_picker/file_picker.dart';

class FileUploadManager {
  /// Converte os acceptTypes do <input type=file> para FilePicker
  static ({FileType type, List<String>? exts}) _mapAcceptTypes(List<String> acceptTypes) {
    final types = acceptTypes.map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
    if (types.isEmpty) return (type: FileType.any, exts: null);

    // wildcards mais comuns
    if (types.any((t) => t == 'image/*')) return (type: FileType.image, exts: null);
    if (types.any((t) => t == 'video/*')) return (type: FileType.video, exts: null);
    if (types.any((t) => t == 'audio/*')) return (type: FileType.audio, exts: null);

    // extensões específicas
    final exts = <String>[];
    for (var t in types) {
      if (t.startsWith('.')) {
        exts.add(t.substring(1));
      } else if (t == 'application/pdf') {
        exts.add('pdf');
      } else if (t == 'application/zip') {
        exts.add('zip');
      }
    }
    if (exts.isNotEmpty) return (type: FileType.custom, exts: exts);

    return (type: FileType.any, exts: null);
  }

  /// Abre o picker e retorna URIs (file://...) que o WebView entende.
  static Future<List<String>> pick({
    required List<String> acceptTypes,
    required bool allowMultiple,
  }) async {
    final mapped = _mapAcceptTypes(acceptTypes);
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      type: mapped.type,
      allowedExtensions: mapped.exts,
      withData: false,
    );
    if (res == null) return <String>[];
    return res.files
        .where((f) => f.path != null)
        .map((f) => Uri.file(f.path!).toString())
        .toList();
  }
}
