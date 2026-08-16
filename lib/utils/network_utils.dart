import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

/// True if [error] looks like a connectivity problem (no network, DNS
/// failure, request timeout) rather than a genuine app/server error.
/// Used to decide whether to fall back to cached data / queue a mutation
/// for later, instead of surfacing the error to the user.
bool isNetworkError(Object error) {
  return error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is HttpException;
}
