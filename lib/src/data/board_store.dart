import '../board/board_item.dart';

abstract interface class BoardStore {
  Future<List<BoardItem>> loadItems();
  Future<void> saveItems(List<BoardItem> items);
}

abstract interface class RemoteBoardStore {
  bool get isConfigured;
  Future<void> initialize();
  Future<List<BoardItem>> loadItems();
  Future<void> upsertItem(BoardItem item);
  Future<void> deleteItem(String id);
  Future<void> close();
}

