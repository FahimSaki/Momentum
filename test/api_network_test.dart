import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:momentum/services/api_exception.dart';
import 'package:momentum/utils/network_utils.dart';

void main() {
  group('isNetworkError', () {
    test('treats connectivity failures as network errors', () {
      expect(isNetworkError(const SocketException('no route')), isTrue);
      expect(isNetworkError(TimeoutException('too slow')), isTrue);
      expect(isNetworkError(http.ClientException('connection closed')), isTrue);
      expect(isNetworkError(const HttpException('bad stream')), isTrue);
    });

    test('does not treat application errors as network errors', () {
      expect(isNetworkError(Exception('Task not found')), isFalse);
      expect(isNetworkError(const FormatException('bad json')), isFalse);
      expect(isNetworkError(StateError('not ready')), isFalse);
      expect(isNetworkError(const ApiException(500, 'Server error')), isFalse);
    });
  });

  group('ApiException.fromResponse', () {
    test('uses the server message and keeps the status code', () {
      final e = ApiException.fromResponse(
        http.Response('{"message":"Task not found"}', 404),
        fallback: 'Failed',
      );

      expect(e.statusCode, 404);
      expect(e.message, 'Task not found');
      expect(e.toString(), 'Task not found');
    });

    test('joins a validation errors list and prefers it over message', () {
      final e = ApiException.fromResponse(
        http.Response(
          '{"message":"Validation error","errors":["Name is required","Too long"]}',
          400,
        ),
        fallback: 'Failed',
      );

      expect(e.message, 'Name is required, Too long');
    });

    test('an empty errors list falls back to message', () {
      final e = ApiException.fromResponse(
        http.Response('{"message":"Bad request","errors":[]}', 400),
        fallback: 'Failed',
      );

      expect(e.message, 'Bad request');
    });

    test('uses the fallback for a non-JSON body', () {
      final e = ApiException.fromResponse(
        http.Response('<html>502 Bad Gateway</html>', 502),
        fallback: 'Failed to fetch tasks',
      );

      expect(e.statusCode, 502);
      expect(e.message, 'Failed to fetch tasks');
    });

    test(
      'uses the fallback when the JSON is not an object or has no message',
      () {
        expect(
          ApiException.fromResponse(
            http.Response('[1,2,3]', 500),
            fallback: 'Fallback',
          ).message,
          'Fallback',
        );
        expect(
          ApiException.fromResponse(
            http.Response('{"message":""}', 500),
            fallback: 'Fallback',
          ).message,
          'Fallback',
        );
        expect(
          ApiException.fromResponse(
            http.Response('{}', 500),
            fallback: 'Fallback',
          ).message,
          'Fallback',
        );
      },
    );

    test('isUnauthorized is true only for 401', () {
      expect(const ApiException(401, 'x').isUnauthorized, isTrue);
      expect(const ApiException(403, 'x').isUnauthorized, isFalse);
      expect(const ApiException(500, 'x').isUnauthorized, isFalse);
    });
  });
}
