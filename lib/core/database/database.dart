// lib/core/database/database.dart

import 'dart:io';

import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' show getDatabasesPath;

// Export ConversationData and PresetData from generated drift file for use in Riverpod providers
export 'database.drift.dart' show ConversationData, PresetData;

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
  // WHY: Timestamp column ensures reliable ordering of messages, independent of ID generation.
  // This is critical for _updateLastMessage which needs to find the most recent message.
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PresetData')
class Presets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get providerId => text()();
  IntColumn get displayOrder => integer()();
  TextColumn get settingsJson => text()();
}

// WHY: LazyDatabase ensures the database connection is only opened when needed.
// This is important for platform-specific path resolution.
// Uses sqflite's getDatabasesPath() for mobile platforms, which provides the
// standard database directory on Android/iOS.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getDatabasesPath();
    final file = File(p.join(dbFolder, 'db.sqlite'));

    // TODO: Remove this block for production. This is for development only
    // to wipe the database on every app start, avoiding migration complexity.
    if (await file.exists()) {
      await file.delete();
    }

    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [Conversations, Messages, Presets])
class AppDatabase extends _$AppDatabase {
  // WHY: This constructor uses sqflite's getDatabasesPath() for mobile platforms,
  // which provides the standard database directory on Android/iOS. The database
  // file will be stored in the platform's standard database location.
  AppDatabase() : super(_openConnection());

  // WHY: Test constructor that uses in-memory database for fast, isolated tests.
  AppDatabase.test() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 6;

  // WHY: A migration strategy is essential for any production application.
  // It ensures that when you change your database schema in future versions (e.g., add a new column),
  // existing users' data can be safely migrated without loss.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      // TODO: Implement a robust onUpgrade strategy for production release.
      // The current development setup wipes the DB on each start, so onUpgrade is never called.
      // WHY: Foreign keys must be explicitly enabled in SQLite for referential integrity.
      // This ensures cascade deletes work correctly and prevents orphaned records.
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');

        // WHY: Defensive check to ensure all presets have providerId values.
        // This handles edge cases where data might exist with null providerId.
        if (!details.wasCreated) {
          // Only check if database already existed (not a fresh install)
          try {
            final nullCount = await customSelect(
              'SELECT COUNT(*) as count FROM presets WHERE providerId IS NULL OR providerId = ""',
            ).getSingle();
            final count = nullCount.data['count'] as int;
            if (count > 0) {
              // Fix any presets with null or empty providerId
              await customStatement(
                "UPDATE presets SET providerId = 'ai_studio' WHERE providerId IS NULL OR providerId = ''",
              );
            }
          } on Object {
            // Ignore errors - table might not exist yet or other issues
          }
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
    // WHY: This query efficiently finds the IDs of the oldest conversations
    // exceeding the maxCount limit and deletes them in a single operation,
    // avoiding loading the full conversation list into Dart memory.
    final oldestIdsQuery = select(conversations)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(1000, offset: maxCount); // High limit to get all excess rows

    final oldestIds = await oldestIdsQuery.map((row) => row.id).get();

    if (oldestIds.isNotEmpty) {
      await (delete(conversations)..where((t) => t.id.isIn(oldestIds))).go();
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
        createdAt: Value(DateTime.now()),
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

  // --- Preset Data Access Methods ---

  Stream<List<PresetData>> watchAllPresets() => (select(
    presets,
  )..orderBy([(t) => OrderingTerm.asc(t.displayOrder)])).watch();

  Future<int> createPreset(PresetsCompanion entry) =>
      into(presets).insert(entry);

  Future<void> updatePreset(PresetsCompanion entry) =>
      update(presets).replace(entry);

  Future<void> deletePreset(int id) =>
      (delete(presets)..where((t) => t.id.equals(id))).go();
}
