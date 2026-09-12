import 'package:flutter/material.dart';

import 'board/board_controller.dart';
import 'board/board_info.dart';
import 'board/board_screen.dart';
import 'data/local_board_catalog_store.dart';
import 'data/local_board_store.dart';
import 'data/turso_board_store.dart';
import 'data/turso_settings_store.dart';

class NabuApp extends StatefulWidget {
  const NabuApp({super.key});

  @override
  State<NabuApp> createState() => _NabuAppState();
}

class _NabuAppState extends State<NabuApp> {
  final TursoSettingsStore _settingsStore = TursoSettingsStore();
  final LocalBoardCatalogStore _catalogStore = LocalBoardCatalogStore();
  BoardController? _controller;
  List<BoardInfo> _boards = <BoardInfo>[BoardInfo.mainBoard()];
  String _selectedBoardId = 'main';
  TursoSettings _settings = const TursoSettings(
    databaseUrl: TursoSettings.defaultDatabaseUrl,
    authToken: '',
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var localBoards = await _catalogStore.loadBoards();
    final savedBoardId = await _catalogStore.loadSelectedBoardId();
    final stored = await _settingsStore.load();
    const environmentUrl = String.fromEnvironment('TURSO_DATABASE_URL');
    const environmentToken = String.fromEnvironment('TURSO_AUTH_TOKEN');
    final resolved = TursoSettings(
      databaseUrl: stored.databaseUrl.isNotEmpty
          ? stored.databaseUrl
          : environmentUrl.isNotEmpty
              ? environmentUrl
              : TursoSettings.defaultDatabaseUrl,
      authToken:
          stored.authToken.isNotEmpty ? stored.authToken : environmentToken,
    );
    if (resolved.isConfigured) {
      localBoards = await _syncBoardCatalog(resolved, localBoards);
    }
    _boards = localBoards;
    _selectedBoardId = localBoards.any((board) => board.id == savedBoardId)
        ? savedBoardId
        : 'main';
    await _catalogStore.saveBoards(localBoards);
    await _replaceController(resolved);
  }

  Future<void> _replaceController(TursoSettings settings) async {
    final board = _selectedBoard;
    final next = BoardController(
      localStore: LocalBoardStore(boardId: board.id),
      remoteStore: TursoBoardStore(
        databaseUrl: settings.databaseUrl,
        authToken: settings.authToken,
        boardId: board.id,
        boardTitle: board.title,
      ),
      showStarterItems: board.id == 'main',
    );
    await next.initialize();
    if (!mounted) {
      next.dispose();
      return;
    }
    final previous = _controller;
    setState(() {
      _settings = settings;
      _controller = next;
    });
    previous?.dispose();
  }

  BoardInfo get _selectedBoard => _boards.firstWhere(
        (board) => board.id == _selectedBoardId,
        orElse: BoardInfo.mainBoard,
      );

  static List<BoardInfo> _mergeBoards(
    List<BoardInfo> local,
    List<BoardInfo> remote,
  ) {
    final merged = <String, BoardInfo>{};
    for (final board in <BoardInfo>[...local, ...remote]) {
      final current = merged[board.id];
      if (current == null || board.updatedAt.isAfter(current.updatedAt)) {
        merged[board.id] = board;
      }
    }
    if (!merged.containsKey('main')) merged['main'] = BoardInfo.mainBoard();
    return merged.values.toList()
      ..sort((a, b) {
        if (a.id == 'main') return -1;
        if (b.id == 'main') return 1;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  }

  Future<List<BoardInfo>> _syncBoardCatalog(
    TursoSettings settings,
    List<BoardInfo> local,
  ) async {
    final selected = local.firstWhere(
      (board) => board.id == _selectedBoardId,
      orElse: BoardInfo.mainBoard,
    );
    final store = TursoBoardStore(
      databaseUrl: settings.databaseUrl,
      authToken: settings.authToken,
      boardId: selected.id,
      boardTitle: selected.title,
    );
    try {
      await store.initialize();
      final merged = _mergeBoards(local, await store.loadBoards());
      for (final board in merged) {
        await store.upsertBoard(board);
      }
      return merged;
    } catch (_) {
      return local;
    } finally {
      await store.close();
    }
  }

  Future<void> _switchBoard(String id) async {
    if (id == _selectedBoardId) return;
    _selectedBoardId = id;
    await _catalogStore.saveSelectedBoardId(id);
    await _replaceController(_settings);
  }

  Future<String?> _askBoardName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) async {
    final textController = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Nome do quadro',
            hintText: 'Ex.: Livros e leituras',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = textController.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    textController.dispose();
    return result;
  }

  Future<void> _createBoard(BuildContext context) async {
    final title = await _askBoardName(context, title: 'Novo quadro');
    if (title == null || !mounted) return;
    final now = DateTime.now().toUtc();
    final board = BoardInfo(
      id: 'board-${now.microsecondsSinceEpoch}',
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    setState(() => _boards = _mergeBoards(_boards, <BoardInfo>[board]));
    await _catalogStore.saveBoards(_boards);
    if (_settings.isConfigured) {
      await _saveBoardRemote(board);
    }
    await _switchBoard(board.id);
  }

  Future<void> _renameBoard(BuildContext context, BoardInfo board) async {
    final title = await _askBoardName(
      context,
      title: 'Renomear quadro',
      initial: board.title,
    );
    if (title == null || title == board.title || !mounted) return;
    final updated = board.copyWith(
      title: title,
      updatedAt: DateTime.now().toUtc(),
    );
    setState(() {
      _boards = _boards
          .map((value) => value.id == updated.id ? updated : value)
          .toList();
    });
    await _catalogStore.saveBoards(_boards);
    if (_settings.isConfigured) await _saveBoardRemote(updated);
  }

  Future<void> _saveBoardRemote(BoardInfo board) async {
    final store = TursoBoardStore(
      databaseUrl: _settings.databaseUrl,
      authToken: _settings.authToken,
      boardId: board.id,
      boardTitle: board.title,
    );
    try {
      await store.initialize();
      await store.upsertBoard(board);
    } catch (_) {
      // O catálogo local continua disponível e será reenviado no próximo sync.
    } finally {
      await store.close();
    }
  }

  Future<void> _openBoardPicker(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ListTile(
              leading: Icon(Icons.dashboard_outlined),
              title: Text(
                'Meus quadros',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView(
                shrinkWrap: true,
                children: _boards
                    .map((board) => ListTile(
                          leading: Icon(
                            board.id == _selectedBoardId
                                ? Icons.check_circle_rounded
                                : Icons.dashboard_outlined,
                          ),
                          title: Text(board.title),
                          onTap: () => Navigator.pop(context, board.id),
                          trailing: IconButton(
                            tooltip: 'Renomear',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                Navigator.pop(context, 'rename:${board.id}'),
                          ),
                        ))
                    .toList(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Criar novo quadro'),
              onTap: () => Navigator.pop(context, 'create'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'create') {
      await _createBoard(context);
    } else if (action.startsWith('rename:')) {
      final id = action.substring('rename:'.length);
      final board = _boards.firstWhere((value) => value.id == id);
      await _renameBoard(context, board);
    } else {
      await _switchBoard(action);
    }
  }

  Future<void> _syncNow(BuildContext context) async {
    final controller = _controller;
    if (controller == null) return;
    final itemsSynced = await controller.syncNow();
    if (_settings.isConfigured) {
      final boards = await _syncBoardCatalog(_settings, _boards);
      if (mounted) {
        setState(() => _boards = boards);
        await _catalogStore.saveBoards(boards);
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          itemsSynced
              ? 'Quadro sincronizado com o Turso.'
              : 'Não foi possível sincronizar. Confira a conexão.',
        ),
      ),
    );
  }

  Future<void> _openSettings(BuildContext pageContext) async {
    final result = await showDialog<TursoSettings>(
      context: pageContext,
      builder: (_) => _TursoSettingsDialog(initial: _settings),
    );
    if (result == null) return;

    await _settingsStore.save(result);
    _boards = await _syncBoardCatalog(result, _boards);
    await _catalogStore.saveBoards(_boards);
    await _replaceController(result);
    if (!pageContext.mounted) return;
    final synced = _controller?.syncState == SyncState.synced;
    ScaffoldMessenger.of(pageContext).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Turso conectado e tabelas verificadas.'
              : 'Configuração salva. Não foi possível sincronizar agora.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nabu',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff16a394),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7f8fa),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (pageContext) {
          final controller = _controller;
          if (controller == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return BoardScreen(
            key: ValueKey(_selectedBoardId),
            controller: controller,
            boardTitle: _selectedBoard.title,
            onBoards: () => _openBoardPicker(pageContext),
            onSync: () => _syncNow(pageContext),
            onSettings: () => _openSettings(pageContext),
          );
        },
      ),
    );
  }
}

class _TursoSettingsDialog extends StatefulWidget {
  const _TursoSettingsDialog({required this.initial});

  final TursoSettings initial;

  @override
  State<_TursoSettingsDialog> createState() => _TursoSettingsDialogState();
}

class _TursoSettingsDialogState extends State<_TursoSettingsDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;
  bool _obscureToken = true;
  bool _testing = false;
  String? _feedback;
  bool _testSucceeded = false;

  TursoSettings get _value => TursoSettings(
        databaseUrl: _urlController.text.trim(),
        authToken: _tokenController.text.trim(),
      );

  bool _hasValidDatabaseUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'libsql' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  String _connectionErrorMessage(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('401') ||
        message.contains('403') ||
        message.contains('unauthorized') ||
        message.contains('authentication') ||
        message.contains('jwt')) {
      return 'O Turso recusou o token. Gere ou copie um token válido.';
    }
    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('host lookup') ||
        message.contains('connection')) {
      return 'Não foi possível acessar o Turso. Confira sua internet e tente novamente.';
    }
    return 'Não foi possível conectar ao Turso (${error.runtimeType}).';
  }

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initial.databaseUrl);
    _tokenController = TextEditingController(text: widget.initial.authToken);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final settings = _value;
    if (!settings.isConfigured) {
      setState(() {
        _testSucceeded = false;
        _feedback = 'Informe a URL e o token do banco.';
      });
      return;
    }
    if (!_hasValidDatabaseUrl(settings.databaseUrl)) {
      setState(() {
        _testSucceeded = false;
        _feedback =
            'URL inválida. Use o endereço libsql:// exibido pelo Turso.';
      });
      return;
    }
    setState(() {
      _testing = true;
      _feedback = null;
    });
    final store = TursoBoardStore(
      databaseUrl: settings.databaseUrl,
      authToken: settings.authToken,
    );
    try {
      await store.initialize();
      await store.close();
      if (!mounted) return;
      setState(() {
        _testSucceeded = true;
        _feedback = 'Conexão realizada. As tabelas do Nabu estão prontas.';
      });
    } catch (error) {
      await store.close();
      if (!mounted) return;
      setState(() {
        _testSucceeded = false;
        _feedback = _connectionErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.cloud_outlined),
          SizedBox(width: 10),
          Text('Configurar Turso'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Conecte o quadro ao banco online. O token fica guardado no armazenamento seguro do aparelho.',
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'URL do banco',
                  hintText: 'libsql://seu-banco.turso.io',
                  prefixIcon: Icon(Icons.link_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _tokenController,
                obscureText: _obscureToken,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Token de autenticação',
                  prefixIcon: const Icon(Icons.key_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                    tooltip: _obscureToken ? 'Mostrar token' : 'Ocultar token',
                    icon: Icon(
                      _obscureToken
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_feedback != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _feedback!,
                  style: TextStyle(
                    color: _testSucceeded
                        ? const Color(0xff087f5b)
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _testing ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        OutlinedButton.icon(
          onPressed: _testing ? null : _testConnection,
          icon: _testing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering_rounded),
          label: const Text('Testar conexão'),
        ),
        FilledButton(
          onPressed: _testing || !_testSucceeded
              ? null
              : () => Navigator.pop(context, _value),
          child: const Text('Salvar e conectar'),
        ),
      ],
    );
  }
}
