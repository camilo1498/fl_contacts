/// A contact group (iOS) or label (Android); contacts may belong to many.
class Group {
  /// Database identifier. Empty for groups not yet inserted.
  String id;

  /// Display name.
  String name;

  /// Creates a group from [id] and [name].
  Group(this.id, this.name);

  /// Decodes a group from its channel map.
  factory Group.fromJson(Map<String, dynamic> json) =>
      Group((json['id'] as String?) ?? '', (json['name'] as String?) ?? '');

  /// Encodes the group for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};

  @override
  int get hashCode => Object.hash(id, name);

  @override
  bool operator ==(Object other) =>
      other is Group && other.id == id && other.name == name;

  @override
  String toString() => 'Group(id=$id, name=$name)';
}
