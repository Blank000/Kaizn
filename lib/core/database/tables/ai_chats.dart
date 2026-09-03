import 'package:drift/drift.dart';

/// Pico chat history — one row per message, grouped into threads. Stored
/// locally (the OpenAI chat API is stateless; nothing lives server-side),
/// so history is private, free, and survives app restarts.
@DataClassName('AiChatMessage')
class AiChatMessages extends Table {
  TextColumn get id => text()();

  /// Groups messages into conversations; a new id starts a new thread.
  TextColumn get threadId => text()();

  TextColumn get role => text()(); // 'user' | 'assistant'
  TextColumn get content => text()();

  /// Local error notices (transport failures) — rendered, never replayed
  /// to the API.
  BoolColumn get isError => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
