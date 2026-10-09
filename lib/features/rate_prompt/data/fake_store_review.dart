import '../domain/ports/store_review_port.dart';

class FakeStoreReview implements StoreReviewPort {
  var requests = 0;

  @override
  Future<bool> requestReview() async {
    requests += 1;
    return true;
  }
}
