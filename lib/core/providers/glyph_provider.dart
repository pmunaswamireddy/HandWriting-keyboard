import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/glyph_map.dart';
import 'profile_provider.dart';

// ── GlyphMap provider per profile ──

final glyphMapProvider =
    StreamProvider.family<GlyphMap, String>((ref, profileId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchGlyphsForProfile(profileId).map((rows) {
    final map = <String, String>{};
    for (final row in rows) {
      map[row.character] = row.svgPath;
    }
    return GlyphMap(profileId: profileId, glyphs: map);
  });
});

/// Glyph map for the currently active profile
final activeGlyphMapProvider = Provider<AsyncValue<GlyphMap>>((ref) {
  final profile = ref.watch(activeProfileProvider);
  if (profile == null) return const AsyncValue.data(GlyphMap(profileId: '', glyphs: {}));
  return ref.watch(glyphMapProvider(profile.id));
});

// ── Glyph service ──

final glyphServiceProvider = Provider((ref) => GlyphService(ref));

class GlyphService {
  final Ref _ref;
  GlyphService(this._ref);

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<void> saveGlyph({
    required String profileId,
    required String character,
    required String svgPath,
    String? strokesJson,
  }) async {
    await _db.upsertGlyph(GlyphsCompanion.insert(
      profileId: profileId,
      character: character,
      svgPath: svgPath,
      strokesJson: Value(strokesJson),
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> deleteGlyph({
    required String profileId,
    required String character,
  }) async {
    await _db.deleteGlyph(profileId, character);
  }

  Future<void> deleteAllGlyphs(String profileId) async {
    await _db.deleteAllGlyphsForProfile(profileId);
  }

  Future<void> saveGlyphBatch({
    required String profileId,
    required Map<String, String> glyphs,
  }) async {
    for (final entry in glyphs.entries) {
      await saveGlyph(
        profileId: profileId,
        character: entry.key,
        svgPath: entry.value,
      );
    }
  }
}
