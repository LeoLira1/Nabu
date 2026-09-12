import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../board/board_item.dart';
import 'board_store.dart';

class LocalBoardStore implements BoardStore {
  static const _itemsKey = 'nabu.board.main.items.v1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<List<BoardItem>> loadItems() async {
    final raw = await _preferences.getString(_itemsKey);
    if (raw == null || raw.isEmpty) return <BoardItem>[];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => BoardItem.fromJson(
              Map<String, Object?>.from(entry as Map<dynamic, dynamic>),
            ))
        .toList(growable: false);
  }

  @override
  Future<void> saveItems(List<BoardItem> items) async {
    final raw = jsonEncode(items.map((item) => item.toJson()).toList());
    await _preferences.setString(_itemsKey, raw);
  }
}

