import 'package:flutter/foundation.dart';

/// Kind of a curated [Note].
enum NoteKind {
  fact,
  story;

  static NoteKind parse(String raw) => switch (raw) {
        'story' => NoteKind.story,
        _ => NoteKind.fact, // includes legacy 'trivia'
      };

  String get emoji => switch (this) {
        NoteKind.fact => '💡',
        NoteKind.story => '📖',
      };
}

/// A curated text attached to a country, shown in the Stories layer.
/// Read-only: ships with the app content.
@immutable
class Note {
  const Note({
    required this.id,
    required this.countryCode,
    required this.kind,
    required this.text,
  });

  final String id;
  final String countryCode;
  final NoteKind kind;
  final String text;
}
