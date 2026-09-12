class BoardInfo {
  const BoardInfo({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  BoardInfo copyWith({String? title, DateTime? updatedAt}) => BoardInfo(
        id: id,
        title: title ?? this.title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory BoardInfo.fromJson(Map<String, Object?> json) => BoardInfo(
        id: json['id']! as String,
        title: json['title']! as String,
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
      );

  static BoardInfo mainBoard() {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return BoardInfo(
      id: 'main',
      title: 'Meu quadro',
      createdAt: epoch,
      updatedAt: epoch,
    );
  }
}
