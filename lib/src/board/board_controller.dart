import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/board_store.dart';
import 'board_item.dart';

enum SyncState { localOnly, connecting, synced, error }

class BoardController extends ChangeNotifier {
  BoardController({required this.localStore, required this.remoteStore});

  final BoardStore localStore;
  final RemoteBoardStore remoteStore;
  final List<List<BoardItem>> _undo = <List<BoardItem>>[];
  final List<List<BoardItem>> _redo = <List<BoardItem>>[];
  final Map<String, Offset> _moveStarts = <String, Offset>{};
  List<BoardItem> _items = <BoardItem>[];
  String? _selectedId;
  SyncState _syncState = SyncState.localOnly;
  bool _loading = true;
  int _idCounter = 0;

  List<BoardItem> get items => List.unmodifiable(_items);
  String? get selectedId => _selectedId;
  SyncState get syncState => _syncState;
  bool get loading => _loading;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  Future<void> initialize() async {
    try {
      final local = await localStore.loadItems();
      _items = local.isEmpty ? _starterItems() : local;
      _loading = false;
      notifyListeners();
      if (!remoteStore.isConfigured) {
        await _persistLocal();
        return;
      }

      _syncState = SyncState.connecting;
      notifyListeners();
      await remoteStore.initialize();
      final remote = await remoteStore.loadItems();
      if (remote.isNotEmpty) {
        _items = _mergeNewest(_items, remote);
      } else {
        for (final item in _items) {
          await remoteStore.upsertItem(item);
        }
      }
      await _persistLocal();
      _syncState = SyncState.synced;
    } catch (_) {
      _syncState = SyncState.error;
      _loading = false;
    }
    notifyListeners();
  }

  void select(String? id) {
    _selectedId = id;
    notifyListeners();
  }

  void addItem(BoardItemType type, Offset worldPosition) {
    _checkpoint();
    final now = DateTime.now().toUtc();
    final palette = <int>[
      0xffffe68a,
      0xffffb8d1,
      0xffa8ddff,
      0xffc5efad,
    ];
    final item = BoardItem(
      id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
      type: type,
      position: worldPosition,
      size: switch (type) {
        BoardItemType.stickyNote => const Size(210, 180),
        BoardItemType.text => const Size(240, 90),
        BoardItemType.rectangle => const Size(220, 120),
        BoardItemType.circle => const Size(150, 150),
        BoardItemType.image => const Size(320, 220),
      },
      colorValue: palette[_items.length % palette.length],
      text: switch (type) {
        BoardItemType.stickyNote => 'Nova ideia',
        BoardItemType.text => 'Digite seu texto',
        BoardItemType.rectangle => 'Etapa',
        BoardItemType.circle => 'Tema',
        BoardItemType.image => '',
      },
      createdAt: now,
      updatedAt: now,
    );
    _items = <BoardItem>[..._items, item];
    _selectedId = item.id;
    _changed(item);
  }

  void addImage(
    Uint8List bytes,
    Offset worldPosition, {
    String mimeType = 'image/jpeg',
  }) {
    _checkpoint();
    final now = DateTime.now().toUtc();
    final item = BoardItem(
      id: '${now.microsecondsSinceEpoch}-${_idCounter++}',
      type: BoardItemType.image,
      position: worldPosition,
      size: const Size(320, 220),
      colorValue: 0xffffffff,
      imageBase64: base64Encode(bytes),
      imageMimeType: mimeType,
      createdAt: now,
      updatedAt: now,
    );
    _items = <BoardItem>[..._items, item];
    _selectedId = item.id;
    _changed(item);
  }

  void beginMove(String id) {
    final item = _itemById(id);
    if (item != null) _moveStarts[id] = item.position;
  }

  void moveBy(String id, Offset worldDelta) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(
      position: _items[index].position + worldDelta,
      updatedAt: DateTime.now().toUtc(),
    );
    notifyListeners();
  }

  void endMove(String id) {
    final start = _moveStarts.remove(id);
    final item = _itemById(id);
    if (start == null || item == null || start == item.position) return;
    final before = _copyItems();
    final index = before.indexWhere((value) => value.id == id);
    before[index] = before[index].copyWith(position: start);
    _undo.add(before);
    _trimHistory();
    _redo.clear();
    _changed(item);
  }

  void updateText(String id, String text) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].text == text) return;
    _checkpoint();
    _items[index] = _items[index].copyWith(
      text: text,
      updatedAt: DateTime.now().toUtc(),
    );
    _changed(_items[index]);
  }

  void deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    _checkpoint();
    _items = _items.where((item) => item.id != id).toList();
    _selectedId = null;
    unawaited(_persistLocal());
    unawaited(_deleteRemote(id));
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_copyItems());
    _items = _undo.removeLast();
    _selectedId = null;
    _persistSnapshot();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_copyItems());
    _items = _redo.removeLast();
    _selectedId = null;
    _persistSnapshot();
  }

  void _checkpoint() {
    _undo.add(_copyItems());
    _trimHistory();
    _redo.clear();
  }

  void _trimHistory() {
    if (_undo.length > 50) _undo.removeAt(0);
  }

  List<BoardItem> _copyItems() => List<BoardItem>.of(_items);

  BoardItem? _itemById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _changed(BoardItem item) {
    unawaited(_persistLocal());
    unawaited(_upsertRemote(item));
    notifyListeners();
  }

  void _persistSnapshot() {
    unawaited(_persistLocal());
    if (remoteStore.isConfigured) {
      for (final item in _items) {
        unawaited(_upsertRemote(item));
      }
    }
    notifyListeners();
  }

  Future<void> _persistLocal() => localStore.saveItems(_items);

  Future<void> _upsertRemote(BoardItem item) async {
    if (!remoteStore.isConfigured) return;
    try {
      await remoteStore.upsertItem(item);
      _syncState = SyncState.synced;
    } catch (_) {
      _syncState = SyncState.error;
    }
    notifyListeners();
  }

  Future<void> _deleteRemote(String id) async {
    if (!remoteStore.isConfigured) return;
    try {
      await remoteStore.deleteItem(id);
      _syncState = SyncState.synced;
    } catch (_) {
      _syncState = SyncState.error;
    }
    notifyListeners();
  }

  static List<BoardItem> _mergeNewest(
    List<BoardItem> local,
    List<BoardItem> remote,
  ) {
    final merged = <String, BoardItem>{};
    for (final item in <BoardItem>[...local, ...remote]) {
      final current = merged[item.id];
      if (current == null || item.updatedAt.isAfter(current.updatedAt)) {
        merged[item.id] = item;
      }
    }
    return merged.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static List<BoardItem> _starterItems() {
    final now = DateTime.now().toUtc();
    BoardItem item(
      String id,
      BoardItemType type,
      double x,
      double y,
      double width,
      double height,
      int color,
      String text,
    ) =>
        BoardItem(
          id: id,
          type: type,
          position: Offset(x, y),
          size: Size(width, height),
          colorValue: color,
          text: text,
          createdAt: now,
          updatedAt: now,
        );

    return <BoardItem>[
      item('welcome-1', BoardItemType.stickyNote, -330, -130, 210, 180,
          0xffffe68a, 'Este é o Nabu: um espaço livre para suas ideias.'),
      item('welcome-2', BoardItemType.stickyNote, -75, -130, 210, 180,
          0xffffb8d1, 'Mova cartões, aplique zoom e organize seus projetos.'),
      item('welcome-3', BoardItemType.stickyNote, 180, -130, 210, 180,
          0xffa8ddff, 'Crie textos, formas e conexões entre pensamentos.'),
      item('flow-1', BoardItemType.rectangle, -270, 150, 220, 110,
          0xffc9bcff, 'Planejamento'),
      item('flow-2', BoardItemType.circle, 130, 140, 150, 150, 0xffffe998,
          'Ideia?'),
      item('flow-3', BoardItemType.rectangle, 430, 150, 220, 110,
          0xffc9bcff, 'Transformar em ação!'),
    ];
  }

  @override
  void dispose() {
    unawaited(remoteStore.close());
    super.dispose();
  }
}
