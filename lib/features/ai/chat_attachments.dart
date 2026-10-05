import 'dart:convert';
import 'dart:typed_data';

/// What a chat attachment is, which decides how the model receives it.
enum AttachmentKind {
  /// A photo or screenshot - sent as an image the model can see.
  image,

  /// A PDF - sent whole; OpenAI reads both its text and its pages.
  pdf,

  /// A plain-text file (txt, md, csv, json) - sent as text.
  text,

  /// A web page the user linked - fetched on the phone, sent as its text.
  webPage,
}

/// Something sent alongside a Pico message.
///
/// Attachments live in memory only. The chat history saves just their
/// names (see [describeForHistory]) - photos and PDFs would bloat the
/// local database, and a restored thread can't resend them anyway.
class ChatAttachment {
  final AttachmentKind kind;

  /// File name, or the URL for a web page.
  final String name;

  /// MIME type, for images and PDFs.
  final String? mime;

  /// Raw bytes, for images and PDFs.
  final Uint8List? bytes;

  /// Extracted text, for text files and web pages.
  final String? text;

  /// A linked page that couldn't be read. Pico is still told, so it says
  /// so instead of guessing what the page contains.
  final bool failed;

  const ChatAttachment({
    required this.kind,
    required this.name,
    this.mime,
    this.bytes,
    this.text,
    this.failed = false,
  });

  // Limits that keep one message affordable and under the server's cap.
  static const maxPerMessage = 4;
  static const maxPdfBytes = 10 * 1024 * 1024;
  static const maxImageBytes = 5 * 1024 * 1024;
  static const maxTextFileBytes = 2 * 1024 * 1024;
  static const maxTextChars = 40000;

  static const textExtensions = ['txt', 'md', 'csv', 'json'];

  /// Builds an attachment from a picked file, or explains why it can't be
  /// one. Pure, so the rules are unit-tested.
  static ({ChatAttachment? attachment, String? error}) fromFile(
      String name, Uint8List bytes) {
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    if (ext == 'pdf') {
      if (bytes.length > maxPdfBytes) {
        return (attachment: null, error: '$name is over 10 MB.');
      }
      return (
        attachment: ChatAttachment(
            kind: AttachmentKind.pdf,
            name: name,
            mime: 'application/pdf',
            bytes: bytes),
        error: null,
      );
    }
    final image = imageMime(ext);
    if (image != null) {
      if (bytes.length > maxImageBytes) {
        return (
          attachment: null,
          error: '$name is over 5 MB - use Photos instead, which shrinks it.',
        );
      }
      return (
        attachment: ChatAttachment(
            kind: AttachmentKind.image, name: name, mime: image, bytes: bytes),
        error: null,
      );
    }
    if (textExtensions.contains(ext)) {
      if (bytes.length > maxTextFileBytes) {
        return (attachment: null, error: '$name is over 2 MB.');
      }
      final text = utf8.decode(bytes, allowMalformed: true);
      return (
        attachment: ChatAttachment(
            kind: AttachmentKind.text, name: name, text: clip(text)),
        error: null,
      );
    }
    return (
      attachment: null,
      error: "Pico can't read .$ext files yet - try a PDF, photo or text file.",
    );
  }

  static String? imageMime(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => null,
      };

  static String clip(String text) => text.length <= maxTextChars
      ? text
      : '${text.substring(0, maxTextChars)}\n[... cut off here - the rest '
          'was too long to send]';

  /// Roughly how many bytes this adds to a request (base64 is 4/3 of raw).
  int get requestBytes =>
      bytes != null ? bytes!.length * 4 ~/ 3 : (text?.length ?? 0) * 2;

  /// How much attachment data one request may carry. The server refuses
  /// bodies over 30 MB; this leaves room for the chat itself.
  static const requestBudget = 20 * 1024 * 1024;

  /// The OpenAI chat-completions content part for this attachment.
  Map<String, Object> toContentPart() {
    switch (kind) {
      case AttachmentKind.image:
        return {
          'type': 'image_url',
          'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes!)}'},
        };
      case AttachmentKind.pdf:
        return {
          'type': 'file',
          'file': {
            'filename': name,
            'file_data': 'data:application/pdf;base64,${base64Encode(bytes!)}',
          },
        };
      case AttachmentKind.text:
        return {
          'type': 'text',
          'text': 'Attached file "$name":\n<<<\n$text\n>>>',
        };
      case AttachmentKind.webPage:
        return {'type': 'text', 'text': text!};
    }
  }

  /// One line saved into chat history in place of the attachments.
  static String? describeForHistory(List<ChatAttachment> all) {
    final files =
        all.where((a) => a.kind != AttachmentKind.webPage).toList();
    if (files.isEmpty) return null;
    return '📎 ${files.map((a) => a.name).join(' · ')}';
  }
}
