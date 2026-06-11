import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart' hide Profile;
import '../models/profile.dart';
import '../models/glyph_map.dart';

// ── Profile providers ──

final profilesProvider = StreamProvider<List<Profile>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllProfiles().map(
        (rows) => rows
            .map((r) => Profile(
                  id: r.id,
                  name: r.name,
                  avatarColor: r.avatarColor,
                  createdAt: r.createdAt,
                  updatedAt: r.updatedAt,
                ))
            .toList(),
      );
});

class ActiveProfileIdNotifier extends StateNotifier<String?> {
  final AppDatabase _db;

  ActiveProfileIdNotifier(this._db) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _db.getSetting('active_profile_id');
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setActiveProfile(String? id) async {
    state = id;
    if (id != null) {
      await _db.setSetting('active_profile_id', id);
    } else {
      await _db.setSetting('active_profile_id', '');
    }
  }
}

final activeProfileIdProvider =
    StateNotifierProvider<ActiveProfileIdNotifier, String?>((ref) {
  return ActiveProfileIdNotifier(ref.watch(appDatabaseProvider));
});

final activeProfileProvider = Provider<Profile?>((ref) {
  final id = ref.watch(activeProfileIdProvider);
  final profiles = ref.watch(profilesProvider).valueOrNull ?? [];
  if (id == null && profiles.isNotEmpty) return profiles.first;
  return profiles.where((p) => p.id == id).firstOrNull;
});

// ── Profile service actions ──

final profileServiceProvider = Provider((ref) => ProfileService(ref));

class ProfileService {
  final Ref _ref;
  final _uuid = const Uuid();

  ProfileService(this._ref);

  AppDatabase get _db => _ref.read(appDatabaseProvider);

  Future<Profile> createProfile({
    required String name,
    required int avatarColor,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.insertProfile(ProfilesCompanion.insert(
      id: id,
      name: name,
      avatarColor: avatarColor,
      createdAt: now,
      updatedAt: now,
    ));
    return Profile(
      id: id,
      name: name,
      avatarColor: avatarColor,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> updateProfile(Profile profile) async {
    await _db.updateProfile(ProfilesCompanion(
      id: Value(profile.id),
      name: Value(profile.name),
      avatarColor: Value(profile.avatarColor),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> deleteProfile(String id) async {
    await _db.deleteAllGlyphsForProfile(id);
    await _db.deleteProfile(id);
  }

  void setActiveProfile(String? id) {
    _ref.read(activeProfileIdProvider.notifier).setActiveProfile(id);
  }
}
