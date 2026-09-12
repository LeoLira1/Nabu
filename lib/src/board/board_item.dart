import 'dart:convert';

import 'package:flutter/material.dart';

enum BoardItemType { stickyNote, text, rectangle, circle }

@immutable
class BoardItem {
  const BoardItem({
    required this.id,
    required this.type,
    required this.position,
    required this.size,
    required this.colorValue,
    this.text = '',
    this.rotation = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final BoardItemType type;
  final Offset position;
  final Size size;
  final int colorValue;
  final String text;
  final double rotation;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get color => Color(colorValue);

  BoardItem copyWith({
    BoardItemType? type,
    Offset? position,
    Size? size,
    int? colorValue,
    String? text,
    double? rotation,
    DateTime? updatedAt,
  }) {
    return BoardItem(
      id: id,
      type: type ?? this.type,
      position: position ?? this.position,
      size: size ?? this.size,
      colorValue: colorValue ?? this.colorValue,
      text: text ?? this.text,
      rotation: rotation ?? this.rotation,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'type': type.name,
        'x': position.dx,
        'y': position.dy,
        'width': size.width,
        'height': size.height,
        'color': colorValue,
        'text': text,
        'rotation': rotation,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory BoardItem.fromJson(Map<String, Object?> json) {
    return BoardItem(
      id: json['id']! as String,
      type: BoardItemType.values.byName(json['type']! as String),
      position: Offset(
        (json['x']! as num).toDouble(),
        (json['y']! as num).toDouble(),
      ),
      size: Size(
        (json['width']! as num).toDouble(),
        (json['height']! as num).toDouble(),
      ),
      colorValue: (json['color']! as num).toInt(),
      text: (json['text'] as String?) ?? '',
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['createdAt']! as String),
      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );
  }

  String encodeContent() => jsonEncode(<String, Object?>{
        'text': text,
        'color': colorValue,
      });
}

