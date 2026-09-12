import 'package:flutter_test/flutter_test.dart';
import 'package:nabu/src/board/board_info.dart';

void main() {
  test('serializa e restaura os dados de um quadro', () {
    final created = DateTime.utc(2026, 9, 12, 10);
    final board = BoardInfo(
      id: 'livros',
      title: 'Livros e leituras',
      createdAt: created,
      updatedAt: created.add(const Duration(minutes: 5)),
    );

    final restored = BoardInfo.fromJson(board.toJson());

    expect(restored.id, board.id);
    expect(restored.title, board.title);
    expect(restored.createdAt, board.createdAt);
    expect(restored.updatedAt, board.updatedAt);
  });
}
