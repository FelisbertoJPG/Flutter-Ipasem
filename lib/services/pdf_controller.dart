// lib/services/pdf_controller.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PdfController {
  /// GET de PDF preservando cookies da sessão da WebView.
  Future<void> handlePdfGet(String url, WebViewController webview) async {
    final headers = await _buildHeadersFor(url, webview);
    final resp = await http.get(Uri.parse(url), headers: headers);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final filename = _filenameFromHeaders(resp.headers, fallbackFromUrl: url);
      await _saveAndOpen(resp.bodyBytes, filename);
    } else {
      throw Exception('GET $url falhou (${resp.statusCode})');
    }
  }

  /// POST urlencoded (padrão de muitos backends PHP).
  Future<void> handlePdfPostUrlEncoded(
      String url,
      Map<String, String> formData,
      WebViewController webview,
      ) async {
    final headers = await _buildHeadersFor(url, webview);
    final resp = await http.post(Uri.parse(url), headers: headers, body: formData);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final filename = _filenameFromHeaders(resp.headers);
      await _saveAndOpen(resp.bodyBytes, filename);
    } else {
      throw Exception('POST $url falhou (${resp.statusCode})');
    }
  }

  /// POST multipart (caso o endpoint exija multipart como o FormData do browser).
  Future<void> handlePdfPostMultipart(
      String url,
      Map<String, String> formData,
      WebViewController webview,
      ) async {
    final headers = await _buildHeadersFor(url, webview, includeContentType: false);
    final req = http.MultipartRequest('POST', Uri.parse(url));
    req.headers.addAll(headers);
    formData.forEach((k, v) => req.fields[k] = v);
    final streamResp = await req.send();
    final resp = await http.Response.fromStream(streamResp);
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final filename = _filenameFromHeaders(resp.headers);
      await _saveAndOpen(resp.bodyBytes, filename);
    } else {
      throw Exception('POST multipart $url falhou (${resp.statusCode})');
    }
  }

  // ----------------- helpers -----------------

  Future<Map<String, String>> _buildHeadersFor(
      String url,
      WebViewController webview, {
        bool includeContentType = true,
      }) async {
    final uri = Uri.parse(url);

    // Lê cookies e user-agent da própria WebView (podem voltar null).
    final cookieStr = await _evalJsString(webview, 'document.cookie') ?? '';
    final ua = await _evalJsString(webview, 'navigator.userAgent') ?? 'FlutterWebView';

    final headers = <String, String>{
      'Host': uri.host,
      'User-Agent': ua,
      'Accept': 'application/pdf,application/octet-stream,*/*',
      'Cookie': cookieStr,
      'Accept-Language': 'pt-BR,pt;q=0.9',
      'Connection': 'keep-alive',
    };
    if (includeContentType) {
      headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8';
    }
    return headers;
  }

  Future<String?> _evalJsString(WebViewController webview, String expr) async {
    // Usa JSON.stringify para garantir retorno de string.
    final result = await webview.runJavaScriptReturningResult('JSON.stringify($expr)');
    if (result is String) {
      // remove aspas do JSON.stringify
      try {
        return result.isEmpty ? null : (result.substring(1, result.length - 1));
      } catch (_) {
        return result;
      }
    }
    return result?.toString();
  }

  String _filenameFromHeaders(Map<String, String> headers, {String? fallbackFromUrl}) {
    // evita MapEntry/firstWhere; pega direto as duas variantes do header
    final cd = headers['content-disposition'] ??
        headers['Content-Disposition'] ??
        '';

    final re = RegExp(
      r'''filename\*?=(?:UTF-8''|")?([^";]+)''',
      caseSensitive: false,
    );

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

  String _sanitizeFilename(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

  Future<void> _saveAndOpen(List<int> bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }
}
