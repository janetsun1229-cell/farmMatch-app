import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/iap_verifier.dart';
import '../domain/store_receipt.dart';

/// `POST /v1/iap/verify`. An empty [baseUrl] uses the offline stub so CI and
/// local play can grant after a fake receipt. Production must set the API
/// base URL; the stub is not a trusted verifier.
class IapApi implements IapVerifier {
  IapApi({
    http.Client? client,
    this.baseUrl = '',
    this.verifyPath = '/v1/iap/verify',
    this.allowOfflineStub = true,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final String verifyPath;
  final bool allowOfflineStub;

  @override
  Future<VerifyResult> verify({
    required String platform,
    required String productId,
    required String receipt,
    String? packageName,
  }) async {
    if (receipt.isEmpty) {
      return VerifyResult.failure('IAP_VERIFY_FAILED', 'Missing receipt.');
    }
    if (baseUrl.isEmpty) {
      if (!allowOfflineStub) {
        return VerifyResult.failure(
            'IAP_VERIFY_FAILED', 'Receipt check is offline.');
      }
      return VerifyResult.success(receipt);
    }
    try {
      final root = Uri.parse(baseUrl);
      final uri = root.replace(
          path: verifyPath.startsWith('/')
              ? verifyPath
              : '${root.path}$verifyPath');
      final response = await _client
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode({
              'platform': platform,
              'productId': productId,
              'receipt': receipt,
              'purchaseToken': receipt,
              if (packageName != null) 'packageName': packageName,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _errorBody(response.body);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['ok'] == false) {
        return VerifyResult.failure(
          decoded['code'] as String? ?? 'IAP_VERIFY_FAILED',
          decoded['message'] as String? ?? 'Receipt check failed.',
        );
      }
      final txn = decoded is Map ? decoded['transactionId'] as String? : null;
      return VerifyResult.success(txn ?? receipt);
    } catch (_) {
      return VerifyResult.failure('IAP_VERIFY_FAILED', 'Receipt check failed.');
    }
  }

  VerifyResult _errorBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return VerifyResult.failure(
          decoded['code'] as String? ?? 'IAP_VERIFY_FAILED',
          decoded['message'] as String? ?? 'Receipt check failed.',
        );
      }
    } catch (_) {}
    return VerifyResult.failure('IAP_VERIFY_FAILED', 'Receipt check failed.');
  }
}
