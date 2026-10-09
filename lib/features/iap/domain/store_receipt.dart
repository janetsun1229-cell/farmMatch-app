class StoreReceipt {
  const StoreReceipt({
    required this.productId,
    required this.receipt,
    required this.transactionId,
    required this.consumable,
  });

  final String productId;
  final String receipt;
  final String transactionId;
  final bool consumable;
}

class IapException implements Exception {
  const IapException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code $message';
}

class VerifyResult {
  const VerifyResult(
      {required this.ok,
      required this.code,
      required this.message,
      this.transactionId});

  final bool ok;
  final String code;
  final String message;
  final String? transactionId;

  factory VerifyResult.success(String transactionId) {
    return VerifyResult(
        ok: true,
        code: 'OK',
        message: 'Verified',
        transactionId: transactionId);
  }

  factory VerifyResult.failure(String code, String message) {
    return VerifyResult(ok: false, code: code, message: message);
  }
}

class PurchaseOutcome {
  const PurchaseOutcome(
      {required this.ok, this.code, this.message, this.productId});

  final bool ok;
  final String? code;
  final String? message;
  final String? productId;

  factory PurchaseOutcome.success(String productId) =>
      PurchaseOutcome(ok: true, productId: productId);

  factory PurchaseOutcome.failure(String code, String message) {
    return PurchaseOutcome(ok: false, code: code, message: message);
  }
}

class RestoreOutcome {
  const RestoreOutcome({required this.restoredSkus, this.message});

  final List<String> restoredSkus;
  final String? message;

  bool get restoredAny => restoredSkus.isNotEmpty;
}
