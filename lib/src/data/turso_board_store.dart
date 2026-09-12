import 'dart:convert';
import 'dart:ui';

import 'package:libsql_dart/libsql_dart.dart';

import '../board/board_item.dart';
import 'board_store.dart';

class TursoBoardStore implements RemoteBoardStore {
  TursoBoardStore({required this.databaseUrl, required this.authToken});

  factory TursoBoardStore.fromEnvironment() => TursoBoardStore(
        databaseUrl: const String.fromEnvironment('TURSO_DATABASE_URL'),
        authToken: const String.fromEnvironment('TURSO_AUTH_TOKEN'),
      );

  static const boardId = 'main';
  final String databaseUrl;
  final String authToken;
  LibsqlClient? _client;

  @override
  bool get isConfigured => databaseUrl.isNotEmpty && authToken.isNotEmpty;

  LibsqlClient get client {
    final value = _client;
    if (value == null) throw StateError('Turso ainda não foi inicializado.');
    return value;
  }

  @override
  Future<void> initialize() async {
    if (!isConfigured || _client != null) return;
    final value = LibsqlClient.remote(databaseUrl, authToken: authToken);
    await value.connect();
    _client = value;
    await value.batch('''
      CREATE TABLE IF NOT EXISTS boards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS board_items (
        id TEXT PRIMARY KEY,
        board_id TEXT NOT NULL,
        type TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        width REAL NOT NULL,
        height REAL NOT NULL,
        rotation REAL NOT NULL DEFAULT 0,
        content_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY (board_id) REFERENCES boards(id)
      );
      CREATE INDEX IF NOT EXISTS idx_board_items_board_updated
        ON board_items(board_id, updated_at);
      INSERT OR IGNORE INTO boards(id, title, created_at, updated_at)
        VALUES ('main', 'Meu quadro', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
    ''');
  }

  @override
  Future<List<BoardItem>> loadItems() async {
    if (!isConfigured) return <BoardItem>[];
    final rows = await client.query('''
      SELECT id, type, x, y, width, height, rotation, content_json,
             created_at, updated_at
      FROM board_items
      WHERE board_id = 'main' AND deleted_at IS NULL
      ORDER BY updated_at
    ''');

    return rows.map((row) {
      final content = Map<String, Object?>.from(
        jsonDecode(row['content_json']! as String) as Map<dynamic, dynamic>,
      );
      return BoardItem(
        id: row['id']! as String,
        type: BoardItemType.values.byName(row['type']! as String),
        position: Offset(
          (row['x']! as num).toDouble(),
          (row['y']! as num).toDouble(),
        ),
        size: Size(
          (row['width']! as num).toDouble(),
          (row['height']! as num).toDouble(),
        ),
        rotation: (row['rotation']! as num).toDouble(),
        colorValue: (content['color']! as num).toInt(),
        text: (content['text'] as String?) ?? '',
        imageBase64: (content['imageBase64'] as String?) ?? '',
        imageMimeType:
            (content['imageMimeType'] as String?) ?? 'image/jpeg',
        createdAt: DateTime.parse(row['created_at']! as String),
        updatedAt: DateTime.parse(row['updated_at']! as String),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> upsertItem(BoardItem item) async {
    if (!isConfigured) return;
    final statement = await client.prepare('''
      INSERT INTO board_items(
        id, board_id, type, x, y, width, height, rotation,
        content_json, created_at, updated_at, deleted_at
      ) VALUES (?, 'main', ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
      ON CONFLICT(id) DO UPDATE SET
        type = excluded.type,
        x = excluded.x,
        y = excluded.y,
        width = excluded.width,
        height = excluded.height,
        rotation = excluded.rotation,
        content_json = excluded.content_json,
        updated_at = excluded.updated_at,
        deleted_at = NULL
    ''');
    await statement.query(positional: <Object?>[
      item.id,
      item.type.name,
      item.position.dx,
      item.position.dy,
      item.size.width,
      item.size.height,
      item.rotation,
      item.encodeContent(),
      item.createdAt.toUtc().toIso8601String(),
      item.updatedAt.toUtc().toIso8601String(),
    ]);
  }

  @override
  Future<void> deleteItem(String id) async {
    if (!isConfigured) return;
    final statement = await client.prepare('''
      UPDATE board_items SET deleted_at = ?, updated_at = ? WHERE id = ?
    ''');
    final now = DateTime.now().toUtc().toIso8601String();
    await statement.query(positional: <Object?>[now, now, id]);
  }

  @override
  Future<void> close() async {
    await _client?.dispose();
    _client = null;
  }
}
