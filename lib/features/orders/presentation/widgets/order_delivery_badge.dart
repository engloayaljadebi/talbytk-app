import 'package:flutter/material.dart';

import '../providers/order_delivery_status_provider.dart';

/// A transport-status badge, separate from the order's commercial lifecycle.
class OrderDeliveryBadge extends StatelessWidget {
  const OrderDeliveryBadge({super.key, required this.status});

  final OrderDeliveryStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (status) {
      OrderDeliveryStatus.savedLocally => (
        Icons.save_outlined,
        colors.tertiary,
      ),
      OrderDeliveryStatus.awaitingRetry => (
        Icons.sync_problem_outlined,
        colors.tertiary,
      ),
      OrderDeliveryStatus.failed => (Icons.error_outline_rounded, colors.error),
      OrderDeliveryStatus.sent => (Icons.cloud_done_outlined, colors.primary),
      OrderDeliveryStatus.checking => (
        Icons.hourglass_empty_rounded,
        colors.onSurfaceVariant,
      ),
    };

    return Container(
      key: ValueKey<String>('order-delivery-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              status.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
