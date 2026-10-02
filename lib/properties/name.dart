import 'package:fl_contacts/vcard.dart';

/// Structured name parts. Display text lives on [Contact.displayName];
/// only one name per contact is modeled, nickname included.
class Name {
  /// Given name.
  String first;

  /// Family name.
  String last;

  /// Middle name.
  String middle;

  /// Title prefix such as `Dr`.
  String prefix;

  /// Generational suffix such as `Jr`.
  String suffix;

  /// Nickname or short name.
  String nickname;

  /// Phonetic given name.
  String firstPhonetic;

  /// Phonetic family name.
  String lastPhonetic;

  /// Phonetic middle name.
  String middlePhonetic;

  /// Creates an empty name; every part defaults to `''`.
  Name({
    this.first = '',
    this.last = '',
    this.middle = '',
    this.prefix = '',
    this.suffix = '',
    this.nickname = '',
    this.firstPhonetic = '',
    this.lastPhonetic = '',
    this.middlePhonetic = '',
  });

  /// Decodes a name from its channel map.
  factory Name.fromJson(Map<String, dynamic> json) => Name(
    first: (json['first'] as String?) ?? '',
    last: (json['last'] as String?) ?? '',
    middle: (json['middle'] as String?) ?? '',
    prefix: (json['prefix'] as String?) ?? '',
    suffix: (json['suffix'] as String?) ?? '',
    nickname: (json['nickname'] as String?) ?? '',
    firstPhonetic: (json['firstPhonetic'] as String?) ?? '',
    lastPhonetic: (json['lastPhonetic'] as String?) ?? '',
    middlePhonetic: (json['middlePhonetic'] as String?) ?? '',
  );

  /// Encodes the name for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'first': first,
    'last': last,
    'middle': middle,
    'prefix': prefix,
    'suffix': suffix,
    'nickname': nickname,
    'firstPhonetic': firstPhonetic,
    'lastPhonetic': lastPhonetic,
    'middlePhonetic': middlePhonetic,
  };

  @override
  int get hashCode => Object.hash(
    first,
    last,
    middle,
    prefix,
    suffix,
    nickname,
    firstPhonetic,
    lastPhonetic,
    middlePhonetic,
  );

  @override
  bool operator ==(Object other) =>
      other is Name &&
      other.first == first &&
      other.last == last &&
      other.middle == middle &&
      other.prefix == prefix &&
      other.suffix == suffix &&
      other.nickname == nickname &&
      other.firstPhonetic == firstPhonetic &&
      other.lastPhonetic == lastPhonetic &&
      other.middlePhonetic == middlePhonetic;

  @override
  String toString() =>
      'Name(first=$first, last=$last, middle=$middle, prefix=$prefix, '
      'suffix=$suffix, nickname=$nickname, firstPhonetic=$firstPhonetic, '
      'lastPhonetic=$lastPhonetic, middlePhonetic=$middlePhonetic)';

  /// Emits parts as `N` plus `NICKNAME` when present.
  List<String> toVCard() {
    var lines = <String>[];
    final components = [last, first, middle, prefix, suffix];
    if (components.any((x) => x.isNotEmpty)) {
      lines.add('N:${components.map(vCardEncode).join(';')}');
    }
    if (nickname.isNotEmpty) {
      lines.add('NICKNAME:${vCardEncode(nickname)}');
    }
    return lines;
  }
}
