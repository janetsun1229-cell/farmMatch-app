/// Native In-App Review. The CI build uses a fake that records the request.
/// A store build can call StoreKit or Play In-App Review here. When that call
/// is unavailable the skippable Enjoying Farm Match sheet is the fallback.
abstract class StoreReviewPort {
  Future<bool> requestReview();
}
