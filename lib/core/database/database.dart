// lib/core/database/database.dart

import 'dart:io';

import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Export ConversationData from generated drift file for use in Riverpod providers
export 'database.drift.dart' show ConversationData;

part 'database.g.dart';

// WHY: This custom converter allows Drift to store our MessageStatus enum as a simple
// String in the database, making the data human-readable and portable.
class MessageStatusConverter extends TypeConverter<MessageStatus, String> {
  const MessageStatusConverter();

  @override
  MessageStatus fromSql(String fromDb) => MessageStatus.values.byName(fromDb);

  @override
  String toSql(MessageStatus value) => value.name;
}

// --- Data Models (for Drift) ---

@DataClassName('ConversationData')
class Conversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// WHY: We use @DataClassName to give the generated data class a different name ('MessageData').
// This avoids a name conflict with our existing Freezed model named 'Message'.
@DataClassName('MessageData')
class Messages extends Table {
  TextColumn get id => text()();
  // WHY: Foreign key relationship ensures referential integrity and enables cascade delete.
  // When a conversation is deleted, all associated messages are automatically removed.
  IntColumn get conversationId =>
      integer().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get content => text()();
  BoolColumn get isFromUser => boolean()();
  TextColumn get status => text().map(const MessageStatusConverter())();

  @override
  Set<Column> get primaryKey => {id};
}

// WHY: LazyDatabase ensures the database connection is only opened when needed.
// This is important for platform-specific path resolution.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [Conversations, Messages])
class AppDatabase extends _$AppDatabase {
  // WHY: This constructor uses NativeDatabase with a platform-agnostic path.
  // The database file will be stored in the app's documents directory.
  AppDatabase() : super(_openConnection());

  // WHY: Test constructor that uses in-memory database for fast, isolated tests.
  AppDatabase.test() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  // WHY: A migration strategy is essential for any production application.
  // It ensures that when you change your database schema in future versions (e.g., add a new column),
  // existing users' data can be safely migrated without loss.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // WHY: Migration from schema version 1 to 2 adds Conversations table and conversationId column.
        // Existing messages are assigned to a default "Legacy" conversation to preserve user data.
        if (from < 2) {
          // Step 1: Create Conversations table
          await m.createTable(conversations);

          // Step 2: Create default "Legacy" conversation for existing messages
          final db = m.database as AppDatabase;
          final legacyId = await db
              .into(db.conversations)
              .insert(
                ConversationsCompanion.insert(
                  title: 'Legacy',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

          // Step 3: Recreate Messages table with conversationId column
          // WHY: SQLite doesn't support adding NOT NULL columns to existing tables.
          // We must recreate the table: rename old, create new, copy data, drop old.
          // Handle case where messages_old might already exist from a failed migration
          try {
            await db.customStatement('DROP TABLE IF EXISTS messages_old');
          } on Object {
            // Ignore if table doesn't exist or other errors
          }
          await db.customStatement(
            'ALTER TABLE messages RENAME TO messages_old',
          );
          await m.createTable(messages);

          // Step 4: Migrate existing messages to new table with legacy conversationId
          await db.customStatement(
            'INSERT INTO messages (id, conversationId, content, isFromUser, status) '
            'SELECT id, $legacyId, content, isFromUser, status FROM messages_old',
          );

          // Step 5: Drop old table
          await db.customStatement('DROP TABLE messages_old');
        }
      },
    );
  }

  // --- Conversation Data Access Methods ---

  // WHY: This method provides a reactive stream of all conversations, ordered by most recently updated.
  // The UI will automatically rebuild whenever conversations are modified.
  Stream<List<ConversationData>> watchAllConversations() => (select(
    conversations,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<int> createConversation(ConversationsCompanion entry) =>
      into(conversations).insert(entry);

  Future<void> deleteConversation(int id) =>
      (delete(conversations)..where((t) => t.id.equals(id))).go();

  Future<void> updateConversationTitle(int id, String title) =>
      (update(conversations)..where((t) => t.id.equals(id))).write(
        ConversationsCompanion(title: Value(title)),
      );

  Future<void> updateConversationTimestamp(int id, DateTime timestamp) =>
      (update(conversations)..where((t) => t.id.equals(id))).write(
        ConversationsCompanion(updatedAt: Value(timestamp)),
      );

  Future<void> pruneOldConversations(int maxCount) async {
    final allConvos = await (select(
      conversations,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
    if (allConvos.length > maxCount) {
      final convosToPrune = allConvos.sublist(maxCount);
      final idsToPrune = convosToPrune.map((c) => c.id).toList();
      await (delete(conversations)..where((t) => t.id.isIn(idsToPrune))).go();
    }
  }

  // --- Message Data Access Methods ---

  // WHY: This method provides a reactive stream for messages in a specific conversation.
  // The UI will automatically rebuild whenever messages in that conversation are modified.
  Stream<List<Message>> watchMessagesForConversation(int convId) {
    return (select(
      messages,
    )..where((t) => t.conversationId.equals(convId))).watch().map((rows) {
      return rows
          .map(
            (row) => Message(
              id: row.id,
              text: row.content,
              isFromUser: row.isFromUser,
              status: row.status,
            ),
          )
          .toList();
    });
  }

  // NOTE: This class uses both Manager API and Query Builder API intentionally:
  // - Manager API (managers.*): Used for simple CRUD operations on Messages (insertMessage,
  //   updateMessage, clearAllMessages). It provides a fluent, readable interface that's less
  //   error-prone for straightforward operations.
  // - Query Builder API (select, into, update, delete): Used for Conversations and complex
  //   queries (watchAllConversations, watchMessagesForConversation, pruneOldConversations).
  //   It offers more flexibility for filtering, ordering, and complex operations.
  // This mixed approach leverages the strengths of each API: Manager for simplicity,
  // Query Builder for flexibility and reactive streams.

  // WHY: The Manager API provides a fluent, readable, and less error-prone
  // interface for common CRUD operations compared to the standard query builder.
  Future<void> insertMessage(Message message, int conversationId) {
    return managers.messages.create(
      (o) => o(
        id: message.id,
        conversationId: conversationId,
        content: message.text,
        isFromUser: message.isFromUser,
        status: message.status,
      ),
    );
  }

  Future<void> updateMessage(Message message) {
    return managers.messages
        .filter((f) => f.id(message.id))
        .update(
          (o) => o(
            content: Value(message.text),
            status: Value(message.status),
          ),
        );
  }

  Future<void> clearAllMessages() => managers.messages.delete();
}
