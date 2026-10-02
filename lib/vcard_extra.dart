/// An unrecognized vCard property preserved across import and export.
///
/// Importers meet vendor extensions (`X-*`), future RFC properties and
/// malformed-but-harmless lines. Instead of dropping them, [VCardParser]
/// collects them here and [Contact.toVCard] writes them back verbatim, so a
/// vCard survives a round trip without silent data loss.
class VCardExtra {
  /// Upper-cased property name such as `X-SPOUSE` or `VERSION`.
  final String name;

  /// Decoded property value with escapes resolved.
  final String value;

  /// Property parameters. A null value marks a bare vCard 2.1 flag.
  final Map<String, String?> params;

  /// Apple-style group (`item1` in `item1.X-FOO`), if the line had one.
  final String? group;

  /// Creates an extra property. [name] is stored upper-cased.
  VCardExtra({
    required String name,
    required this.value,
    Map<String, String?>? params,
    this.group,
  }) : name = name.toUpperCase(),
       params = params ?? const {};

  @override
  bool operator ==(Object other) =>
      other is VCardExtra &&
      other.name == name &&
      other.value == value &&
      other.group == group &&
      _mapsEqual(other.params, params);

  @override
  int get hashCode => Object.hash(
    name,
    value,
    group,
    Object.hashAllUnordered(
      params.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'VCardExtra(name=$name, value=$value, params=$params, group=$group)';

  /// Serializes the extra back to a vCard line.
  String toVCardLine() {
    final head = group != null ? '$group.$name' : name;
    if (params.isEmpty) return '$head:$value';
    final rendered = params.entries
        .map((e) => e.value == null ? e.key : '${e.key}=${e.value}')
        .join(';');
    return '$head;$rendered:$value';
  }
}

bool _mapsEqual(Map<String, String?> a, Map<String, String?> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) return false;
  }
  return true;
}
