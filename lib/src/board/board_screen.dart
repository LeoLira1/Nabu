import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'board_controller.dart';
import 'board_item.dart';

const _symbolIcons = <String, IconData>{
  'star': Icons.star_rounded,
  'heart': Icons.favorite_rounded,
  'check': Icons.check_circle_rounded,
  'idea': Icons.lightbulb_rounded,
  'warning': Icons.warning_rounded,
  'book': Icons.menu_book_rounded,
  'movie': Icons.movie_rounded,
  'work': Icons.work_rounded,
};

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.controller,
    required this.boardTitle,
    required this.onBoards,
    required this.onSync,
    required this.onSettings,
  });

  final BoardController controller;
  final String boardTitle;
  final VoidCallback onBoards;
  final VoidCallback onSync;
  final VoidCallback onSettings;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  static const _green = Color(0xff16a394);
  final FocusNode _keyboardFocus = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  Offset _translation = Offset.zero;
  Offset _gestureStartTranslation = Offset.zero;
  Offset _worldFocalAtStart = Offset.zero;
  double _scale = 1;
  double _gestureStartScale = 1;
  Size _viewport = Size.zero;
  bool _cameraReady = false;

  BoardController get controller => widget.controller;

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  Offset _screenToWorld(Offset screen) => (screen - _translation) / _scale;

  void _centerCamera() {
    setState(() {
      _scale = 1;
      _translation = Offset(_viewport.width / 2, _viewport.height / 2);
    });
  }

  void _zoomBy(double factor) {
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final worldCenter = _screenToWorld(center);
    final next = (_scale * factor).clamp(.25, 3.0);
    setState(() {
      _scale = next;
      _translation = center - worldCenter * next;
    });
  }

  void _add(BoardItemType type) {
    final center = _screenToWorld(
      Offset(_viewport.width / 2, _viewport.height / 2),
    );
    controller.addItem(type, center - const Offset(105, 80));
  }

  void _addWithContent(BoardItemType type, String content) {
    final center = _screenToWorld(
      Offset(_viewport.width / 2, _viewport.height / 2),
    );
    final offset = type == BoardItemType.symbol
        ? const Offset(50, 50)
        : const Offset(105, 50);
    controller.addItem(type, center - offset, content: content);
  }

  Future<void> _pickArrow() async {
    final style = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            const ListTile(
              title: Text(
                'Adicionar seta',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded),
              title: const Text('Seta reta'),
              onTap: () => Navigator.pop(context, 'straight'),
            ),
            ListTile(
              leading: const Icon(Icons.subdirectory_arrow_right_rounded),
              title: const Text('Seta curva'),
              onTap: () => Navigator.pop(context, 'curved'),
            ),
          ],
        ),
      ),
    );
    if (style != null && mounted) {
      _addWithContent(BoardItemType.arrow, style);
    }
  }

  Future<void> _pickSymbol() async {
    final symbol = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Adicionar símbolo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: _symbolIcons.entries
                    .map((entry) => InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, entry.key),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xffedf1f4),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(entry.value, size: 34),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    if (symbol != null && mounted) {
      _addWithContent(BoardItemType.symbol, symbol);
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final center = _screenToWorld(
        Offset(_viewport.width / 2, _viewport.height / 2),
      );
      controller.addImage(
        bytes,
        center - const Offset(160, 110),
        mimeType: image.mimeType ?? 'image/jpeg',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível importar a imagem: $error')),
      );
    }
  }

  Future<void> _edit(BoardItem item) async {
    final textController = TextEditingController(text: item.text);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar conteúdo'),
        content: TextField(
          controller: textController,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Escreva sua ideia…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result != null && result.isNotEmpty) {
      controller.updateText(item.id, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Focus(
              focusNode: _keyboardFocus,
              autofocus: true,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.delete ||
                    event.logicalKey == LogicalKeyboardKey.backspace) {
                  controller.deleteSelected();
                  return KeyEventResult.handled;
                }
                if (HardwareKeyboard.instance.isControlPressed &&
                    event.logicalKey == LogicalKeyboardKey.keyZ) {
                  controller.undo();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Column(
                children: <Widget>[
                  _TopBar(
                    boardTitle: widget.boardTitle,
                    scale: _scale,
                    syncState: controller.syncState,
                    canUndo: controller.canUndo,
                    canRedo: controller.canRedo,
                    onUndo: controller.undo,
                    onRedo: controller.redo,
                    onZoomOut: () => _zoomBy(1 / 1.2),
                    onZoomIn: () => _zoomBy(1.2),
                    onCenter: _centerCamera,
                    onBoards: widget.onBoards,
                    onSync: widget.onSync,
                    onSettings: widget.onSettings,
                  ),
                  Expanded(child: _buildBoard()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        if (!_cameraReady && _viewport.isFinite) {
          _cameraReady = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centerCamera();
          });
        }

        final selectedItem = controller.selectedItem;

        return ClipRect(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => controller.select(null),
                  onScaleStart: (details) {
                    _gestureStartScale = _scale;
                    _gestureStartTranslation = _translation;
                    _worldFocalAtStart =
                        (details.localFocalPoint - _translation) / _scale;
                  },
                  onScaleUpdate: (details) {
                    final next = (_gestureStartScale * details.scale)
                        .clamp(.25, 3.0);
                    setState(() {
                      _scale = next;
                      if (details.pointerCount > 1) {
                        _translation = details.localFocalPoint -
                            _worldFocalAtStart * next;
                      } else {
                        _translation = _gestureStartTranslation +
                            details.focalPointDelta;
                        _gestureStartTranslation = _translation;
                      }
                    });
                  },
                  child: CustomPaint(
                    painter: InfiniteGridPainter(
                      translation: _translation,
                      scale: _scale,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              ...controller.items.map(_buildItem),
              Positioned(
                left: 16,
                top: 18,
                child: _ToolBar(
                  selectedItem: selectedItem,
                  onAdd: _add,
                  onAddImage: _pickImage,
                  onAddArrow: _pickArrow,
                  onAddSymbol: _pickSymbol,
                  onToggleLock: () {
                    if (selectedItem != null) {
                      controller.toggleLock(selectedItem.id);
                    }
                  },
                  onToggleImageOrientation: () {
                    if (selectedItem != null) {
                      controller.toggleImageOrientation(selectedItem.id);
                    }
                  },
                  onRotate: () {
                    if (selectedItem != null) {
                      controller.rotateItem(selectedItem.id);
                    }
                  },
                  onDelete: controller.deleteSelected,
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _MiniMap(
                  items: controller.items,
                  viewport: _viewport,
                  translation: _translation,
                  scale: _scale,
                ),
              ),
              if (controller.loading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItem(BoardItem item) {
    final selected = controller.selectedId == item.id;
    return Positioned(
      left: item.position.dx * _scale + _translation.dx,
      top: item.position.dy * _scale + _translation.dy,
      child: Transform.rotate(
        angle: item.rotation,
        child: Transform.scale(
          scale: _scale,
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: () => controller.select(item.id),
            onDoubleTap: item.type == BoardItemType.image ||
                    item.type == BoardItemType.arrow ||
                    item.type == BoardItemType.symbol
                ? null
                : () => _edit(item),
            onPanStart: item.isLocked
                ? null
                : (_) {
                    controller.select(item.id);
                    controller.beginMove(item.id);
                  },
            onPanUpdate: item.isLocked
                ? null
                : (details) =>
                    controller.moveBy(item.id, details.delta / _scale),
            onPanEnd:
                item.isLocked ? null : (_) => controller.endMove(item.id),
            onPanCancel:
                item.isLocked ? null : () => controller.endMove(item.id),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                _BoardItemView(item: item, selected: selected),
                if (item.isLocked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xdd202833),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.boardTitle,
    required this.scale,
    required this.syncState,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onCenter,
    required this.onBoards,
    required this.onSync,
    required this.onSettings,
  });

  final String boardTitle;
  final double scale;
  final SyncState syncState;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onCenter;
  final VoidCallback onBoards;
  final VoidCallback onSync;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;
    final status = switch (syncState) {
      SyncState.localOnly => ('Somente local', Icons.phone_android_rounded),
      SyncState.connecting => ('Conectando', Icons.sync_rounded),
      SyncState.synced => ('Turso sincronizado', Icons.cloud_done_outlined),
      SyncState.error => ('Falha na sincronização', Icons.cloud_off_outlined),
    };
    Widget actionButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
    }) =>
        IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          color: Colors.white,
          disabledColor: Colors.white24,
          visualDensity: compact ? VisualDensity.compact : null,
          constraints: compact
              ? const BoxConstraints.tightFor(width: 40, height: 48)
              : null,
          icon: Icon(icon),
        );

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 18),
      color: const Color(0xff202833),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _BoardScreenState._green,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              '∞',
              style: TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!compact) ...<Widget>[
            const Text(
              'Nabu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 28, color: Colors.white24),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: TextButton.icon(
              onPressed: onBoards,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 10),
              ),
              icon: const Icon(Icons.dashboard_outlined, size: 19),
              label: Text(
                boardTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const Spacer(),
          if (MediaQuery.sizeOf(context).width > 760) ...<Widget>[
            Icon(status.$2, color: Colors.white60, size: 17),
            const SizedBox(width: 6),
            Text(status.$1, style: const TextStyle(color: Colors.white60)),
            const SizedBox(width: 18),
          ],
          actionButton(
            icon: Icons.sync_rounded,
            tooltip: 'Sincronizar agora',
            onPressed: syncState == SyncState.connecting ? null : onSync,
          ),
          actionButton(
            icon: Icons.cloud_outlined,
            tooltip: 'Configurar Turso',
            onPressed: onSettings,
          ),
          actionButton(
            icon: Icons.undo_rounded,
            tooltip: 'Desfazer',
            onPressed: canUndo ? onUndo : null,
          ),
          actionButton(
            icon: Icons.redo_rounded,
            tooltip: 'Refazer',
            onPressed: canRedo ? onRedo : null,
          ),
          if (!compact) ...<Widget>[
            IconButton(
              onPressed: onZoomOut,
              color: Colors.white,
              icon: const Icon(Icons.remove_rounded),
            ),
            InkWell(
              onTap: onCenter,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                child: Text(
                  '${(scale * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onZoomIn,
              color: Colors.white,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({
    required this.selectedItem,
    required this.onAdd,
    required this.onAddImage,
    required this.onAddArrow,
    required this.onAddSymbol,
    required this.onToggleLock,
    required this.onToggleImageOrientation,
    required this.onRotate,
    required this.onDelete,
  });

  final BoardItem? selectedItem;
  final ValueChanged<BoardItemType> onAdd;
  final VoidCallback onAddImage;
  final VoidCallback onAddArrow;
  final VoidCallback onAddSymbol;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleImageOrientation;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tooltip, VoidCallback action) {
      return IconButton(
        onPressed: action,
        tooltip: tooltip,
        color: const Color(0xffdfe5ec),
        icon: Icon(icon),
      );
    }

    return Material(
      elevation: 8,
      color: const Color(0xff202833),
      borderRadius: BorderRadius.circular(13),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - 120,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
            button(Icons.pan_tool_alt_outlined, 'Mover o quadro', () {}),
            const Divider(color: Colors.white12, height: 8),
            button(Icons.sticky_note_2_outlined, 'Novo post-it',
                () => onAdd(BoardItemType.stickyNote)),
            button(Icons.text_fields_rounded, 'Novo texto',
                () => onAdd(BoardItemType.text)),
            button(Icons.crop_square_rounded, 'Novo retângulo',
                () => onAdd(BoardItemType.rectangle)),
            button(Icons.circle_outlined, 'Novo círculo',
                () => onAdd(BoardItemType.circle)),
            button(Icons.image_outlined, 'Importar imagem', onAddImage),
            button(Icons.arrow_forward_rounded, 'Adicionar seta', onAddArrow),
            button(Icons.category_outlined, 'Adicionar símbolo', onAddSymbol),
            if (selectedItem != null) ...<Widget>[
              const Divider(color: Colors.white12, height: 8),
              button(
                selectedItem!.isLocked
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                selectedItem!.isLocked
                    ? 'Desancorar elemento'
                    : 'Ancorar elemento',
                onToggleLock,
              ),
              if (selectedItem!.type == BoardItemType.image)
                button(
                  Icons.rotate_90_degrees_ccw_outlined,
                  'Alternar retrato/paisagem',
                  onToggleImageOrientation,
                ),
              if (selectedItem!.type == BoardItemType.arrow)
                button(
                  Icons.rotate_right_rounded,
                  'Girar seta em 45°',
                  onRotate,
                ),
              button(Icons.delete_outline_rounded, 'Excluir', onDelete),
            ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardItemView extends StatelessWidget {
  const _BoardItemView({required this.item, required this.selected});

  final BoardItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (item.type == BoardItemType.arrow) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: item.size.width,
        height: item.size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xff3d6fe8) : Colors.transparent,
            width: 3,
          ),
        ),
        child: CustomPaint(
          painter: _ArrowPainter(
            curved: item.text == 'curved',
            color: item.color,
          ),
        ),
      );
    }
    if (item.type == BoardItemType.symbol) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: item.size.width,
        height: item.size.height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xff3d6fe8) : Colors.transparent,
            width: 3,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(blurRadius: 12, color: Color(0x18000000)),
          ],
        ),
        child: Icon(
          _symbolIcons[item.text] ?? Icons.star_rounded,
          size: 54,
          color: item.color,
        ),
      );
    }
    if (item.type == BoardItemType.image && item.imageBase64.isNotEmpty) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: item.size.width,
        height: item.size.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xff3d6fe8)
                : const Color(0xffd6dce1),
            width: selected ? 3 : 1,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              blurRadius: 18,
              offset: Offset(0, 8),
              color: Color(0x22000000),
            ),
          ],
        ),
        child: Image.memory(
          base64Decode(item.imageBase64),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 42),
          ),
        ),
      );
    }
    final shape = item.type == BoardItemType.circle
        ? BoxShape.circle
        : BoxShape.rectangle;
    final radius = item.type == BoardItemType.stickyNote
        ? BorderRadius.circular(3)
        : BorderRadius.circular(13);
    final textStyle = TextStyle(
      fontSize: item.type == BoardItemType.text ? 27 : 18,
      height: 1.35,
      color: const Color(0xff24272b),
      fontWeight: item.type == BoardItemType.stickyNote
          ? FontWeight.w500
          : FontWeight.w700,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: item.size.width,
      height: item.size.height,
      padding: const EdgeInsets.all(18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: item.type == BoardItemType.text
            ? Colors.transparent
            : item.color,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? radius : null,
        border: Border.all(
          color: selected
              ? const Color(0xff3d6fe8)
              : item.type == BoardItemType.stickyNote
                  ? Colors.transparent
                  : item.color.withValues(alpha: .9),
          width: selected ? 3 : 2,
        ),
        boxShadow: item.type == BoardItemType.text
            ? null
            : const <BoxShadow>[
                BoxShadow(
                  blurRadius: 18,
                  offset: Offset(0, 8),
                  color: Color(0x22000000),
                ),
              ],
      ),
      child: Text(item.text, textAlign: TextAlign.center, style: textStyle),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.curved, required this.color});

  final bool curved;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final end = curved
        ? Offset(size.width - 28, size.height * .6)
        : Offset(size.width - 28, size.height / 2);
    double angle;
    if (curved) {
      final control = Offset(size.width * .68, 8);
      final path = Path()
        ..moveTo(18, size.height - 18)
        ..cubicTo(
          size.width * .18,
          8,
          control.dx,
          control.dy,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, paint);
      angle = math.atan2(end.dy - control.dy, end.dx - control.dx);
    } else {
      canvas.drawLine(Offset(18, size.height / 2), end, paint);
      angle = 0;
    }
    const headLength = 25.0;
    const spread = .68;
    final first = end -
        Offset(
          math.cos(angle - spread) * headLength,
          math.sin(angle - spread) * headLength,
        );
    final second = end -
        Offset(
          math.cos(angle + spread) * headLength,
          math.sin(angle + spread) * headLength,
        );
    canvas.drawLine(end, first, paint);
    canvas.drawLine(end, second, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.curved != curved || oldDelegate.color != color;
}

class InfiniteGridPainter extends CustomPainter {
  InfiniteGridPainter({required this.translation, required this.scale});

  final Offset translation;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xfffafbf9), BlendMode.src);
    final minor = 24 * scale;
    final major = minor * 5;
    final minorPaint = Paint()
      ..color = const Color(0xffdfe4e3)
      ..strokeWidth = .75;
    final majorPaint = Paint()
      ..color = const Color(0xffcbd2d0)
      ..strokeWidth = 1;

    void lines(double spacing, Paint paint) {
      if (spacing < 7) return;
      final startX = translation.dx % spacing;
      final startY = translation.dy % spacing;
      for (double x = startX; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = startY; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    lines(minor, minorPaint);
    lines(major, majorPaint);
  }

  @override
  bool shouldRepaint(covariant InfiniteGridPainter oldDelegate) =>
      oldDelegate.translation != translation || oldDelegate.scale != scale;
}

class _MiniMap extends StatelessWidget {
  const _MiniMap({
    required this.items,
    required this.viewport,
    required this.translation,
    required this.scale,
  });

  final List<BoardItem> items;
  final Size viewport;
  final Offset translation;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 620) {
      return const SizedBox.shrink();
    }
    return Container(
      width: 190,
      height: 126,
      decoration: BoxDecoration(
        color: const Color(0xf2ffffff),
        border: Border.all(color: const Color(0xffbac2c8)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(blurRadius: 18, color: Color(0x22000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Text(
              'Mini mapa',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _MiniMapPainter(
                items: items,
                viewport: viewport,
                translation: translation,
                scale: scale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({
    required this.items,
    required this.viewport,
    required this.translation,
    required this.scale,
  });

  final List<BoardItem> items;
  final Size viewport;
  final Offset translation;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (items.isEmpty) return;
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final item in items) {
      left = math.min(left, item.position.dx);
      top = math.min(top, item.position.dy);
      right = math.max(right, item.position.dx + item.size.width);
      bottom = math.max(bottom, item.position.dy + item.size.height);
    }
    final viewLeft = -translation.dx / scale;
    final viewTop = -translation.dy / scale;
    final viewRight = viewLeft + viewport.width / scale;
    final viewBottom = viewTop + viewport.height / scale;
    left = math.min(left, viewLeft) - 80;
    top = math.min(top, viewTop) - 80;
    right = math.max(right, viewRight) + 80;
    bottom = math.max(bottom, viewBottom) + 80;
    final factor = math.min(size.width / (right - left), size.height / (bottom - top));
    Offset map(Offset point) => Offset(
          (point.dx - left) * factor,
          (point.dy - top) * factor,
        );

    for (final item in items) {
      final origin = map(item.position);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx,
            origin.dy,
            math.max(4, item.size.width * factor),
            math.max(4, item.size.height * factor),
          ),
          const Radius.circular(2),
        ),
        Paint()..color = item.color,
      );
    }
    final visibleOrigin = map(Offset(viewLeft, viewTop));
    canvas.drawRect(
      Rect.fromLTWH(
        visibleOrigin.dx,
        visibleOrigin.dy,
        viewport.width / scale * factor,
        viewport.height / scale * factor,
      ),
      Paint()
        ..color = const Color(0x223d6fe8)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        visibleOrigin.dx,
        visibleOrigin.dy,
        viewport.width / scale * factor,
        viewport.height / scale * factor,
      ),
      Paint()
        ..color = const Color(0xff3d6fe8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}
