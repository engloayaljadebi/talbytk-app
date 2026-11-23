import 'dart:io';

import 'package:dio/dio.dart';

/// Backoff for durable order-create operations. Retry-After is a server-side
/// minimum delay, never permission to retry earlier than local backoff.
abstract final class OrderRetryPolicy {
  static Duration backoff(int attempts) {
    switch (attempts) {
      case 1:
        return const Duration(seconds: 30);
      case 2:
        return const Duration(minutes: 1);
      case 3:
        return const Duration(minutes: 5);
      default:
        return const Duration(minutes: 15);
    }
  }

  static DateTime nextAttemptAt({
    required Object error,
    required int attempts,
    DateTime? now,
  }) {
    final instant = (now ?? DateTime.now()).toUtc();
    // Drift stores SQLite DateTime values with whole-second precision by
    // default. Round UP before computing deadlines so persistence never
    // truncates Retry-After into an early retry.
    final safeInstant = DateTime.fromMicrosecondsSinceEpoch(
      ((instant.microsecondsSinceEpoch + Duration.microsecondsPerSecond - 1) ~/
              Duration.microsecondsPerSecond) *
          Duration.microsecondsPerSecond,
      isUtc: true,
    );
    final localDeadline = safeInstant.add(backoff(attempts));
    if (error is! DioException) return localDeadline;

    // Retry-After is defined for 429 and can also accompany 503.
    final status = error.response?.statusCode;
    if (status != 429 && status != 503) return localDeadline;

    final values = error.response?.headers['retry-after'];
    if (values == null || values.isEmpty) return localDeadline;
    final raw = values.first.trim();
    if (raw.isEmpty) return localDeadline;

    late DateTime serverDeadline;
    if (RegExp(r'^[0-9]+$').hasMatch(raw)) {
      final seconds = int.tryParse(raw);
      if (seconds == null) return localDeadline;
      // Bound an untrusted header to avoid an effectively stuck outbox.
      final boundedSeconds = seconds > 86400 ? 86400 : seconds;
      serverDeadline = safeInstant.add(Duration(seconds: boundedSeconds));
    } else {
      try {
        serverDeadline = HttpDate.parse(raw).toUtc();
      } catch (_) {
        return localDeadline;
      }
      final latestAllowed = safeInstant.add(const Duration(days: 1));
      if (serverDeadline.isAfter(latestAllowed)) {
        serverDeadline = latestAllowed;
      }
    }
    return serverDeadline.isAfter(localDeadline)
        ? serverDeadline
        : localDeadline;
  }
}
