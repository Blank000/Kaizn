import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_reward_tracker/features/ai/chat_attachments.dart';
import 'package:habit_reward_tracker/features/ai/web_reader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('extractUrls', () {
    test('finds links and drops trailing punctuation', () {
      expect(
        WebReader.extractUrls(
            'Read https://example.com/a. Then www.site.org/x, ok?'),
        ['https://example.com/a', 'https://www.site.org/x'],
      );
    });

    test('keeps balanced brackets, skips duplicates', () {
      expect(
        WebReader.extractUrls('https://en.wikipedia.org/wiki/Kaizen_(business) '
            'and again https://en.wikipedia.org/wiki/Kaizen_(business)'),
        ['https://en.wikipedia.org/wiki/Kaizen_(business)'],
      );
    });

    test('no links, no work', () {
      expect(WebReader.extractUrls('plan my week please'), isEmpty);
    });
  });

  group('htmlToText', () {
    test('keeps content, drops scripts and navigation', () {
      final page = WebReader.htmlToText('''
<html><head><title>Morning &amp; Night Routine</title>
<meta name="description" content="A calm start to the day.">
<script>var tracking = 1;</script><style>p{color:red}</style></head>
<body><nav>Home | About</nav>
<h1>Routine</h1><p>Wake at 6&nbsp;AM.</p><ul><li>Water</li><li>Walk</li></ul>
<footer>© 2026</footer></body></html>''');
      expect(page.title, 'Morning & Night Routine');
      expect(page.text, contains('Summary: A calm start to the day.'));
      expect(page.text, contains('Wake at 6 AM.'));
      expect(page.text, contains('• Water'));
      expect(page.text, isNot(contains('tracking')));
      expect(page.text, isNot(contains('Home | About')));
      expect(page.text, isNot(contains('© 2026')));
    });
  });

  group('readLinks', () {
    test('a readable page becomes its text', () async {
      final client = MockClient((req) async => http.Response(
            '<title>Tips</title><p>${'Drink water. ' * 30}</p>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          ));
      final pages =
          await WebReader.readLinks('see https://x.com/tips', client: client);
      expect(pages, hasLength(1));
      expect(pages.single.failed, isFalse);
      expect(pages.single.text, contains('Title: Tips'));
      expect(pages.single.text, contains('Drink water.'));
    });

    test('an error page is reported, not guessed at', () async {
      final client = MockClient((_) async => http.Response('nope', 404));
      final pages =
          await WebReader.readLinks('https://x.com/gone', client: client);
      expect(pages.single.failed, isTrue);
      expect(pages.single.text, contains('could NOT be read'));
      expect(pages.single.text, contains('404'));
    });

    test('a JavaScript-only page is flagged as nearly empty', () async {
      final client = MockClient((_) async => http.Response(
            '<title>App</title><div id="root"></div>',
            200,
            headers: {'content-type': 'text/html'},
          ));
      final pages =
          await WebReader.readLinks('https://app.example.com', client: client);
      expect(pages.single.text, contains('almost no readable text'));
    });

    test('a linked PDF is sent as a PDF', () async {
      final client = MockClient((_) async => http.Response.bytes(
            utf8.encode('%PDF-1.4 fake'),
            200,
            headers: {'content-type': 'application/pdf'},
          ));
      final pages = await WebReader.readLinks('https://x.com/guide.pdf',
          client: client);
      expect(pages.single.kind, AttachmentKind.pdf);
      expect(pages.single.name, 'guide.pdf');
    });
  });

  group('ChatAttachment', () {
    test('files are sorted into the right kind', () {
      final bytes = Uint8List.fromList(utf8.encode('hello'));
      expect(ChatAttachment.fromFile('a.PDF', bytes).attachment!.kind,
          AttachmentKind.pdf);
      expect(ChatAttachment.fromFile('notes.md', bytes).attachment!.text,
          'hello');
      expect(ChatAttachment.fromFile('pic.jpg', bytes).attachment!.mime,
          'image/jpeg');
      expect(ChatAttachment.fromFile('app.exe', bytes).error,
          contains("can't read .exe"));
    });

    test('oversized PDFs are refused before sending', () {
      final big = Uint8List(ChatAttachment.maxPdfBytes + 1);
      expect(ChatAttachment.fromFile('huge.pdf', big).error,
          contains('over 10 MB'));
    });

    test('content parts match the OpenAI shapes', () {
      final img = ChatAttachment(
          kind: AttachmentKind.image,
          name: 'a.png',
          mime: 'image/png',
          bytes: Uint8List.fromList([1, 2, 3]));
      expect(img.toContentPart(), {
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,AQID'},
      });
      final pdf = ChatAttachment(
          kind: AttachmentKind.pdf,
          name: 'p.pdf',
          mime: 'application/pdf',
          bytes: Uint8List.fromList([1, 2, 3]));
      expect((pdf.toContentPart()['file'] as Map)['file_data'],
          'data:application/pdf;base64,AQID');
    });

    test('history keeps file names but not links', () {
      expect(
        ChatAttachment.describeForHistory([
          const ChatAttachment(kind: AttachmentKind.pdf, name: 'plan.pdf'),
          const ChatAttachment(kind: AttachmentKind.webPage, name: 'https://x'),
          const ChatAttachment(kind: AttachmentKind.image, name: 'shot.jpg'),
        ]),
        '📎 plan.pdf · shot.jpg',
      );
      expect(
          ChatAttachment.describeForHistory([
            const ChatAttachment(
                kind: AttachmentKind.webPage, name: 'https://x'),
          ]),
          isNull);
    });
  });
}
