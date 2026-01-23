// lib/backend/controller/pdf_controller/pdf_controller.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PdfController {
  Future<void> handlePdfGet(String url, WebViewController webview) async {
    final headers = await _buildHeadersFor(url, webview, includeContentType: false);
    final resp = await http.get(Uri.parse(url), headers: headers);
    _ensureOk(resp, 'GET $url');
    final filename = _filenameFromHeaders(resp.headers, fallbackFromUrl: url);
    await _saveAndOpen(resp.bodyBytes, filename);
  }

  Future<void> handlePdfPostUrlEncoded(
      String url,
      Map<String, String> formData,
      WebViewController webview,
      ) async {
    final headers = await _buildHeadersFor(url, webview, includeContentType: true);
    final resp = await http.post(Uri.parse(url), headers: headers, body: formData);
    _ensureOk(resp, 'POST $url');
    final filename = _filenameFromHeaders(resp.headers, fallbackFromUrl: url);
    await _saveAndOpen(resp.bodyBytes, filename);
  }

  Future<void> handlePdfPostMultipart(
      String url,
      Map<String, String> formData,
      WebViewController webview,
      ) async {
    final headers = await _buildHeadersFor(url, webview, includeContentType: false);
    final req = http.MultipartRequest('POST', Uri.parse(url))..headers.addAll(headers);
    formData.forEach((k, v) => req.fields[k] = v);
    final resp = await http.Response.fromStream(await req.send());
    _ensureOk(resp, 'POST multipart $url');
    final filename = _filenameFromHeaders(resp.headers, fallbackFromUrl: url);
    await _saveAndOpen(resp.bodyBytes, filename);
  }

  // ----------------- helpers -----------------

  Future<Map<String, String>> _buildHeadersFor(
      String url,
      WebViewController webview, {
        bool includeContentType = false,
      }) async {
    final uri = Uri.parse(url);
    final cookieStr = await _evalJsString(webview, 'document.cookie') ?? '';
    final ua       = await _evalJsString(webview, 'navigator.userAgent') ?? 'FlutterWebView';
    final referer  = await _evalJsString(webview, 'location.href') ?? '${uri.scheme}://${uri.host}/';
    final origin   = '${uri.scheme}://${uri.host}';

    return {
      'User-Agent': ua,
      'Accept': 'application/pdf,application/octet-stream,*/*',
      'Cookie': cookieStr,                     // NÃO inclui HttpOnly
      'Referer': referer,
      'Origin': origin,
      'Accept-Language': 'pt-BR,pt;q=0.9',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
      if (includeContentType)
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
    };
  }

  Future<String?> _evalJsString(WebViewController webview, String expr) async {
    final result = await webview.runJavaScriptReturningResult('JSON.stringify($expr)');
    if (result is String) {
      try {
        return result.isEmpty ? null : result.substring(1, result.length - 1);
      } catch (_) {
        return result;
      }
    }
    return result?.toString();
  }

  void _ensureOk(http.Response resp, String label) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('$label falhou (${resp.statusCode})');
    }
  }

  String _filenameFromHeaders(Map<String, String> headers, {String? fallbackFromUrl}) {
    final cd = headers['content-disposition'] ?? headers['Content-Disposition'] ?? '';
    final re = RegExp(r'''filename\*?=(?:UTF-8''|")?([^";]+)''', caseSensitive: false);
    final m = re.firstMatch(cd);
    if (m != null) {
      final name = Uri.decodeFull(m.group(1)!.replaceAll('"', ''));
      return _sanitizeFilename(name);
    }
    if (fallbackFromUrl != null) {
      final last = Uri.parse(fallbackFromUrl).pathSegments.last;
      if (last.isNotEmpty) return _sanitizeFilename(last);
    }
    return 'documento.pdf';
  }

  String _sanitizeFilename(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  Future<void> _saveAndOpen(List<int> bytes, String filename) async {
    final dir   = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safe  = _sanitizeFilename(
      filename.toLowerCase().endsWith('.pdf') ? filename : '$filename.pdf',
    );
    final file = File('${dir.path}/$stamp-$safe');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
  }
}
