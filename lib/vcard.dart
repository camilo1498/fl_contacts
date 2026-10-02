import 'dart:convert';

import 'package:fl_contacts/contact.dart';
import 'package:fl_contacts/properties/address.dart';
import 'package:fl_contacts/properties/email.dart';
import 'package:fl_contacts/properties/event.dart';
import 'package:fl_contacts/properties/note.dart';
import 'package:fl_contacts/properties/organization.dart';
import 'package:fl_contacts/properties/phone.dart';
import 'package:fl_contacts/properties/social_media.dart';
import 'package:fl_contacts/properties/website.dart';
import 'package:fl_contacts/vcard_extra.dart';

final RegExp _dateRegexp = RegExp(
  r'^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|30|31)$',
);
final RegExp _noYearDateRegexp = RegExp(
  r'^--(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|30|31)$',
);
final RegExp _dateNoDashRegexp = RegExp(
  r'^\d{4}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|30|31)$',
);
final RegExp _noYearDateNoDashRegexp = RegExp(
  r'^--(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|30|31)$',
);

/// vCard lines that structure the document or annotate labels rather than
/// carrying contact data. Never collected as [VCardExtra].
const _structuralOps = {
  'BEGIN',
  'END',
  'VERSION',
  'PRODID',
  'REV',
  'X-ABLABEL',
};

/// One vCard property parameter such as `TYPE=home` in `TEL;TYPE=home:…`.
class Param {
  /// Upper-cased parameter key, e.g. `TYPE`.
  final String key;

  /// Upper-cased value, or null for valueless vCard 2.1 parameters.
  final String? value;

  /// Creates a parameter from an already upper-cased [key] and [value].
  const Param(this.key, this.value);

  @override
  String toString() => '$key => $value';
}

/// Escapes commas, semicolons and newlines for vCard property values.
String vCardEncode(String s) =>
    s.replaceAll(',', '\\,').replaceAll(';', '\\;').replaceAll('\n', '\\n');

/// Lenient vCard 2.1/3.0/4.0 importer. Unknown properties are skipped so
/// one malformed line never drops the whole card.
class VCardParser {
  /// Hides escaped separators behind placeholders so naive splits stay safe.
  String encode(String s) => s
      .replaceAll('\\,', '&flcontactscomma&')
      .replaceAll('\\;', '&flcontactssemicolon&')
      .replaceAll('\\n', '&flcontactsnewline&');

  /// Restores the placeholders hidden by [encode].
  String decode(String s) => s
      .replaceAll('&flcontactscomma&', ',')
      .replaceAll('&flcontactssemicolon&', ';')
      .replaceAll('&flcontactsnewline&', '\n');

  /// Joins folded lines per RFC 2425 §5.8.1 and rejoins split encodings.
  String unfold(String s) =>
      s.replaceAll(RegExp(r'\n[ \t]'), '').replaceAll(RegExp(r'=\n='), '=');

  /// Parses [content] and merges every recognized property into [contact].
  void parse(String content, Contact contact) {
    final lines = encode(
      unfold(content),
    ).split('\n').map((String x) => x.trim()).toList();
    final labelOverrides = _indexAppleLabels(lines);
    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length < 2) {
        continue;
      }
      final prefix = parts[0];
      var content = parts.sublist(1).join(':');
      if (content.isEmpty) {
        continue;
      }
      final prefixParts = prefix.split(';');
      final groupKey = prefixParts[0].split('.');
      final op = groupKey.last.toUpperCase();
      final group = groupKey.length == 2 ? groupKey.first : '';
      var params = <Param>[];
      for (final p in prefixParts.sublist(1)) {
        final paramParts = p.split('=');
        if (paramParts.length < 2) {
          params.add(Param(paramParts[0].toUpperCase(), null));
        } else {
          params.add(
            Param(
              paramParts[0].toUpperCase(),
              paramParts.sublist(1).join('=').toUpperCase(),
            ),
          );
        }
      }

      if (params.any(
        (p) => p.key == 'ENCODING' && p.value == 'QUOTED-PRINTABLE',
      )) {
        try {
          content = Uri.decodeFull(content.replaceAll('=', '%'));
        } on ArgumentError {
          // Malformed quoted-printable: keep the raw content.
        }
      }

      final labelOverride = group.isEmpty ? '' : (labelOverrides[group] ?? '');

      switch (op) {
        case 'PHOTO':
          try {
            contact.photo = base64.decode(decode(content));
          } on FormatException {
            // Not base64 (e.g. a photo URL): ignore the line.
          }
          break;
        case 'N':
          final parts = content.split(';');
          final n = parts.length;
          if (n >= 1) contact.name.last = decode(parts[0]);
          if (n >= 2) contact.name.first = decode(parts[1]);
          if (n >= 3) contact.name.middle = decode(parts[2]);
          if (n >= 4) contact.name.prefix = decode(parts[3]);
          if (n >= 5) contact.name.suffix = decode(parts[4]);
          break;
        case 'FN':
          contact.displayName = decode(content);
          break;
        case 'NICKNAME':
          final parts = content.split(',');
          contact.name.nickname = decode(parts[0]);
          break;
        case 'TEL':
        case 'PHONE':
          Phone phone;
          final number = content.startsWith('tel:')
              ? content.substring(4)
              : content;
          final numberParts = number.split(';ext=');
          if (numberParts.length == 2) {
            phone = Phone(
              '${decode(numberParts[0])};${decode(numberParts[1])}',
            );
          } else {
            phone = Phone(decode(numberParts[0]));
          }
          _parseLabel(params, labelOverride, _parsePhoneLabel, phone);
          contact.phones.add(phone);
          break;
        case 'EMAIL':
          var email = Email(decode(content));
          _parseLabel(params, labelOverride, _parseEmailLabel, email);
          contact.emails.add(email);
          break;
        case 'ADR':
          var addressParts = content.split(';');
          if (addressParts.length != 7) {
            continue; // invalid line
          }
          var address = Address('');
          if (([addressParts[0]] + addressParts.sublist(3)).any(
            (x) => x.isNotEmpty,
          )) {
            address.pobox = decode(addressParts[0]);
            address.street = decode(addressParts[2]);
            address.city = decode(addressParts[3]);
            address.state = decode(addressParts[4]);
            address.postalCode = decode(addressParts[5]);
            address.country = decode(addressParts[6]);
          }
          address.address = addressParts
              .map(decode)
              .where((x) => x.isNotEmpty)
              .join(' ');
          _parseLabel(params, labelOverride, _parseAddressLabel, address);
          contact.addresses.add(address);
          break;
        case 'ORG':
          if (contact.organizations.isEmpty) {
            contact.organizations = [Organization()];
          }
          final orgParts = content.split(';');
          final n = orgParts.length;
          if (n >= 1) {
            contact.organizations.first.company = decode(orgParts[0]);
          }
          if (n >= 2) {
            contact.organizations.first.department = decode(orgParts[1]);
          }
          break;
        case 'TITLE':
          if (contact.organizations.isEmpty) {
            contact.organizations = [Organization()];
          }
          contact.organizations.first.title = decode(content);
          break;
        case 'ROLE':
          if (contact.organizations.isEmpty) {
            contact.organizations = [Organization()];
          }
          contact.organizations.first.jobDescription = decode(content);
          break;
        case 'URL':
          var website = Website(decode(content));
          _parseLabel(params, labelOverride, _parseWebsiteLabel, website);
          contact.websites.add(website);
          break;
        case 'IMPP':
          final colonIndex = content.indexOf(':');
          if (colonIndex < 0) {
            continue; // invalid line
          }
          final serviceTypes = params.where((p) => p.key == 'X-SERVICE-TYPE');
          final serviceType = serviceTypes.isNotEmpty
              ? serviceTypes.first.value
              : null;
          final protocol = decode(
            serviceType ?? content.substring(0, colonIndex),
          );
          if (serviceType == 'ICQ' &&
              content.substring(0, colonIndex) == 'aim') {
            continue;
          }
          final userName = decode(content.substring(colonIndex + 1));
          final label =
              lowerCaseStringToSocialMediaLabel[protocol.toLowerCase()] ??
              SocialMediaLabel.custom;
          final customLabel = label == SocialMediaLabel.custom ? protocol : '';
          contact.socialMedias.add(
            SocialMedia(userName, label: label, customLabel: customLabel),
          );
          break;
        case 'X-SOCIALPROFILE':
          var protocol = '';
          for (final param in params) {
            if (param.key == 'TYPE' && param.value != null) {
              protocol = decode(param.value!);
            }
          }
          if (params.any((p) => p.key == 'X-USER' && p.value == 'TENCENT')) {
            protocol = 'tencent';
          }
          var userName = decode(content);
          for (final prefix in ['x-apple:', 'xmpp:']) {
            if (userName.startsWith(prefix)) {
              userName = userName.substring(prefix.length);
              break;
            }
          }
          final label =
              lowerCaseStringToSocialMediaLabel[protocol.toLowerCase()] ??
              SocialMediaLabel.custom;
          final customLabel = label == SocialMediaLabel.custom ? protocol : '';
          contact.socialMedias.add(
            SocialMedia(userName, label: label, customLabel: customLabel),
          );
          break;
        case 'BDAY':
        case 'ANNIVERSARY':
          final label = op == 'BDAY'
              ? EventLabel.birthday
              : EventLabel.anniversary;
          final date = decode(content);
          final omitYear = params.any((p) => p.key == 'X-APPLE-OMIT-YEAR');
          _tryAddEvent(contact, date, label, '', omitYear);
          break;
        case 'NOTE':
          contact.notes.add(Note(decode(content)));
          break;
        case 'X-ANDROID-CUSTOM':
          final contentParts = content.split(';');
          final n = contentParts.length;
          if (n < 2) {
            continue; // invalid line
          }
          switch (contentParts[0]) {
            case 'vnd.android.cursor.item/contact_event':
              final date = decode(contentParts[1]);
              final labelStr = n >= 3 ? contentParts[2] : '';
              var label = EventLabel.other;
              if (labelStr == '0') {
                label = EventLabel.custom;
              } else if (labelStr == '1') {
                label = EventLabel.anniversary;
              }
              final customLabel = n >= 4 && label == EventLabel.custom
                  ? decode(contentParts[3])
                  : '';
              _tryAddEvent(contact, date, label, customLabel, false);
              break;
            case 'vnd.android.cursor.item/nickname':
              contact.name.nickname = decode(contentParts[1]);
              break;
          }
          break;
        case 'X-AIM':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.aim),
          );
          break;
        case 'X-MSN':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.msn),
          );
          break;
        case 'X-YAHOO':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.yahoo),
          );
          break;
        case 'X-SKYPE-USERNAME':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.skype),
          );
          break;
        case 'X-QQ':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.qqchat),
          );
          break;
        case 'X-GOOGLE-TALK':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.googleTalk),
          );
          break;
        case 'X-ICQ':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.icq),
          );
          break;
        case 'X-JABBER':
          contact.socialMedias.add(
            SocialMedia(decode(content), label: SocialMediaLabel.jabber),
          );
          break;
        case 'X-PHONETIC-FIRST-NAME':
          contact.name.firstPhonetic = decode(content);
          break;
        case 'X-PHONETIC-LAST-NAME':
          contact.name.lastPhonetic = decode(content);
          break;
        case 'X-PHONETIC-ORG':
          if (contact.organizations.isEmpty) {
            contact.organizations = [Organization()];
          }
          contact.organizations.first.phoneticName = decode(content);
          break;
        case 'X-ABDATE':
          var tempContact = Contact();
          final date = decode(content);
          final omitYear = params.any((p) => p.key == 'X-APPLE-OMIT-YEAR');
          _tryAddEvent(tempContact, date, EventLabel.birthday, '', omitYear);
          if (tempContact.events.isNotEmpty) {
            _parseEventLabel(labelOverride, tempContact.events.last, true);
            contact.events.add(tempContact.events.last);
          }
          break;
        default:
          // Structural lines (BEGIN/END/VERSION/…) and Apple label metadata
          // carry no contact data; everything else is preserved as an extra
          // so exports round-trip without silent loss.
          if (_structuralOps.contains(op)) break;
          final extraParams = <String, String?>{};
          for (final param in params) {
            extraParams[param.key] = param.value;
          }
          contact.extras.add(
            VCardExtra(
              name: op,
              value: decode(content),
              params: extraParams,
              group: group.isEmpty ? null : group,
            ),
          );
      }
    }
    contact.deduplicateProperties();
  }
}

/// Adds a dated event when [date] matches a known vCard shape; silently
/// skips unparseable input instead of throwing.
/// Indexes Apple `X-ABLABEL` lines by group name in a single pass.
///
/// The main loop used to rescan every line for each grouped property
/// (quadratic); this map preserves the same last-wins semantics in linear
/// time. Labels stay raw here and are decoded downstream as before.
Map<String, String> _indexAppleLabels(List<String> lines) {
  final overrides = <String, String>{};
  for (final line in lines) {
    final dot = line.indexOf('.');
    if (dot < 0) continue;
    final colon = line.indexOf(':', dot);
    if (colon < 0) continue;
    if (line.substring(dot + 1, colon).toUpperCase() != 'X-ABLABEL') {
      continue;
    }
    final label = line.substring(line.lastIndexOf(':') + 1);
    if (label.startsWith('_\$!<') && label.endsWith('>!\$_')) {
      overrides[line.substring(0, dot)] = label.substring(4, label.length - 4);
    } else {
      overrides[line.substring(0, dot)] = label;
    }
  }
  return overrides;
}

void _tryAddEvent(
  Contact contact,
  String date,
  EventLabel label,
  String customLabel,
  bool omitYear,
) {
  if (_dateRegexp.hasMatch(date)) {
    contact.events.add(
      Event(
        year: omitYear ? null : int.parse(date.substring(0, 4)),
        month: int.parse(date.substring(5, 7)),
        day: int.parse(date.substring(8, 10)),
        label: label,
        customLabel: customLabel,
      ),
    );
  } else if (_noYearDateRegexp.hasMatch(date)) {
    contact.events.add(
      Event(
        year: null,
        month: int.parse(date.substring(2, 4)),
        day: int.parse(date.substring(5, 7)),
        label: label,
        customLabel: customLabel,
      ),
    );
  } else if (_dateNoDashRegexp.hasMatch(date)) {
    contact.events.add(
      Event(
        year: omitYear ? null : int.parse(date.substring(0, 4)),
        month: int.parse(date.substring(4, 6)),
        day: int.parse(date.substring(6, 8)),
        label: label,
        customLabel: customLabel,
      ),
    );
  } else if (_noYearDateNoDashRegexp.hasMatch(date)) {
    contact.events.add(
      Event(
        year: null,
        month: int.parse(date.substring(2, 4)),
        day: int.parse(date.substring(4, 6)),
        label: label,
        customLabel: customLabel,
      ),
    );
  } else {
    final dt = DateTime.tryParse(date);
    if (dt != null) {
      contact.events.add(
        Event(
          year: omitYear ? null : dt.year,
          month: dt.month,
          day: dt.day,
          label: label,
          customLabel: customLabel,
        ),
      );
    }
  }
}

/// Maps a vCard type token onto its model label; unknown tokens fall
/// back to `custom` only when the caller allows it.
void _parsePhoneLabel(String label, Phone phone, bool defaultToCustom) {
  switch (label.toUpperCase()) {
    case 'HOME':
      if (phone.label != PhoneLabel.faxHome) {
        phone.label = PhoneLabel.home;
      }
      break;
    case 'CELL':
    case 'MOBILE':
      if (phone.label != PhoneLabel.iPhone) {
        phone.label = PhoneLabel.mobile;
      }
      break;
    case 'IPHONE':
      phone.label = PhoneLabel.iPhone;
      break;
    case 'MAIN':
      phone.label = PhoneLabel.main;
      break;
    case 'WORK':
      if (phone.label == PhoneLabel.faxHome) {
        phone.label = PhoneLabel.faxWork;
      } else if (phone.label == PhoneLabel.pager) {
        phone.label = PhoneLabel.workPager;
      } else {
        phone.label = PhoneLabel.work;
      }
      break;
    case 'OTHER':
      if (phone.label == PhoneLabel.faxHome) {
        phone.label = PhoneLabel.faxOther;
      } else {
        phone.label = PhoneLabel.other;
      }
      break;
    case 'PAGER':
      if (phone.label == PhoneLabel.work) {
        phone.label = PhoneLabel.workPager;
      } else {
        phone.label = PhoneLabel.pager;
      }
      break;
    case 'FAX':
      if (phone.label == PhoneLabel.work) {
        phone.label = PhoneLabel.faxWork;
      } else if (phone.label == PhoneLabel.pager) {
        phone.label = PhoneLabel.workPager;
      } else if (phone.label == PhoneLabel.other) {
        phone.label = PhoneLabel.faxOther;
      } else {
        phone.label = PhoneLabel.faxHome;
      }
      break;
    case 'PREF':
      phone.isPrimary = true;
      break;
    default:
      if (defaultToCustom) {
        phone.label = PhoneLabel.custom;
        phone.customLabel = label;
      }
  }
}

/// Maps a vCard type token onto its model label; unknown tokens fall
/// back to `custom` only when the caller allows it.
void _parseEmailLabel(String label, Email email, bool defaultToCustom) {
  switch (label.toUpperCase()) {
    case 'HOME':
      email.label = EmailLabel.home;
      break;
    case 'MOBILE':
    case 'CELL':
      email.label = EmailLabel.mobile;
      break;
    case 'WORK':
      email.label = EmailLabel.work;
      break;
    case 'OTHER':
      email.label = EmailLabel.other;
      break;
    case 'PREF':
      email.isPrimary = true;
      break;
    default:
      if (defaultToCustom) {
        email.label = EmailLabel.custom;
        email.customLabel = label;
      }
  }
}

/// Maps a vCard type token onto its model label; unknown tokens fall
/// back to `custom` only when the caller allows it.
void _parseAddressLabel(String label, Address address, bool defaultToCustom) {
  switch (label.toUpperCase()) {
    case 'HOME':
      address.label = AddressLabel.home;
      break;
    case 'WORK':
      address.label = AddressLabel.work;
      break;
    case 'OTHER':
      address.label = AddressLabel.other;
      break;
    default:
      if (defaultToCustom) {
        address.label = AddressLabel.custom;
        address.customLabel = label;
      }
  }
}

/// Maps a vCard type token onto its model label; unknown tokens fall
/// back to `custom` only when the caller allows it.
void _parseWebsiteLabel(String label, Website website, bool defaultToCustom) {
  switch (label.toUpperCase()) {
    case 'HOME':
      website.label = WebsiteLabel.home;
      break;
    case 'HOMEPAGE':
      website.label = WebsiteLabel.homepage;
      break;
    case 'WORK':
      website.label = WebsiteLabel.work;
      break;
    case 'OTHER':
      website.label = WebsiteLabel.other;
      break;
    default:
      if (defaultToCustom) {
        website.label = WebsiteLabel.custom;
        website.customLabel = label;
      }
  }
}

/// Maps a vCard type token onto its model label; unknown tokens fall
/// back to `custom` only when the caller allows it.
void _parseEventLabel(String label, Event event, bool defaultToCustom) {
  switch (label.toUpperCase()) {
    case 'BIRTHDAY':
      event.label = EventLabel.birthday;
      break;
    case 'ANNIVERSARY':
      event.label = EventLabel.anniversary;
      break;
    case 'OTHER':
      event.label = EventLabel.other;
      break;
    default:
      if (defaultToCustom) {
        event.label = EventLabel.custom;
        event.customLabel = label;
      }
  }
}

/// Fans TYPE parameters (and any `X-ABLABEL` override) out through
/// [parseFunction]; valueless TYPE entries carry no data and are skipped.
void _parseLabel<T>(
  List<Param> params,
  String labelOverride,
  void Function(String, T, bool) parseFunction,
  T property,
) {
  if (labelOverride.isNotEmpty) {
    parseFunction(labelOverride, property, true);
  } else {
    for (final param in params) {
      if (param.key == 'TYPE') {
        // TYPE without a value carries no information; skip it instead of
        final value = param.value;
        if (value == null) continue;
        final types =
            (value.startsWith('"') && value.endsWith('"')
                    ? value.substring(1, value.length - 1)
                    : value)
                .split(',');
        for (final type in types) {
          parseFunction(type, property, false);
        }
      } else {
        parseFunction(param.key, property, false);
      }
    }
  }
}
