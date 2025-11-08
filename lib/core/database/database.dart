// lib/core/database/database.dart

import 'dart:io';

import 'package:ai_hybrid_hub/features/hub/models/message.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
    final file = File('${dbFolder.path}/db.sqlite');
    return NativeDatabase.createInBackground(file);
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

  // WHY: This method safely reads conversations by catching FormatException
  // when parsing corrupted DateTime values. It uses raw SQL to read date strings
  // first, then manually parses them, allowing us to handle corrupted data gracefully.
  Future<List<ConversationData>> safeReadConversations() async {
    final results = await customSelect(
      'SELECT id, title, created_at, updated_at FROM conversations ORDER BY updated_at DESC',
      readsFrom: {conversations},
    ).get();

    final validConversations = <ConversationData>[];
    final now = DateTime.now();

    for (final row in results) {
      try {
        final id = row.read<int>('id');
        final title = row.read<String>('title');
        final createdAtStr = row.read<String>('created_at');
        final updatedAtStr = row.read<String>('updated_at');

        DateTime? createdAt;
        DateTime? updatedAt;

        // Try to parse createdAt
        try {
          createdAt = _parseDateTime(createdAtStr);
        } on FormatException {
          // If parsing fails, use current time as fallback
          createdAt = now;
        }

        // Try to parse updatedAt
        try {
          updatedAt = _parseDateTime(updatedAtStr);
        } on FormatException {
          // If parsing fails, use current time as fallback
          updatedAt = now;
        }

        validConversations.add(
          ConversationData(
            id: id,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
      } on Exception {
        // Skip corrupted records entirely if we can't even read basic fields
        continue;
      }
    }

    return validConversations;
  }

  // WHY: This helper method attempts to parse DateTime strings, handling
  // corrupted formats like Unix timestamps with 'Z' suffix (e.g., "1762611824Z").
  DateTime _parseDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      throw const FormatException('Empty date string');
    }

    // Try standard ISO 8601 parsing first
    try {
      return DateTime.parse(dateStr);
    } on FormatException {
      // Handle corrupted Unix timestamp format (e.g., "1762611824Z")
      final cleaned = dateStr.replaceAll(RegExp('[^0-9]'), '');
      if (cleaned.isNotEmpty) {
        try {
          final timestamp = int.tryParse(cleaned);
          if (timestamp != null) {
            // Assume seconds if < year 2100, milliseconds otherwise
            if (timestamp < 4102444800) {
              // Less than year 2100 in seconds
              return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
            } else {
              // Likely milliseconds
              return DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
          }
        } on FormatException {
          // Fall through to throw FormatException
        }
      }
      throw FormatException('Invalid date format', dateStr);
    }
  }

  // WHY: This method cleans up corrupted DateTime values in the database.
  // It finds conversations with invalid date formats and fixes them by
  // converting them to proper DateTime values.
  Future<int> cleanupCorruptedDates() async {
    final results = await customSelect(
      'SELECT id, created_at, updated_at FROM conversations',
      readsFrom: {conversations},
    ).get();

    var fixedCount = 0;
    final now = DateTime.now();

    for (final row in results) {
      final id = row.read<int>('id');
      final createdAtStr = row.read<String>('created_at');
      final updatedAtStr = row.read<String>('updated_at');

      DateTime? fixedCreatedAt;
      DateTime? fixedUpdatedAt;
      var needsUpdate = false;

      // Check and fix createdAt
      try {
        fixedCreatedAt = _parseDateTime(createdAtStr);
      } on FormatException {
        fixedCreatedAt = now;
        needsUpdate = true;
      }

      // Check and fix updatedAt
      try {
        fixedUpdatedAt = _parseDateTime(updatedAtStr);
      } on FormatException {
        fixedUpdatedAt = now;
        needsUpdate = true;
      }

      // Update the record if it was corrupted
      if (needsUpdate) {
        await (update(conversations)..where((t) => t.id.equals(id))).write(
          ConversationsCompanion(
            createdAt: Value(fixedCreatedAt),
            updatedAt: Value(fixedUpdatedAt),
          ),
        );
        fixedCount++;
      }
    }

    return fixedCount;
  }

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
