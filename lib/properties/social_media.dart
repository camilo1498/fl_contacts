import 'package:fl_contacts/vcard.dart';

/// An instant-messaging or social profile. iOS reports both kinds here;
/// anything outside the known set lands on `custom` with its raw name.
class SocialMedia {
  /// Handle, username or login.
  String userName;

  /// Platform, defaulting to [SocialMediaLabel.other].
  SocialMediaLabel label;

  /// Free-form platform used only with [SocialMediaLabel.custom].
  String customLabel;

  /// Creates a profile for [userName] with an optional platform.
  SocialMedia(
    this.userName, {
    this.label = SocialMediaLabel.other,
    this.customLabel = '',
  });

  /// Decodes a profile from its channel map, defaulting unknown labels.
  factory SocialMedia.fromJson(Map<String, dynamic> json) => SocialMedia(
    (json['userName'] as String?) ?? '',
    label: SocialMediaLabel.fromValue(
      json['label'] as String?,
      SocialMediaLabel.other,
    ),
    customLabel: (json['customLabel'] as String?) ?? '',
  );

  /// Encodes the profile for the channel.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'userName': userName,
    'label': label.value,
    'customLabel': customLabel,
  };

  @override
  int get hashCode => Object.hash(userName, label, customLabel);

  @override
  bool operator ==(Object other) =>
      other is SocialMedia &&
      other.userName == userName &&
      other.label == label &&
      other.customLabel == customLabel;

  @override
  String toString() =>
      'SocialMedia(userName=$userName, label=$label, customLabel=$customLabel)';

  /// Emits the profile as `IMPP` with protocol and username.
  List<String> toVCard() {
    final protocol = label == SocialMediaLabel.custom
        ? customLabel
        : label.value;
    return ['IMPP:${vCardEncode(protocol)}:${vCardEncode(userName)}'];
  }
}

/// Social media labels.
///
/// | Label        | Android | iOS |
/// |--------------|:-------:|:---:|
/// | aim          | ✔       | ✔   |
/// | baiduTieba   | ⨯       | ⨯   |
/// | discord      | ⨯       | ⨯   |
/// | facebook     | ⨯       | ✔   |
/// | flickr       | ⨯       | ✔   |
/// | gaduGadu     | ⨯       | ✔   |
/// | gameCenter   | ⨯       | ✔   |
/// | googleTalk   | ✔       | ✔   |
/// | icq          | ✔       | ✔   |
/// | instagram    | ⨯       | ⨯   |
/// | jabber       | ✔       | ✔   |
/// | line         | ⨯       | ⨯   |
/// | linkedIn     | ⨯       | ✔   |
/// | medium       | ⨯       | ⨯   |
/// | messenger    | ⨯       | ⨯   |
/// | msn          | ✔       | ✔   |
/// | myspace      | ⨯       | ✔   |
/// | netmeeting   | ✔       | ⨯   |
/// | pinterest    | ⨯       | ⨯   |
/// | qqchat       | ✔       | ✔   |
/// | qzone        | ⨯       | ⨯   |
/// | reddit       | ⨯       | ⨯   |
/// | sinaWeibo    | ⨯       | ✔   |
/// | skype        | ✔       | ✔   |
/// | snapchat     | ⨯       | ⨯   |
/// | telegram     | ⨯       | ⨯   |
/// | tencentWeibo | ⨯       | ✔   |
/// | tikTok       | ⨯       | ⨯   |
/// | tumblr       | ⨯       | ⨯   |
/// | twitter      | ⨯       | ✔   |
/// | viber        | ⨯       | ⨯   |
/// | wechat       | ⨯       | ⨯   |
/// | whatsapp     | ⨯       | ⨯   |
/// | yahoo        | ✔       | ✔   |
/// | yelp         | ✔       | ✔   |
/// | youtube      | ⨯       | ⨯   |
/// | zoom         | ⨯       | ⨯   |
/// | other        | ⨯       | ⨯   |
/// | custom       | ✔       | ✔   |
/// Social and IM platforms across Android and iOS.
enum SocialMediaLabel {
  aim('aim'),
  baiduTieba('baiduTieba'),
  discord('discord'),
  facebook('facebook'),
  flickr('flickr'),
  gaduGadu('gaduGadu'),
  gameCenter('gameCenter'),
  googleTalk('googleTalk'),
  icq('icq'),
  instagram('instagram'),
  jabber('jabber'),
  line('line'),
  linkedIn('linkedIn'),
  medium('medium'),
  messenger('messenger'),
  msn('msn'),
  mySpace('mySpace'),
  netmeeting('netmeeting'),
  pinterest('pinterest'),
  qqchat('qqchat'),
  qzone('qzone'),
  reddit('reddit'),
  sinaWeibo('sinaWeibo'),
  skype('skype'),
  snapchat('snapchat'),
  telegram('telegram'),
  tencentWeibo('tencentWeibo'),
  tikTok('tikTok'),
  tumblr('tumblr'),
  twitter('twitter'),
  viber('viber'),
  wechat('wechat'),
  whatsapp('whatsapp'),
  yahoo('yahoo'),
  yelp('yelp'),
  youtube('youtube'),
  zoom('zoom'),
  other('other'),
  custom('custom');

  /// Wire string used on the channel and in JSON.
  final String value;

  /// Creates a label with its wire [value].
  const SocialMediaLabel(this.value);

  /// Parses a wire string, returning [fallback] for unknown values.
  static SocialMediaLabel fromValue(String? value, SocialMediaLabel fallback) =>
      SocialMediaLabel.values.firstWhere(
        (e) => e.value == value,
        orElse: () => fallback,
      );
}

/// Case-insensitive lookup for importer protocol names.
final Map<String, SocialMediaLabel> lowerCaseStringToSocialMediaLabel = {
  'aim': SocialMediaLabel.aim,
  'baidu': SocialMediaLabel.baiduTieba,
  'baidutieba': SocialMediaLabel.baiduTieba,
  'discord': SocialMediaLabel.discord,
  'facebook': SocialMediaLabel.facebook,
  'flickr': SocialMediaLabel.flickr,
  'gadugadu': SocialMediaLabel.gaduGadu,
  'gamecenter': SocialMediaLabel.gameCenter,
  'googletalk': SocialMediaLabel.googleTalk,
  'icq': SocialMediaLabel.icq,
  'instagram': SocialMediaLabel.instagram,
  'jabber': SocialMediaLabel.jabber,
  'line': SocialMediaLabel.line,
  'linkedin': SocialMediaLabel.linkedIn,
  'medium': SocialMediaLabel.medium,
  'messenger': SocialMediaLabel.messenger,
  'msn': SocialMediaLabel.msn,
  'myspace': SocialMediaLabel.mySpace,
  'netmeeting': SocialMediaLabel.netmeeting,
  'pinterest': SocialMediaLabel.pinterest,
  'qq': SocialMediaLabel.qqchat,
  'qqchat': SocialMediaLabel.qqchat,
  'qzone': SocialMediaLabel.qzone,
  'reddit': SocialMediaLabel.reddit,
  'sina': SocialMediaLabel.sinaWeibo,
  'sinaweibo': SocialMediaLabel.sinaWeibo,
  'skype': SocialMediaLabel.skype,
  'snapchat': SocialMediaLabel.snapchat,
  'telegram': SocialMediaLabel.telegram,
  'tencent': SocialMediaLabel.tencentWeibo,
  'tencentweibo': SocialMediaLabel.tencentWeibo,
  'tiktok': SocialMediaLabel.tikTok,
  'tumblr': SocialMediaLabel.tumblr,
  'twitter': SocialMediaLabel.twitter,
  'viber': SocialMediaLabel.viber,
  'wechat': SocialMediaLabel.wechat,
  'whatsapp': SocialMediaLabel.whatsapp,
  'yahoo': SocialMediaLabel.yahoo,
  'yelp': SocialMediaLabel.yelp,
  'youtube': SocialMediaLabel.youtube,
  'zoom': SocialMediaLabel.zoom,
  'other': SocialMediaLabel.other,
  'custom': SocialMediaLabel.custom,
};
