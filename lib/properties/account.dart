import 'package:flutter/foundation.dart';

/// Account backing a contact: raw sync accounts on Android (several per
/// contact), containers on iOS (at most one). Informational in most flows.
class Account {
  /// Raw-contact identifier within its account.
  String rawId;

  /// Account type such as `com.google`.
  String type;

  /// Account name such as `john.doe@gmail.com`.
  String name;

  /// Data kinds this account contributes. Android only.
  List<String> mimetypes;

  /// Creates an account record from its four fields.
  Account(this.rawId, this.type, this.name, this.mimetypes);

  /// Decodes an account from its channel map.
  factory Account.fromJson(Map<String, dynamic> json) => Account(
    (json['rawId'] as String?) ?? '',
    (json['type'] as String?) ?? '',
    (json['name'] as String?) ?? '',
    (json['mimetypes'] as List?)?.map((e) => e as String).toList() ?? [],
  );

  /// Encodes the account for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'rawId': rawId,
    'type': type,
    'name': name,
    'mimetypes': mimetypes,
  };

  @override
  int get hashCode => Object.hash(rawId, type, name, Object.hashAll(mimetypes));

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.rawId == rawId &&
      other.type == type &&
      other.name == name &&
      listEquals(other.mimetypes, mimetypes);

  @override
  String toString() =>
      'Account(rawId=$rawId, type=$type, name=$name, mimetypes=$mimetypes)';
}
