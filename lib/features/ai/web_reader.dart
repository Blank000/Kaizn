import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'chat_attachments.dart';

/// Reads the web pages a user links in a Pico message, so Pico can answer
/// from what the page actually says.
///
/// The PHONE fetches the page, not Zuzu's server: a server that fetches any
/// URL it's handed could be pointed at other machines, and the user's own
/// connection reaches the pages they can see anyway.
///
/// Pages that build their content with JavaScript, or sit behind a login,
/// come back nearly empty. Pico is told exactly that rather than left to
/// guess at the page.
class WebReader {
  WebReader._();

  /// Pages read per message. More than this is usually a pasted list.
  static const maxLinks = 3;
  static const _maxDownload = 3 * 1024 * 1024;

  static final _urlPattern = RegExp(
    r'''(?:https?://|www\.)[^\s<>"'`]+''',
    caseSensitive: false,
  );

  /// The links in [text], in order, without duplicates or trailing
  /// punctuation. `www.` links get https:// added.
  static List<String> extractUrls(String text) {
    final seen = <String>{};
    final out = <String>[];
    for (final m in _urlPattern.allMatches(text)) {
      var url = m.group(0)!;
      // "see example.com/page." - the full stop isn't part of the link.
      while (url.isNotEmpty && '.,;:!?)]}'.contains(url[url.length - 1])) {
        // Keep a closing bracket that has its opening one, as in Wikipedia
        // links like /wiki/Kaizen_(business).
        final last = url[url.length - 1];
        if (last == ')' && url.contains('(')) break;
        url = url.substring(0, url.length - 1);
      }
      if (url.toLowerCase().startsWith('www.')) url = 'https://$url';
      final uri = Uri.tryParse(url);
      if (uri == null || uri.host.isEmpty) continue;
      if (seen.add(url)) out.add(url);
    }
    return out;
  }

  /// Fetches every link in [text] (up to [maxLinks]). Never throws: a page
  /// that can't be read becomes an attachment saying so.
  static Future<List<ChatAttachment>> readLinks(String text,
      {http.Client? client}) async {
    final urls = extractUrls(text).take(maxLinks).toList();
    if (urls.isEmpty) return const [];
    final c = client ?? http.Client();
    try {
      return await Future.wait(urls.map((u) => _read(c, u)));
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<ChatAttachment> _read(http.Client client, String url) async {
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers.addAll({
          // Some sites refuse requests that don't look like a browser.
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) '
              'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 '
              'Mobile Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/pdf,'
              'text/plain;q=0.9,*/*;q=0.5',
          'Accept-Language': 'en',
        });
      final resp =
          await client.send(req).timeout(const Duration(seconds: 15));
      if (resp.statusCode >= 400) {
        unawaited(resp.stream.drain<void>());
        return _failed(url, 'the site answered with error ${resp.statusCode}');
      }
      final bytes = await _readCapped(resp.stream)
          .timeout(const Duration(seconds: 20));
      final type = (resp.headers['content-type'] ?? '').toLowerCase();

      if (type.contains('application/pdf') ||
          (type.isEmpty && url.toLowerCase().endsWith('.pdf'))) {
        if (bytes.length > ChatAttachment.maxPdfBytes) {
          return _failed(url, 'the PDF is over 10 MB');
        }
        return ChatAttachment(
          kind: AttachmentKind.pdf,
          name: Uri.parse(url).pathSegments.lastOrNull ?? 'linked.pdf',
          mime: 'application/pdf',
          bytes: bytes,
        );
      }

      final body = _decode(bytes, type);
      final isHtml = type.contains('html') ||
          (type.isEmpty && body.trimLeft().startsWith('<'));
      if (!isHtml && !type.startsWith('text/') && !type.contains('json')) {
        return _failed(url, "it isn't a web page or PDF ($type)");
      }
      final page = isHtml ? htmlToText(body) : (title: '', text: body);
      return ChatAttachment(
        kind: AttachmentKind.webPage,
        name: url,
        text: describePage(url, page.title, page.text),
      );
    } on TimeoutException {
      return _failed(url, 'the site took too long to answer');
    } catch (_) {
      return _failed(url, "the site couldn't be reached");
    }
  }

  /// What the model is told about a page it was given.
  static String describePage(String url, String title, String text) {
    final body = text.trim();
    final header = 'Web page the user linked: $url'
        '${title.isEmpty ? '' : '\nTitle: $title'}';
    if (body.length < 200) {
      return '$header\n(The page returned almost no readable text - it '
          'probably builds its content with JavaScript or needs a login. '
          'Tell the user you could only see the title/summary, and answer '
          'only from what is below.)\n<<<\n$body\n>>>';
    }
    return '$header\n<<<\n${ChatAttachment.clip(body)}\n>>>';
  }

  static ChatAttachment _failed(String url, String why) => ChatAttachment(
        kind: AttachmentKind.webPage,
        name: url,
        failed: true,
        text: 'Web page the user linked: $url\n(It could NOT be read: $why. '
            "Tell the user so plainly. Don't guess what the page says.)",
      );

  static Future<Uint8List> _readCapped(Stream<List<int>> stream) async {
    final out = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      out.add(chunk);
      if (out.length >= _maxDownload) break;
    }
    return out.takeBytes();
  }

  static String _decode(Uint8List bytes, String contentType) {
    final charset =
        RegExp(r'charset=([\w-]+)').firstMatch(contentType)?.group(1);
    if (charset != null && charset.toLowerCase().contains('8859')) {
      return latin1.decode(bytes, allowInvalid: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// The readable text of an HTML page, plus its title. Pure, so it is
  /// unit-tested. Deliberately simple: drop what isn't content, turn block
  /// ends into line breaks, strip tags, decode entities. Meta descriptions
  /// are kept because JavaScript-built pages often have nothing else.
  static ({String title, String text}) htmlToText(String html) {
    String meta(String key) {
      final tag = RegExp(
              '<meta[^>]+(?:name|property)\\s*=\\s*["\']$key["\'][^>]*>',
              caseSensitive: false)
          .firstMatch(html)
          ?.group(0);
      if (tag == null) return '';
      return _entities(RegExp(r'''content\s*=\s*["']([^"']*)["']''',
                  caseSensitive: false)
              .firstMatch(tag)
              ?.group(1) ??
          '');
    }

    final title = _entities(_collapse(RegExp(
                r'<title[^>]*>([\s\S]*?)</title>',
                caseSensitive: false)
            .firstMatch(html)
            ?.group(1) ??
        meta('og:title')));
    final description = meta('description').isNotEmpty
        ? meta('description')
        : meta('og:description');

    var s = html;
    // Remove whole blocks whose text is never content.
    s = s.replaceAll(
        RegExp(
            // Not <form>: some sites (ASP.NET) wrap the whole page in one.
            r'<(script|style|noscript|svg|template|iframe|head|nav|footer)'
            r'\b[\s\S]*?</\1\s*>',
            caseSensitive: false),
        ' ');
    s = s.replaceAll(RegExp(r'<!--[\s\S]*?-->'), ' ');
    // Block-level ends become line breaks so paragraphs stay apart.
    s = s.replaceAll(
        RegExp(r'<(br|/p|/div|/li|/tr|/h[1-6]|/section|/article|/blockquote)'
            r'\b[^>]*>',
            caseSensitive: false),
        '\n');
    s = s.replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '\n• ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    s = _entities(s);
    final lines = s
        .split('\n')
        .map(_collapse)
        .where((l) => l.isNotEmpty)
        .toList();
    var text = lines.join('\n');
    if (description.isNotEmpty && !text.contains(description)) {
      text = 'Summary: $description\n\n$text';
    }
    return (title: title, text: text);
  }

  static String _collapse(String s) =>
      s.replaceAll(RegExp(r'[ \t\r\f\v\u00a0]+'), ' ').trim();

  static String _entities(String s) => s
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.tryParse(m.group(1)!);
        return code == null || code > 0x10FFFF
            ? ''
            : String.fromCharCode(code);
      })
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
        final code = int.tryParse(m.group(1)!, radix: 16);
        return code == null || code > 0x10FFFF
            ? ''
            : String.fromCharCode(code);
      })
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–')
      .replaceAll('&hellip;', '…')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&amp;', '&');
}
