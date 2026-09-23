import 'package:flutter/material.dart';
import '../api.dart';
import '../widgets/common_widgets.dart';
import '../models.dart';
import '../mobile_management.dart';
import '../mobile_screens.dart';
import '../connectivity.dart';
import '../sync_service.dart';

class ComplaintsScreen extends StatefulWidget {
  final ApiClient api;
  final SyncService syncService;

  const ComplaintsScreen({super.key, required this.api, required this.syncService});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  ApiList? data;
  String search = '';
  bool loading = false;
  String? selectedStatus;
  String? selectedPriority;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final filters = <String, String>{};
      if (search.trim().isNotEmpty) filters['search'] = search.trim();
      if (selectedStatus != null) filters['status'] = selectedStatus!;
      if (selectedPriority != null) filters['priority'] = selectedPriority!;
      filters['per_page'] = '100';

      final x = await widget.api.list(
        '/complaints',
        query: filters.isNotEmpty ? filters : null,
      );
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = data?.items ?? [];
    final connectivity = ConnectivityService();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SyncStatusPanel(syncService: widget.syncService, onRefresh: load),
        ),
        // Offline message
        ValueListenableBuilder(
          valueListenable: connectivity.isOnline,
          builder: (_, isOnline, __) => OfflineMessageBar(isOnline: isOnline),
        ),
        // Search and filters
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => search = v,
                onSubmitted: (_) => load(),
                decoration: InputDecoration(
                  labelText: 'بحث',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: load,
                    icon: const Icon(Icons.refresh),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'الحالة',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('الكل'),
                        ),
                        DropdownMenuItem(
                          value: 'open',
                          child: StatusBadge(status: 'open'),
                        ),
                        DropdownMenuItem(
                          value: 'in_progress',
                          child: StatusBadge(status: 'in_progress'),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: StatusBadge(status: 'resolved'),
                        ),
                      ],
                      onChanged:
                          (v) => setState(() {
                            selectedStatus = v;
                            load();
                          }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'الأولوية',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('الكل'),
                        ),
                        DropdownMenuItem(
                          value: 'low',
                          child: PriorityBadge(priority: 'low'),
                        ),
                        DropdownMenuItem(
                          value: 'medium',
                          child: PriorityBadge(priority: 'medium'),
                        ),
                        DropdownMenuItem(
                          value: 'high',
                          child: PriorityBadge(priority: 'high'),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: PriorityBadge(priority: 'urgent'),
                        ),
                      ],
                      onChanged:
                          (v) => setState(() {
                            selectedPriority = v;
                            load();
                          }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (loading && data != null)
          const LinearProgressIndicator(minHeight: 2),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child:
                data == null
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? EmptyState(
                      title: 'لا توجد شكاوى',
                      subtitle: 'لم يتم تسجيل أي شكاوى حتى الآن',
                      icon: Icons.report_off_outlined,
                      action: FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add),
                        label: const Text('تسجيل شكوى'),
                      ),
                    )
                    : ListView.builder(
                      itemCount: items.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      itemBuilder: (_, i) {
                        final m = items[i];
                        final number = m['complaint_number'] ?? '-';
                        final isPending = m['local_pending'] == true;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  child: Icon(Icons.report_outlined),
                                ),
                                if (isPending)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              '$number — ${m['title'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    StatusBadge(status: '${m['status'] ?? ''}'),
                                    const SizedBox(width: 6),
                                    PriorityBadge(
                                      priority: '${m['priority'] ?? ''}',
                                    ),
                                    if (isPending) ...[
                                      const SizedBox(width: 6),
                                      PendingSyncBadge(count: 1),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${m['description'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () => _openComplaintDetails(m['id'], m),
                          ),
                        );
                      },
                    ),
          ),
        ),
        // Create button
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _createComplaint(),
              icon: const Icon(Icons.add),
              label: const Text('تسجيل شكوى جديدة'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openComplaintDetails(dynamic id, Map<String, dynamic> m) async {
    try {
      final fresh = await widget.api.getOne('/complaints/$id');
      if (!mounted) return;
      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => ComplaintManager(api: widget.api, data: fresh),
      );
      if (changed == true && mounted) load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _createComplaint() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ComplaintForm(api: widget.api),
    );
    if (ok == true && mounted) load();
  }
}
