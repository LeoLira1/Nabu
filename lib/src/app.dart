import 'package:flutter/material.dart';

import 'board/board_controller.dart';
import 'board/board_screen.dart';
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
  BoardController? _controller;
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
    await _replaceController(resolved);
  }

  Future<void> _replaceController(TursoSettings settings) async {
    final next = BoardController(
      localStore: LocalBoardStore(),
      remoteStore: TursoBoardStore(
        databaseUrl: settings.databaseUrl,
        authToken: settings.authToken,
      ),
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

  Future<void> _openSettings(BuildContext pageContext) async {
    final result = await showDialog<TursoSettings>(
      context: pageContext,
      builder: (_) => _TursoSettingsDialog(initial: _settings),
    );
    if (result == null) return;

    await _settingsStore.save(result);
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
            controller: controller,
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
    } catch (_) {
      await store.close();
      if (!mounted) return;
      setState(() {
        _testSucceeded = false;
        _feedback = 'Falha na conexão. Confira a URL e o token.';
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
