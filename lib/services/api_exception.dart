/// Thrown by [ApiClient] whenever the backend responds with a non-2xx
/// status. [message] is already unwrapped from the backend's
/// `{"detail": "..."}` response body where possible.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}
