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
  MessageStatus fromSql(String fromDb) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () =>
          MessageStatus.error, // Fallback to 'error' for unknown values
    );
  }

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
  // WHY: System prompt allows users to define persistent instructions that guide
  // AI behavior across an entire conversation, ensuring consistent tone and constraints.
  TextColumn get systemPrompt => text().nullable()();
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
  // WHY: Nullable providerId allows this table to represent both Presets (non-null)
  // and Groups (null). Groups act as organizational containers without provider-specific settings.
  TextColumn get providerId => text().nullable()();
  IntColumn get displayOrder => integer()();
  TextColumn get settingsJson => text()();
  // WHY: UI state flags allow users to customize the preset management interface,
  // pinning important presets and collapsing groups for better organization.
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isCollapsed => boolean().withDefault(const Constant(false))();
}

// WHY: LazyDatabase ensures the database connection is only opened when needed.
// This is important for platform-specific path resolution.
// Uses sqflite's getDatabasesPath() for mobile platforms, which provides the
// standard database directory on Android/iOS.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getDatabasesPath();
    final file = File(p.join(dbFolder, 'db.sqlite'));

    // TODO(felix): Remove this block for production; development convenience to wipe the database each launch.
    // WHY: Dev-only database reset ensures a clean slate for each launch during development.
    // ignore: avoid_slow_async_io
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
        // WHY: Migration from version 1 to 2 adds new columns to existing tables.
        // We use ALTER TABLE to add columns, which preserves existing data.
        if (from < 2) {
          // Add systemPrompt column to Conversations table
          await customStatement(
            'ALTER TABLE conversations ADD COLUMN system_prompt TEXT;',
          );
          // Add isPinned and isCollapsed columns to Presets table
          await customStatement(
            'ALTER TABLE presets ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0;',
          );
          await customStatement(
            'ALTER TABLE presets ADD COLUMN is_collapsed INTEGER NOT NULL DEFAULT 0;',
          );
          // Make providerId nullable in Presets table
          // WHY: SQLite doesn't support ALTER COLUMN directly, so we recreate the table.
          // This preserves existing data while allowing null values.
          await customStatement('''
            CREATE TABLE presets_new (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              provider_id TEXT,
              display_order INTEGER NOT NULL,
              settings_json TEXT NOT NULL,
              is_pinned INTEGER NOT NULL DEFAULT 0,
              is_collapsed INTEGER NOT NULL DEFAULT 0
            );
          ''');
          await customStatement('''
            INSERT INTO presets_new (id, name, provider_id, display_order, settings_json, is_pinned, is_collapsed)
            SELECT id, name, provider_id, display_order, settings_json, 0, 0 FROM presets;
          ''');
          await customStatement('DROP TABLE presets;');
          await customStatement('ALTER TABLE presets_new RENAME TO presets;');
        }
      },
      // WHY: Foreign keys must be explicitly enabled in SQLite for referential integrity.
      // This ensures cascade deletes work correctly and prevents orphaned records.
      beforeOpen: (OpeningDetails details) async {
        await customStatement('PRAGMA foreign_keys = ON');
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

  // WHY: This method allows updating the system prompt for a conversation,
  // enabling persistent instructions that guide AI behavior across turns.
  Future<void> updateConversationSystemPrompt(int id, String? systemPrompt) =>
      (update(conversations)..where((t) => t.id.equals(id))).write(
        ConversationsCompanion(systemPrompt: Value(systemPrompt)),
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

  // WHY: This query efficiently finds only the most recently updated conversation,
  // avoiding loading the entire history into memory during app startup.
  Future<ConversationData?> getMostRecentConversation() {
    return (select(conversations)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  // --- Message Data Access Methods ---

  // WHY: This method provides a reactive stream for messages in a specific conversation.
  // The UI will automatically rebuild whenever messages in that conversation are modified.
  Stream<List<MessageData>> watchMessagesForConversation(int convId) {
    return (select(
      messages,
    )..where((t) => t.conversationId.equals(convId))).watch();
  }

  // NOTE: This class uses both Manager API and Query Builder API intentionally:
  // - Manager API (managers.*): Used for simple CRUD operations on the Messages table.
  //   It provides a fluent, readable interface that's less error-prone for these operations.
  // - Query Builder API (select, into, update, delete): Used for Conversations, Presets,
  //   and complex queries (like reactive streams). It offers more flexibility for filtering,
  //   ordering, and advanced operations.
  // This mixed approach leverages the strengths of each API for its intended purpose.

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

  // WHY: Batch update of preset display orders ensures atomic reordering operations.
  // This is critical for maintaining UI consistency when users drag-and-drop presets.
  Future<void> updatePresetOrders(List<PresetsCompanion> updatedPresets) async {
    return transaction(() async {
      for (final preset in updatedPresets) {
        await (update(
          presets,
        )..where((p) => p.id.equals(preset.id.value))).write(preset);
      }
    });
  }
}
