import 'dart:typed_data';

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

  test('adiciona imagem ao quadro', () async {
    final controller = BoardController(
      localStore: MemoryLocalStore(),
      remoteStore: DisabledRemoteStore(),
    );
    await controller.initialize();

    controller.addImage(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      const Offset(30, 40),
      mimeType: 'image/png',
    );

    final image = controller.items.last;
    expect(image.type, BoardItemType.image);
    expect(image.imageBase64, 'AQIDBA==');
    expect(image.imageMimeType, 'image/png');
  });

  test('item ancorado não se move até ser liberado', () async {
    final controller = BoardController(
      localStore: MemoryLocalStore(),
      remoteStore: DisabledRemoteStore(),
    );
    await controller.initialize();
    final item = controller.items.first;

    controller.toggleLock(item.id);
    controller.beginMove(item.id);
    controller.moveBy(item.id, const Offset(50, 20));
    controller.endMove(item.id);

    expect(controller.items.first.isLocked, isTrue);
    expect(controller.items.first.position, item.position);

    controller.toggleLock(item.id);
    controller.beginMove(item.id);
    controller.moveBy(item.id, const Offset(50, 20));
    controller.endMove(item.id);

    expect(
      controller.items.first.position,
      item.position + const Offset(50, 20),
    );
  });

  test('alterna imagem entre paisagem e retrato mantendo o centro', () async {
    final controller = BoardController(
      localStore: MemoryLocalStore(),
      remoteStore: DisabledRemoteStore(),
    );
    await controller.initialize();
    controller.addImage(
      Uint8List.fromList(<int>[1, 2, 3, 4]),
      const Offset(30, 40),
    );
    final before = controller.items.last;
    final centerBefore = before.position +
        Offset(before.size.width / 2, before.size.height / 2);

    controller.toggleImageOrientation(before.id);
    final after = controller.items.last;
    final centerAfter =
        after.position + Offset(after.size.width / 2, after.size.height / 2);

    expect(after.size, const Size(220, 320));
    expect(centerAfter, centerBefore);
  });
}
