import 'database_client.dart';

class DatabaseMigrator {
  final DatabaseClient _db;

  const DatabaseMigrator(this._db);

  static const String initialSchemaSql = '''
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL CHECK (char_length(trim(email)) > 0),
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (lower(email));

CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash TEXT UNIQUE NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON sessions (token_hash);

CREATE TABLE IF NOT EXISTS items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(60) NOT NULL CHECK (char_length(trim(name)) > 0 AND char_length(name) <= 60),
  description VARCHAR(200) NOT NULL CHECK (char_length(trim(description)) > 0 AND char_length(description) <= 200),
  location TEXT NOT NULL CHECK (char_length(trim(location)) > 0),
  status VARCHAR(10) NOT NULL CHECK (status IN ('lost', 'found')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_items_created_at_desc ON items (created_at DESC);
''';

  Future<void> runMigrations() async {
    await _db.execute(initialSchemaSql);
  }
}
