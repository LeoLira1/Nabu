PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS boards (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS board_items (
  id TEXT PRIMARY KEY,
  board_id TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN (
    'stickyNote', 'text', 'rectangle', 'circle', 'image', 'arrow', 'symbol'
  )),
  x REAL NOT NULL,
  y REAL NOT NULL,
  width REAL NOT NULL CHECK (width > 0),
  height REAL NOT NULL CHECK (height > 0),
  rotation REAL NOT NULL DEFAULT 0,
  content_json TEXT NOT NULL CHECK (json_valid(content_json)),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY (board_id) REFERENCES boards(id)
);

CREATE INDEX IF NOT EXISTS idx_board_items_board_updated
  ON board_items(board_id, updated_at);

INSERT OR IGNORE INTO boards(id, title, created_at, updated_at)
VALUES ('main', 'Meu quadro', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
