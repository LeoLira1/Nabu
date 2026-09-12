import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nabu/src/board/board_item.dart';

void main() {
  test('BoardItem preserva os dados ao serializar e restaurar', () {
    final item = BoardItem(
      id: 'item-1',
      type: BoardItemType.stickyNote,
      position: const Offset(-125.5, 840.25),
      size: const Size(210, 180),
      colorValue: 0xffffe68a,
      text: 'Uma ideia',
      rotation: .03,
      createdAt: DateTime.utc(2026, 9, 12),
      updatedAt: DateTime.utc(2026, 9, 12, 15),
    );

    final restored = BoardItem.fromJson(item.toJson());

    expect(restored.id, item.id);
    expect(restored.type, item.type);
    expect(restored.position, item.position);
    expect(restored.size, item.size);
    expect(restored.colorValue, item.colorValue);
    expect(restored.text, item.text);
    expect(restored.rotation, item.rotation);
    expect(restored.createdAt, item.createdAt);
    expect(restored.updatedAt, item.updatedAt);
  });
}

