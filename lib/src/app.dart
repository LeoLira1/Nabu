import 'package:flutter/material.dart';

import 'board/board_controller.dart';
import 'board/board_screen.dart';
import 'data/local_board_store.dart';
import 'data/turso_board_store.dart';

class NabuApp extends StatefulWidget {
  const NabuApp({super.key});

  @override
  State<NabuApp> createState() => _NabuAppState();
}

class _NabuAppState extends State<NabuApp> {
  late final BoardController controller;

  @override
  void initState() {
    super.initState();
    controller = BoardController(
      localStore: LocalBoardStore(),
      remoteStore: TursoBoardStore.fromEnvironment(),
    );
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
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
      home: BoardScreen(controller: controller),
    );
  }
}

