import 'package:fl_contacts/config.dart';
import 'package:fl_contacts/vcard.dart';

/// A labeled phone number.
class Phone {
  /// Dialable number, extension appended after `;` when present.
  String number;

  /// Canonical E.164 form supplied by Android; empty elsewhere.
  String normalizedNumber;

  /// Label, defaulting to [PhoneLabel.mobile].
  PhoneLabel label;

  /// Free-form label used only with [PhoneLabel.custom].
  String customLabel;

  /// Default number for this contact. Android only.
  bool isPrimary;

  /// Creates a phone; labels default to mobile with no custom text.
  Phone(
    this.number, {
    this.normalizedNumber = '',
    this.label = PhoneLabel.mobile,
    this.customLabel = '',
    this.isPrimary = false,
  });

  /// Decodes a phone from its channel map, defaulting unknown labels.
  factory Phone.fromJson(Map<String, dynamic> json) => Phone(
    (json['number'] as String?) ?? '',
    normalizedNumber: (json['normalizedNumber'] as String?) ?? '',
    label: PhoneLabel.fromValue(json['label'] as String?, PhoneLabel.mobile),
    customLabel: (json['customLabel'] as String?) ?? '',
    isPrimary: (json['isPrimary'] as bool?) ?? false,
  );

  /// Encodes the phone for the channel. The label always round-trips.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'number': number,
    'normalizedNumber': normalizedNumber,
    'label': label.value,
    'customLabel': customLabel,
    'isPrimary': isPrimary,
  };

  @override
  int get hashCode =>
      Object.hash(number, normalizedNumber, label, customLabel, isPrimary);

  @override
  bool operator ==(Object other) =>
      other is Phone &&
      other.number == number &&
      other.normalizedNumber == normalizedNumber &&
      other.label == label &&
      other.customLabel == customLabel &&
      other.isPrimary == isPrimary;

  @override
  String toString() =>
      'Phone(number=$number, normalizedNumber=$normalizedNumber, label=$label, '
      'customLabel=$customLabel, isPrimary=$isPrimary)';

  /// Emits the number as `TEL`, mapping known labels to vCard types.
  List<String> toVCard() {
    final v4 = flContactsConfig.vCardVersion == VCardVersion.v4;
    var s = v4 ? 'TEL;VALUE=uri' : 'TEL';
    var types = <String>[];
    switch (label) {
      case PhoneLabel.faxHome:
        types.add('fax');
        types.add('home');
        break;
      case PhoneLabel.faxOther:
        types.add('fax');
        break;
      case PhoneLabel.faxWork:
        types.add('fax');
        types.add('work');
        break;
      case PhoneLabel.home:
        types.add('home');
        break;
      case PhoneLabel.iPhone:
      case PhoneLabel.main:
        types.add('voice');
        types.add(v4 ? 'text' : 'msg');
        break;
      case PhoneLabel.mms:
      case PhoneLabel.mobile:
        types.add('cell');
        types.add(v4 ? 'text' : 'msg');
        break;
      case PhoneLabel.workMobile:
        types.add('cell');
        types.add(v4 ? 'text' : 'msg');
        types.add('work');
        break;
      case PhoneLabel.pager:
        types.add('pager');
        break;
      case PhoneLabel.workPager:
        types.add('pager');
        types.add('work');
        break;
      default:
    }
    if (!v4 && isPrimary) {
      types.add('pref');
    }
    if (types.length == 1) {
      s += ';TYPE=${types.first}';
    } else if (types.length > 1) {
      if (v4) {
        s += ';TYPE="${types.join(',')}"';
      } else {
        s += ';TYPE=${types.join(',')}';
      }
    }
    if (v4 && isPrimary) {
      s += ';PREF=1';
    }
    if (v4) {
      s += ':tel:${vCardEncode(number)}';
    } else {
      s += ':${vCardEncode(number)}';
    }
    return [s];
  }
}

/// Phone labels.
///
/// | Label       | Android | iOS |
/// |-------------|:-------:|:---:|
/// | assistant   | ✔       | ⨯   |
/// | callback    | ✔       | ⨯   |
/// | car         | ✔       | ⨯   |
/// | companyMain | ✔       | ⨯   |
/// | faxHome     | ✔       | ✔   |
/// | faxOther    | ✔       | ✔   |
/// | faxWork     | ✔       | ✔   |
/// | home        | ✔       | ✔   |
/// | iPhone      | ⨯       | ✔   |
/// | isdn        | ✔       | ⨯   |
/// | main        | ✔       | ✔   |
/// | mms         | ✔       | ⨯   |
/// | mobile      | ✔       | ✔   |
/// | pager       | ✔       | ✔   |
/// | radio       | ✔       | ⨯   |
/// | school      | ⨯       | ✔   |
/// | telex       | ✔       | ⨯   |
/// | ttyTtd      | ✔       | ⨯   |
/// | work        | ✔       | ✔   |
/// | workMobile  | ✔       | ⨯   |
/// | workPager   | ✔       | ⨯   |
/// | other       | ✔       | ✔   |
/// | custom      | ✔       | ✔   |
/// Phone labels across Android and iOS.
enum PhoneLabel {
  assistant('assistant'),
  callback('callback'),
  car('car'),
  companyMain('companyMain'),
  faxHome('faxHome'),
  faxOther('faxOther'),
  faxWork('faxWork'),
  home('home'),
  iPhone('iPhone'),
  isdn('isdn'),
  main('main'),
  mms('mms'),
  mobile('mobile'),
  pager('pager'),
  radio('radio'),
  school('school'),
  telex('telex'),
  ttyTtd('ttyTtd'),
  work('work'),
  workMobile('workMobile'),
  workPager('workPager'),
  other('other'),
  custom('custom');

  /// Wire string used on the channel and in JSON.
  final String value;

  /// Creates a label with its wire [value].
  const PhoneLabel(this.value);

  /// Parses a wire string, returning [fallback] for unknown values.
  static PhoneLabel fromValue(String? value, PhoneLabel fallback) => PhoneLabel
      .values
      .firstWhere((e) => e.value == value, orElse: () => fallback);
}
