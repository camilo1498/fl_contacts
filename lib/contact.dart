import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:fl_contacts/config.dart';
import 'package:fl_contacts/properties/account.dart';
import 'package:fl_contacts/properties/address.dart';
import 'package:fl_contacts/properties/email.dart';
import 'package:fl_contacts/properties/event.dart';
import 'package:fl_contacts/properties/group.dart';
import 'package:fl_contacts/properties/name.dart';
import 'package:fl_contacts/properties/note.dart';
import 'package:fl_contacts/properties/organization.dart';
import 'package:fl_contacts/properties/phone.dart';
import 'package:fl_contacts/properties/social_media.dart';
import 'package:fl_contacts/properties/website.dart';
import 'package:fl_contacts/vcard.dart';
import 'package:fl_contacts/vcard_extra.dart';

/// A device contact with an ID, a display name and optional rich data.
///
/// Properties ([phones], [emails], …) are populated only when fetched with
/// `withProperties: true`; [thumbnail]/[photo] only with the matching photo
/// flags. Everything is non-nullable except the two images and [Event.year];
/// missing values arrive as empty strings, empty lists or label defaults.
/// [accounts] is informational (plus required for Android updates) and
/// [groups] holds label/group membership when requested.
class Contact {
  /// Database identifier. Empty for contacts not yet inserted.
  String id;

  /// Formatted display name, always fetched.
  String displayName;

  /// Low-resolution picture. Null unless fetched and present.
  Uint8List? thumbnail;

  /// Full-resolution picture. Null unless fetched and present.
  Uint8List? photo;

  /// Best available image: [photo] first, [thumbnail] as fallback.
  Uint8List? get photoOrThumbnail => photo ?? thumbnail;

  /// Starred/favorite marker. Android only; always false on iOS.
  bool isStarred;

  /// Structured name parts.
  Name name;

  /// Phone numbers.
  List<Phone> phones;

  /// Email addresses.
  List<Email> emails;

  /// Postal addresses, formatted plus structured.
  List<Address> addresses;

  /// Jobs and affiliations.
  List<Organization> organizations;

  /// Web addresses.
  List<Website> websites;

  /// Instant-messaging and social profiles.
  List<SocialMedia> socialMedias;

  /// Birthdays, anniversaries and custom dates.
  List<Event> events;

  /// Free-form notes. A single entry on iOS, several on Android.
  List<Note> notes;

  /// Raw accounts (Android) or containers (iOS). Excluded from equality.
  List<Account> accounts;

  /// Group (iOS) or label (Android) membership.
  List<Group> groups;

  /// Whether [thumbnail] was requested on the last fetch.
  bool thumbnailFetched = true;

  /// Whether [photo] was requested on the last fetch.
  bool photoFetched = true;

  /// Whether this is a unified contact rather than a raw one.
  bool isUnified = true;

  /// Whether name, phones, emails and friends were requested on the last fetch.
  bool propertiesFetched = true;

  /// Unrecognized vCard properties preserved across import and export.
  ///
  /// Populated by [Contact.fromVCard] for lines the importer does not model
  /// (typically vendor `X-*` extensions) and written back verbatim by
  /// [toVCard], so round trips lose nothing. Excluded from equality,
  /// hash code and channel payloads: the native stores never see it.
  List<VCardExtra> extras = [];

  /// Creates an empty contact. Prefer fetching or [Contact.fromVCard] to
  /// populate one; use [insert] to persist it.
  Contact({
    this.id = '',
    this.displayName = '',
    this.thumbnail,
    this.photo,
    this.isStarred = false,
    Name? name,
    List<Phone>? phones,
    List<Email>? emails,
    List<Address>? addresses,
    List<Organization>? organizations,
    List<Website>? websites,
    List<SocialMedia>? socialMedias,
    List<Event>? events,
    List<Note>? notes,
    List<Account>? accounts,
    List<Group>? groups,
  }) : name = name ?? Name(),
       phones = phones ?? <Phone>[],
       emails = emails ?? <Email>[],
       addresses = addresses ?? <Address>[],
       organizations = organizations ?? <Organization>[],
       websites = websites ?? <Website>[],
       socialMedias = socialMedias ?? <SocialMedia>[],
       events = events ?? <Event>[],
       notes = notes ?? <Note>[],
       accounts = accounts ?? <Account>[],
       groups = groups ?? <Group>[];

  /// Decodes a contact from its platform-channel map. Missing entries fall
  /// back to empty values; binary photo data accepts both typed and plain
  /// byte lists.
  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
    id: (json['id'] as String?) ?? '',
    displayName: (json['displayName'] as String?) ?? '',
    thumbnail: _bytesFromJson(json['thumbnail']),
    photo: _bytesFromJson(json['photo']),
    isStarred: (json['isStarred'] as bool?) ?? false,
    name: Name.fromJson(Map<String, dynamic>.from(json['name'] ?? {})),
    phones: ((json['phones'] as List?) ?? [])
        .map((x) => Phone.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    emails: ((json['emails'] as List?) ?? [])
        .map((x) => Email.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    addresses: ((json['addresses'] as List?) ?? [])
        .map((x) => Address.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    organizations: ((json['organizations'] as List?) ?? [])
        .map((x) => Organization.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    websites: ((json['websites'] as List?) ?? [])
        .map((x) => Website.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    socialMedias: ((json['socialMedias'] as List?) ?? [])
        .map((x) => SocialMedia.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    events: ((json['events'] as List?) ?? [])
        .map((x) => Event.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    notes: ((json['notes'] as List?) ?? [])
        .map((x) => Note.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    accounts: ((json['accounts'] as List?) ?? [])
        .map((x) => Account.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
    groups: ((json['groups'] as List?) ?? [])
        .map((x) => Group.fromJson(Map<String, dynamic>.from(x as Map)))
        .toList(),
  );

  /// Accepts typed bytes or plain byte lists; anything else means "no photo".
  static Uint8List? _bytesFromJson(dynamic value) {
    if (value == null) return null;
    if (value is Uint8List) return value;
    if (value is List) return Uint8List.fromList(List<int>.from(value));
    return null;
  }

  /// Encodes the contact for the platform channel. The image flags let
  /// callers omit heavy photo bytes on update round-trips.
  Map<String, dynamic> toJson({
    bool withThumbnail = true,
    bool withPhoto = true,
  }) => <String, dynamic>{
    'id': id,
    'displayName': displayName,
    'thumbnail': withThumbnail ? thumbnail : null,
    'photo': withPhoto ? photo : null,
    'isStarred': isStarred,
    'name': name.toJson(),
    'phones': phones.map((x) => x.toJson()).toList(),
    'emails': emails.map((x) => x.toJson()).toList(),
    'addresses': addresses.map((x) => x.toJson()).toList(),
    'organizations': organizations.map((x) => x.toJson()).toList(),
    'websites': websites.map((x) => x.toJson()).toList(),
    'socialMedias': socialMedias.map((x) => x.toJson()).toList(),
    'events': events.map((x) => x.toJson()).toList(),
    'notes': notes.map((x) => x.toJson()).toList(),
    'accounts': accounts.map((x) => x.toJson()).toList(),
    'groups': groups.map((x) => x.toJson()).toList(),
  };

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    Object.hashAll(thumbnail ?? const <int>[]),
    Object.hashAll(photo ?? const <int>[]),
    isStarred,
    name,
    Object.hashAll(phones),
    Object.hashAll(emails),
    Object.hashAll(addresses),
    Object.hashAll(organizations),
    Object.hashAll(websites),
    Object.hashAll(socialMedias),
    Object.hashAll(events),
    Object.hashAll(notes),
  );

  @override
  bool operator ==(Object other) =>
      other is Contact &&
      other.id == id &&
      other.displayName == displayName &&
      listEquals(other.thumbnail, thumbnail) &&
      listEquals(other.photo, photo) &&
      other.isStarred == isStarred &&
      other.name == name &&
      listEquals(other.phones, phones) &&
      listEquals(other.emails, emails) &&
      listEquals(other.addresses, addresses) &&
      listEquals(other.organizations, organizations) &&
      listEquals(other.websites, websites) &&
      listEquals(other.socialMedias, socialMedias) &&
      listEquals(other.events, events) &&
      listEquals(other.notes, notes);

  @override
  String toString() =>
      'Contact(id=$id, displayName=$displayName, thumbnail=$thumbnail, '
      'photo=$photo, isStarred=$isStarred, name=$name, phones=$phones, '
      'emails=$emails, addresses=$addresses, organizations=$organizations, '
      'websites=$websites, socialMedias=$socialMedias, events=$events, '
      'notes=$notes, accounts=$accounts, groups=$groups)';

  /// Serializes the contact to a vCard string.
  ///
  /// Emits vCard 3.0 by default, the widest-supported flavor; select
  /// [VCardVersion.v4] via `flContactsConfig` for the modern format.
  /// [productId] stamps the origin and [includeDate] adds a revision line.
  String toVCard({
    bool withPhoto = true,
    String? productId,
    bool includeDate = false,
  }) {
    final bool v4 = flContactsConfig.vCardVersion == VCardVersion.v4;
    final lines = <String>['BEGIN:VCARD', v4 ? 'VERSION:4.0' : 'VERSION:3.0'];
    if (productId != null) {
      lines.add('PRODID:$productId');
    }
    if (includeDate) {
      lines.add('REV:${DateTime.now().toIso8601String()}');
    }
    if (displayName.isNotEmpty) {
      lines.add('FN:${vCardEncode(displayName)}');
    }
    final photoOrThumbnail = this.photoOrThumbnail;
    if (withPhoto && photoOrThumbnail != null) {
      final encoding = vCardEncode(base64.encode(photoOrThumbnail));
      final prefix = v4
          ? 'PHOTO:data:image/jpeg;base64,'
          : 'PHOTO;ENCODING=b;TYPE=JPEG:';
      lines.add(prefix + encoding);
    }
    lines.addAll([
      ...name.toVCard(),
      for (final phone in phones) ...phone.toVCard(),
      for (final email in emails) ...email.toVCard(),
      for (final address in addresses) ...address.toVCard(),
      for (final organization in organizations) ...organization.toVCard(),
      for (final website in websites) ...website.toVCard(),
      for (final socialMedia in socialMedias) ...socialMedia.toVCard(),
      for (final event in events) ...event.toVCard(),
      for (final note in notes) ...note.toVCard(),
      for (final extra in extras) extra.toVCardLine(),
    ]);
    lines.add('END:VCARD');
    return lines.join('\n');
  }

  /// Parses a vCard string into a new contact.
  ///
  /// Lines the importer does not model land in [extras] for lossless export.
  factory Contact.fromVCard(String vCard) {
    final c = Contact();
    VCardParser().parse(vCard, c);
    return c;
  }

  /// Parses a document holding one or more vCards.
  ///
  /// Cards are split on unfolded `BEGIN:VCARD` boundaries; empty chunks are
  /// skipped. Each card keeps its own [extras].
  static List<Contact> fromVCardList(String vCards) {
    final unfolded = VCardParser().unfold(vCards);
    final chunks = unfolded.split('BEGIN:VCARD');
    final contacts = <Contact>[];
    for (final chunk in chunks) {
      if (chunk.trim().isEmpty) continue;
      contacts.add(Contact.fromVCard('BEGIN:VCARD$chunk'));
    }
    return contacts;
  }

  /// Serializes several contacts, one card per contact.
  static String listToVCard(
    List<Contact> contacts, {
    bool withPhoto = true,
    String? productId,
    bool includeDate = false,
  }) => contacts
      .map(
        (c) => c.toVCard(
          withPhoto: withPhoto,
          productId: productId,
          includeDate: includeDate,
        ),
      )
      .join('\n');

  /// Collapses duplicated properties in place.
  ///
  /// Third-party sync adapters often return the same phone or email twice.
  /// Phones compare by normalized (or raw) number, emails by address,
  /// everything else by value.
  void deduplicateProperties() {
    phones = _deduplicateProperty(
      phones,
      (x) => (x.normalizedNumber.isNotEmpty ? x.normalizedNumber : x.number),
    );
    emails = _deduplicateProperty(emails, (x) => x.address);
    addresses = _deduplicateProperty(addresses);
    organizations = _deduplicateProperty(organizations);
    websites = _deduplicateProperty(websites);
    socialMedias = _deduplicateProperty(socialMedias);
    events = _deduplicateProperty(events);
    notes = _deduplicateProperty(notes);
  }

  /// Deduplicates [list] by [keyFn], keeping the first occurrence of each key.
  ///
  /// Keys are compared by value (unlike the previous hashCode-based approach,
  /// which could merge distinct properties on hash collision).
  /// Keeps the first entry per [keyFn] key, comparing keys by value so hash
  /// collisions can never merge distinct properties.
  static List<T> _deduplicateProperty<T>(
    List<T> list, [
    Object Function(T)? keyFn,
  ]) {
    keyFn ??= (T x) => x.hashCode;
    final deduplicated = <T>[];
    final seen = <Object>{};
    for (final element in list) {
      final key = keyFn(element);
      if (seen.add(key)) {
        deduplicated.add(element);
      }
    }
    return deduplicated;
  }
}
