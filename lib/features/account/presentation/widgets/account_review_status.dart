import 'package:flutter/material.dart';

import '../providers/account_business_approvals_provider.dart';

/// Icon-only edit action shown beside the account identity.
///
/// Presentation only: the caller keeps the existing navigation callback.
class ProfileEditIconButton extends StatelessWidget {
  const ProfileEditIconButton({required this.onPressed, super.key});

  static const String label = 'تعديل الملف الشخصي';

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      onTap: onPressed,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        key: const ValueKey<String>('account-profile-edit'),
        tooltip: label,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

/// Compact review state for one role (shop or supplier).
class ReviewStatusChip extends StatelessWidget {
  const ReviewStatusChip({
    required this.roleLabel,
    required this.status,
    super.key,
  });

  final String roleLabel;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (IconData icon, Color background, Color foreground) = switch (status) {
      'pending' => (
        Icons.hourglass_top_rounded,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      'approved' => (
        Icons.verified_rounded,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      'rejected' => (
        Icons.cancel_outlined,
        colors.errorContainer,
        colors.onErrorContainer,
      ),
      _ => (
        Icons.info_outline_rounded,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    final text = '$roleLabel: ${AccountBusinessApproval.statusLabel(status)}';

    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Always-visible review status with an icon-only refresh action.
///
/// It never changes the status itself: it only shows what the server returned
/// and calls [onRefresh], which must re-query the server.
class ReviewStatusBar extends StatelessWidget {
  const ReviewStatusBar({
    required this.approval,
    required this.isLoading,
    required this.hasError,
    required this.onRefresh,
    super.key,
  });

  static const String refreshLabel = 'تحديث حالة المراجعة';

  final AccountBusinessApproval? approval;
  final bool isLoading;
  final bool hasError;

  /// Null disables the action (for example when no user is signed in).
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final chips = <Widget>[
      if (approval?.shopStatus != null)
        ReviewStatusChip(roleLabel: 'العميل', status: approval!.shopStatus!),
      if (approval?.supplierStatus != null)
        ReviewStatusChip(
          roleLabel: 'المورد',
          status: approval!.supplierStatus!,
        ),
    ];

    final Widget content;
    if (chips.isNotEmpty) {
      content = Wrap(spacing: 8, runSpacing: 6, children: chips);
    } else if (isLoading) {
      content = Text(
        'جار جلب حالة النشاط من الخادم',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    } else if (hasError) {
      content = const SizedBox.shrink();
    } else {
      content = Text(
        'لا يوجد طلب اعتماد مسجل',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    return Container(
      key: const ValueKey<String>('account-review-status'),
      padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'حالة المراجعة',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  content,
                  if (hasError && !isLoading) ...[
                    if (chips.isNotEmpty) const SizedBox(height: 6),
                    Text(
                      'تعذر تحديث حالة المراجعة. حاول مجددًا.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Semantics(
            container: true,
            button: true,
            enabled: !isLoading && onRefresh != null,
            onTap: isLoading ? null : onRefresh,
            label: refreshLabel,
            excludeSemantics: true,
            child: isLoading
                ? const SizedBox(
                    key: ValueKey<String>('account-review-refresh-loading'),
                    width: 48,
                    height: 48,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    key: const ValueKey<String>('account-review-refresh'),
                    tooltip: refreshLabel,
                    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                    onPressed: onRefresh,
                    // Server query, not a local/remote sync: Refresh icon.
                    icon: const Icon(Icons.refresh_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}
