/// Base type for domain-layer errors. Repository implementations catch
/// data-layer exceptions (e.g. `ApiException`) and rethrow as one of these,
/// so use cases and controllers never need to know about the REST layer.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The request never reached the server (no connection, DNS, timeout...).
class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Could not reach the server. Check your connection.']);
}

/// The server responded but rejected the request — [message] is already
/// the backend's own `detail` string where available.
class ServerFailure extends AppFailure {
  const ServerFailure(super.message);
}
