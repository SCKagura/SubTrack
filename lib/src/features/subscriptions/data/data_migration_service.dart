/// DataMigrationService — Legacy Hive → Supabase
///
/// Previously migrated data from Hive (local DB) to Firestore.
/// Now that we're on Supabase, all data lives in PostgreSQL.
/// This class is a no-op stub to avoid breaking existing imports.
class DataMigrationService {
  /// Always returns false — no legacy Hive data to migrate.
  Future<bool> needsMigration() async => false;

  /// No-op: nothing to migrate when using Supabase.
  Future<void> migrate() async {}
}
