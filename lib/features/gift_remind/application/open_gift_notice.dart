import '../../deeplink/domain/deep_link.dart';
import '../../deeplink/domain/deep_link_parser.dart';
import '../domain/gift_notice.dart';

class OpenGiftNotice {
  const OpenGiftNotice();

  DeepLinkTarget call(GiftNotice notice) {
    final intent = DeepLinkParser.parse(notice.link);
    if (intent == null || intent.kind != DeepLinkKind.gift) {
      return const DeepLinkTarget(location: '/friends');
    }
    return DeepLinkNavigator.resolve(
      intent: intent,
      canPlay: (_) => false,
    );
  }
}
