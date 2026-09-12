import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../board/board_info.dart';

class LocalBoardCatalogStore {
  static const _boardsKey = 'nabu.boards.v1';
  static const _selectedBoardKey = 'nabu.board.selected.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<List<BoardInfo>> loadBoards() async {
    final raw = await _preferences.getString(_boardsKey);
    if (raw == null || raw.isEmpty) return <BoardInfo>[BoardInfo.mainBoard()];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final boards = decoded
        .map((entry) => BoardInfo.fromJson(
              Map<String, Object?>.from(entry as Map<dynamic, dynamic>),
            ))
        .toList();
    if (!boards.any((board) => board.id == 'main')) {
      boards.insert(0, BoardInfo.mainBoard());
    }
    return boards;
  }

  Future<void> saveBoards(List<BoardInfo> boards) async {
    await _preferences.setString(
      _boardsKey,
      jsonEncode(boards.map((board) => board.toJson()).toList()),
    );
  }

  Future<String> loadSelectedBoardId() async =>
      await _preferences.getString(_selectedBoardKey) ?? 'main';

  Future<void> saveSelectedBoardId(String id) =>
      _preferences.setString(_selectedBoardKey, id);
}
