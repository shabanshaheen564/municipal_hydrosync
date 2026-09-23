import 'package:flutter/material.dart';
import '../utils.dart';
import '../sync_service.dart';

class InfoCard extends StatelessWidget {
  final Map<String, String> rows;

  const InfoCard({super.key, required this.rows});

  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            rows.entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(c).style,
                        children: [
                          TextSpan(
                            text: '${e.key}: ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: e.value),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;

  const StatusBadge({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: statusColor(status).withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: statusColor(status), width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(statusIcon(status), size: 14, color: statusColor(status)),
        const SizedBox(width: 5),
        Text(
          label ?? statusLabel(status),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: statusColor(status),
          ),
        ),
      ],
    ),
  );
}

class PriorityBadge extends StatelessWidget {
  final String priority;
  final String? label;

  const PriorityBadge({super.key, required this.priority, this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: priorityColor(priority).withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: priorityColor(priority), width: 0.5),
    ),
    child: Text(
      label ?? priorityLabel(priority),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: priorityColor(priority),
      ),
    ),
  );
}

class MetricCard extends StatelessWidget {
  final String title;
  final num value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class OfflineIndicator extends StatelessWidget {
  final bool isOnline;

  const OfflineIndicator({super.key, this.isOnline = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color:
          isOnline
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isOnline ? Colors.green : Colors.orange,
        width: 0.5,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isOnline ? 'متصل' : 'غير متصل',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isOnline ? Colors.green : Colors.orange,
          ),
        ),
      ],
    ),
  );
}

class PendingSyncBadge extends StatelessWidget {
  final int count;

  const PendingSyncBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) =>
      count == 0
          ? const SizedBox.shrink()
          : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 14,
                  color: Colors.blue,
                ),
                const SizedBox(width: 5),
                Text(
                  '$count عملية بانتظار',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          );
}

class OfflineMessageBar extends StatelessWidget {
  final bool isOnline;
  final String? message;

  const OfflineMessageBar({super.key, required this.isOnline, this.message});

  @override
  Widget build(BuildContext context) =>
      !isOnline
          ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.orange.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, size: 18, color: Colors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message ??
                        'أنت غير متصل. ستتم المزامنة تلقائياً عند الاتصال.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          )
          : const SizedBox.shrink();
}


class SyncStatusPanel extends StatelessWidget {
  final SyncService syncService;
  final VoidCallback? onRefresh;

  const SyncStatusPanel({
    super.key,
    required this.syncService,
    this.onRefresh,
  });

  String _stateLabel(SyncState state) {
    switch (state) {
      case SyncState.syncing: return 'جاري المزامنة...';
      case SyncState.offline: return 'بانتظار الاتصال';
      case SyncState.error: return 'توجد عمليات فاشلة';
      case SyncState.idle: return 'المزامنة محدثة';
    }
  }

  IconData _stateIcon(SyncState state) {
    switch (state) {
      case SyncState.syncing: return Icons.sync;
      case SyncState.offline: return Icons.cloud_off;
      case SyncState.error: return Icons.error_outline;
      case SyncState.idle: return Icons.cloud_done_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: syncService.revision,
    builder: (_, __, ___) => ValueListenableBuilder<SyncState>(
      valueListenable: syncService.state,
      builder: (_, state, __) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_stateIcon(state)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stateLabel(state),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (syncService.pending.value > 0)
                    PendingSyncBadge(count: syncService.pending.value),
                ],
              ),
              if (syncService.failed.value > 0) ...[
                const SizedBox(height: 8),
                Text('العمليات الفاشلة: ' + syncService.failed.value.toString(),
                    style: const TextStyle(fontSize: 12)),
                if (syncService.lastError.value != null) ...[
                  const SizedBox(height: 4),
                  Text(syncService.lastError.value!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state == SyncState.syncing ? null : () async {
                        await syncService.syncNow();
                        onRefresh?.call();
                      },
                      icon: const Icon(Icons.sync),
                      label: const Text('مزامنة الآن'),
                    ),
                  ),
                  if (syncService.failed.value > 0) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state == SyncState.syncing ? null : () async {
                          await syncService.retryFailed();
                          onRefresh?.call();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ),
                  ],
                ],
              ),
              if (syncService.lastSync.value != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'آخر مزامنة: ' + syncService.lastSync.value.toString(),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
