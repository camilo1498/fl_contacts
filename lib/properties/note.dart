import 'package:fl_contacts/vcard.dart';

/// A free-form note. Android allows several per contact, iOS one, and
/// devices without the notes entitlement report none.
class Note {
  /// Note text.
  String note;

  /// Wraps raw [note] text.
  Note(this.note);

  /// Decodes a note from its channel map.
  factory Note.fromJson(Map<String, dynamic> json) =>
      Note((json['note'] as String?) ?? '');

  /// Encodes the note for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{'note': note};

  @override
  int get hashCode => note.hashCode;

  @override
  bool operator ==(Object other) => other is Note && other.note == note;

  @override
  String toString() => 'Note(note=$note)';

  /// Emits the note as `NOTE`; empty notes produce no output.
  List<String> toVCard() {
    if (note.isEmpty) return [];
    return ['NOTE:${vCardEncode(note)}'];
  }
}
