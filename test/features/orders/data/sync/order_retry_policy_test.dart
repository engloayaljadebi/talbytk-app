import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talbytk/features/orders/data/sync/order_retry_policy.dart';

void main() {
  final now = DateTime.utc(2026, 11, 23, 12);

  DioException failure(int status, {String? retryAfter}) {
    final request = RequestOptions(path: '/orders');
    return DioException(
      requestOptions: request,
      response: Response<dynamic>(
        requestOptions: request,
        statusCode: status,
        headers: Headers.fromMap({
          if (retryAfter != null) 'retry-after': [retryAfter],
        }),
      ),
      type: DioExceptionType.badResponse,
    );
  }

  test('429 delta seconds extends the local retry deadline', () {
    final deadline = OrderRetryPolicy.nextAttemptAt(
      error: failure(429, retryAfter: '120'),
      attempts: 1,
      now: now,
    );
    expect(deadline, now.add(const Duration(seconds: 120)));
  });

  test('rounds Retry-After deadlines up to SQLite second precision', () {
    final fractionalNow = now.add(const Duration(milliseconds: 250));
    final deadline = OrderRetryPolicy.nextAttemptAt(
      error: failure(429, retryAfter: '120'),
      attempts: 1,
      now: fractionalNow,
    );
    expect(deadline, now.add(const Duration(seconds: 121)));
    expect(
      deadline.isBefore(fractionalNow.add(const Duration(seconds: 120))),
      isFalse,
    );

    final localDeadline = OrderRetryPolicy.nextAttemptAt(
      error: failure(422),
      attempts: 1,
      now: fractionalNow,
    );
    expect(localDeadline, now.add(const Duration(seconds: 31)));
  });

  test('429 HTTP-date is supported', () {
    final date = now.add(const Duration(minutes: 3));
    final deadline = OrderRetryPolicy.nextAttemptAt(
      error: failure(429, retryAfter: HttpDate.format(date)),
      attempts: 1,
      now: now,
    );
    expect(deadline, date);
  });

  test('short, missing and invalid values preserve local backoff', () {
    for (final value in ['2', 'invalid', '-30', '']) {
      expect(
        OrderRetryPolicy.nextAttemptAt(
          error: failure(429, retryAfter: value),
          attempts: 2,
          now: now,
        ),
        now.add(const Duration(minutes: 1)),
      );
    }
    expect(
      OrderRetryPolicy.nextAttemptAt(
        error: failure(429),
        attempts: 1,
        now: now,
      ),
      now.add(const Duration(seconds: 30)),
    );
  });

  test('503 may supply Retry-After, 422 may not', () {
    expect(
      OrderRetryPolicy.nextAttemptAt(
        error: failure(503, retryAfter: '90'),
        attempts: 1,
        now: now,
      ),
      now.add(const Duration(seconds: 90)),
    );
    expect(
      OrderRetryPolicy.nextAttemptAt(
        error: failure(422, retryAfter: '90'),
        attempts: 1,
        now: now,
      ),
      now.add(const Duration(seconds: 30)),
    );
  });

  test('untrusted huge values are bounded to one day', () {
    expect(
      OrderRetryPolicy.nextAttemptAt(
        error: failure(429, retryAfter: '999999999999999999999'),
        attempts: 1,
        now: now,
      ),
      now.add(const Duration(seconds: 30)),
    );
    expect(
      OrderRetryPolicy.nextAttemptAt(
        error: failure(429, retryAfter: '999999'),
        attempts: 1,
        now: now,
      ),
      now.add(const Duration(days: 1)),
    );
  });
}
