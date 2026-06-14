import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

// ────────────────────────────────────────────────
// Table definitions
// ────────────────────────────────────────────────

class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get avatarColor => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Glyphs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get character => text()();  // e.g. 'a', 'A', '1'
  TextColumn get svgPath => text()();    // SVG path data string
  TextColumn get strokesJson => text().nullable()(); // raw stroke points
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<String> get customConstraints =>
      ['UNIQUE(profile_id, character)'];
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ────────────────────────────────────────────────
// Database class
// ────────────────────────────────────────────────

@DriftDatabase(tables: [Profiles, Glyphs, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA busy_timeout = 5000;');
        },
      );

  // ── Profiles ──

  Future<List<Profile>> getAllProfiles() =>
      (select(profiles)..orderBy([(p) => OrderingTerm(expression: p.createdAt)])).get();

  Stream<List<Profile>> watchAllProfiles() =>
      (select(profiles)..orderBy([(p) => OrderingTerm(expression: p.createdAt)])).watch();

  Future<Profile?> getProfile(String id) =>
      (select(profiles)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertProfile(ProfilesCompanion entry) =>
      into(profiles).insert(entry);

  Future<bool> updateProfile(ProfilesCompanion entry) =>
      update(profiles).replace(entry);

  Future<int> deleteProfile(String id) =>
      (delete(profiles)..where((p) => p.id.equals(id))).go();

  // ── Glyphs ──

  Future<List<Glyph>> getGlyphsForProfile(String profileId) =>
      (select(glyphs)..where((g) => g.profileId.equals(profileId))).get();

  Stream<List<Glyph>> watchGlyphsForProfile(String profileId) =>
      (select(glyphs)..where((g) => g.profileId.equals(profileId))).watch();

  Future<Glyph?> getGlyph(String profileId, String character) =>
      (select(glyphs)
            ..where((g) =>
                g.profileId.equals(profileId) & g.character.equals(character)))
          .getSingleOrNull();

  Future<void> upsertGlyph(GlyphsCompanion entry) =>
      into(glyphs).insert(entry, mode: InsertMode.insertOrReplace);

  Future<int> deleteGlyph(String profileId, String character) =>
      (delete(glyphs)
            ..where((g) =>
                g.profileId.equals(profileId) & g.character.equals(character)))
          .go();

  Future<int> deleteAllGlyphsForProfile(String profileId) =>
      (delete(glyphs)..where((g) => g.profileId.equals(profileId))).go();

  // ── Settings ──

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value));
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'handwriting_keyboard_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}

// Provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override in main()');
});
