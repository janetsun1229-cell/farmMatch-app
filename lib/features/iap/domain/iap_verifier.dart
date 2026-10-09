import 'store_receipt.dart';

abstract class IapVerifier {
  Future<VerifyResult> verify({
    required String platform,
    required String productId,
    required String receipt,
    String? packageName,
  });
}
