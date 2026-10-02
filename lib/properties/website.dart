import 'package:fl_contacts/vcard.dart';

/// A labeled website URL.
class Website {
  /// The URL itself.
  String url;

  /// Label, defaulting to [WebsiteLabel.homepage].
  WebsiteLabel label;

  /// Free-form label used only with [WebsiteLabel.custom].
  String customLabel;

  /// Creates a website for [url] with an optional label.
  Website(
    this.url, {
    this.label = WebsiteLabel.homepage,
    this.customLabel = '',
  });

  /// Decodes a website from its channel map, defaulting unknown labels.
  factory Website.fromJson(Map<String, dynamic> json) => Website(
    (json['url'] as String?) ?? '',
    label: WebsiteLabel.fromValue(
      json['label'] as String?,
      WebsiteLabel.homepage,
    ),
    customLabel: (json['customLabel'] as String?) ?? '',
  );

  /// Encodes the website for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'label': label.value,
    'customLabel': customLabel,
  };

  @override
  int get hashCode => Object.hash(url, label, customLabel);

  @override
  bool operator ==(Object other) =>
      other is Website &&
      other.url == url &&
      other.label == label &&
      other.customLabel == customLabel;

  @override
  String toString() =>
      'Website(url=$url, label=$label, customLabel=$customLabel)';

  /// Emits the URL as `URL`.
  List<String> toVCard() {
    return ['URL:${vCardEncode(url)}'];
  }
}

/// Website labels.
///
/// | Label    | Android | iOS |
/// |----------|:-------:|:---:|
/// | blog     | ✔       | ⨯   |
/// | ftp      | ✔       | ⨯   |
/// | home     | ✔       | ✔   |
/// | homepage | ✔       | ✔   |
/// | profile  | ✔       | ⨯   |
/// | school   | ⨯       | ✔   |
/// | work     | ✔       | ✔   |
/// | other    | ✔       | ✔   |
/// | custom   | ✔       | ✔   |
/// Website labels across Android and iOS.
enum WebsiteLabel {
  blog('blog'),
  ftp('ftp'),
  home('home'),
  homepage('homepage'),
  profile('profile'),
  school('school'),
  work('work'),
  other('other'),
  custom('custom');

  /// Wire string used on the channel and in JSON.
  final String value;

  /// Creates a label with its wire [value].
  const WebsiteLabel(this.value);

  /// Parses a wire string, returning [fallback] for unknown values.
  static WebsiteLabel fromValue(String? value, WebsiteLabel fallback) =>
      WebsiteLabel.values.firstWhere(
        (e) => e.value == value,
        orElse: () => fallback,
      );
}
