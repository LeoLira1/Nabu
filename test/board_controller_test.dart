import 'package:flutter_test/flutter_test.dart';
import 'package:nabu/src/board/board_controller.dart';
import 'package:nabu/src/board/board_item.dart';
import 'package:nabu/src/data/board_store.dart';

class MemoryLocalStore implements BoardStore {
  List<BoardItem> data = <BoardItem>[];

  @override
  Future<List<BoardItem>> loadItems() async => List<BoardItem>.of(data);

  @override
  Future<void> saveItems(List<BoardItem> items) async {
    data = List<BoardItem>.of(items);
  }
}

class DisabledRemoteStore implements RemoteBoardStore {
  @override
  bool get isConfigured => false;
  @override
  Future<void> close() async {}
  @override
  Future<void> deleteItem(String id) async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<List<BoardItem>> loadItems() async => <BoardItem>[];
  @override
  Future<void> upsertItem(BoardItem item) async {}
}

void main() {
  test('adiciona item e desfaz a operação', () async {
    final controller = BoardController(
      localStore: MemoryLocalStore(),
      remoteStore: DisabledRemoteStore(),
    );
    await controller.initialize();
    final initialCount = controller.items.length;

    controller.addItem(BoardItemType.stickyNote, const Offset(10, 20));
    expect(controller.items, hasLength(initialCount + 1));

    controller.undo();
    expect(controller.items, hasLength(initialCount));
  });
}
