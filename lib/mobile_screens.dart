import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'api.dart';
import 'models.dart';

String statusLabel(String v) =>
    const {
      'open': 'ظ…ظپطھظˆط­ط©',
      'in_progress': 'ظ‚ظٹط¯ ط§ظ„ظ…ط¹ط§ظ„ط¬ط©',
      'resolved': 'ظ…ط­ظ„ظˆظ„ط©',
      'closed': 'ظ…ط؛ظ„ظ‚ط©',
      'cancelled': 'ظ…ظ„ط؛ط§ط©',
      'pending': 'ظ‚ظٹط¯ ط§ظ„ط§ظ†طھط¸ط§ط±',
      'assigned': 'ظ…ط³ظ†ط¯ط©',
      'completed': 'ظ…ظƒطھظ…ظ„ط©',
    }[v] ??
    v;
String priorityLabel(String v) =>
    const {
      'low': 'ظ…ظ†ط®ظپط¶ط©',
      'medium': 'ظ…طھظˆط³ط·ط©',
      'high': 'ط¹ط§ظ„ظٹط©',
      'urgent': 'ط·ط§ط±ط¦ط©',
    }[v] ??
    v;

class ListPage extends StatefulWidget {
  final ApiClient api;
  final String endpoint, title;
  final IconData icon;
  const ListPage({
    super.key,
    required this.api,
    required this.endpoint,
    required this.title,
    required this.icon,
  });
  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  ApiList? data;
  String search = '';
  bool loading = false;
  bool get complaint => widget.endpoint == '/complaints';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final q =
          search.trim().isEmpty
              ? null
              : {'search': search.trim(), 'per_page': '100'};
      final x = await widget.api.list(widget.endpoint, query: q);
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

  Future<void> create() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) =>
              complaint
                  ? ComplaintForm(api: widget.api)
                  : WorkOrderForm(api: widget.api),
    );
    if (ok == true && mounted) load();
  }

  @override
  Widget build(BuildContext c) {
    final items = data?.items ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            onChanged: (v) => search = v,
            onSubmitted: (_) => load(),
            decoration: InputDecoration(
              labelText: 'ط¨ط­ط«',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (loading && data != null)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child:
                data == null
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text('ظ„ط§ طھظˆط¬ط¯ ط¨ظٹط§ظ†ط§طھ')),
                      ],
                    )
                    : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final m = items[i];
                        final n =
                            complaint
                                ? m['complaint_number']
                                : m['work_order_number'];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(widget.icon)),
                            title: Text(
                              '${n ?? '-'} â€” ${m['title'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${statusLabel('${m['status'] ?? ''}')} â€¢ ${priorityLabel('${m['priority'] ?? ''}')}\n${m['description'] ?? ''}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_left),
                            onTap: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          complaint
                                              ? ComplaintDetailsPage(
                                                api: widget.api,
                                                id: (m['id'] as num).toInt(),
                                              )
                                              : WorkOrderDetailsPage(
                                                api: widget.api,
                                                id: (m['id'] as num).toInt(),
                                              ),
                                ),
                              );
                              if (changed == true && mounted) load();
                            },
                          ),
                        );
                      },
                    ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.add),
              label: Text(
                complaint
                    ? 'طھط³ط¬ظٹظ„ ط´ظƒظˆظ‰ ط¬ط¯ظٹط¯ط©'
                    : 'ط¥ظ†ط´ط§ط، ظ…ظ‡ظ…ط© ظ…ظٹط¯ط§ظ†ظٹط©',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ComplaintForm extends StatefulWidget {
  final ApiClient api;
  const ComplaintForm({super.key, required this.api});
  @override
  State<ComplaintForm> createState() => _ComplaintFormState();
}

class _ComplaintFormState extends State<ComplaintForm> {
  final title = TextEditingController(),
      description = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      lat = TextEditingController(),
      lng = TextEditingController();
  String priority = 'medium';
  bool busy = false;
  @override
  void dispose() {
    for (final x in [title, description, name, phone, address, lat, lng]) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> gps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('ط®ط¯ظ…ط© ط§ظ„ظ…ظˆظ‚ط¹ ط؛ظٹط± ظ…ظپط¹ظ„ط©.');
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        throw Exception('ظ„ظ… ظٹطھظ… ط§ظ„ط³ظ…ط§ط­ ط¨ط§ظ„ظ…ظˆظ‚ط¹.');
      }
      final x = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          lat.text = x.latitude.toStringAsFixed(7);
          lng.text = x.longitude.toStringAsFixed(7);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> pick() async {
    final p = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (p != null && mounted) {
      setState(() {
        lat.text = p.latitude.toStringAsFixed(7);
        lng.text = p.longitude.toStringAsFixed(7);
      });
    }
  }

  Future<void> gps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw Exception('خدمة الموقع غير مفعلة.');
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw Exception('لم يتم السماح بالموقع.');
      final x = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) setState(() { lat.text = x.latitude.toStringAsFixed(7); lng.text = x.longitude.toStringAsFixed(7); });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> pick() async {
    final p = await Navigator.push<LatLng>(context, MaterialPageRoute(builder: (_) => const LocationPickerPage()));
    if (p != null && mounted) setState(() { lat.text = p.latitude.toStringAsFixed(7); lng.text = p.longitude.toStringAsFixed(7); });
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ط§ظ„ط¹ظ†ظˆط§ظ† ظˆط§ظ„ظˆطµظپ ظ…ط·ظ„ظˆط¨ط§ظ†.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final b = <String, dynamic>{
        'title': title.text.trim(),
        'description': description.text.trim(),
        'priority': priority,
        if (name.text.trim().isNotEmpty) 'contact_name': name.text.trim(),
        if (phone.text.trim().isNotEmpty) 'contact_phone': phone.text.trim(),
        if (address.text.trim().isNotEmpty) 'address': address.text.trim(),
        if (double.tryParse(lat.text) != null)
          'latitude': double.parse(lat.text),
        if (double.tryParse(lng.text) != null)
          'longitude': double.parse(lng.text),
      };
      final r = await widget.api.create('/complaints', b);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r['queued'] == true
                ? 'طھظ… ط­ظپط¸ظ‡ط§ ظ„ظ„ظ…ط²ط§ظ…ظ†ط© ظ„ط§ط­ظ‚ظ‹ط§'
                : 'طھظ… طھط³ط¬ظٹظ„ ط§ظ„ط´ظƒظˆظ‰',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: const Text('طھط³ط¬ظٹظ„ ط´ظƒظˆظ‰'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'ط§ظ„ط¹ظ†ظˆط§ظ† *'),
            ),
            TextField(
              controller: description,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'ظˆطµظپ ط§ظ„ظ…ط´ظƒظ„ط© *',
              ),
            ),
            DropdownButtonFormField<String>(
              value: priority,
              decoration: const InputDecoration(labelText: 'ط§ظ„ط£ظˆظ„ظˆظٹط©'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('ظ…ظ†ط®ظپط¶ط©')),
                DropdownMenuItem(value: 'medium', child: Text('ظ…طھظˆط³ط·ط©')),
                DropdownMenuItem(value: 'high', child: Text('ط¹ط§ظ„ظٹط©')),
                DropdownMenuItem(value: 'urgent', child: Text('ط·ط§ط±ط¦ط©')),
              ],
              onChanged: (v) => setState(() => priority = v ?? 'medium'),
            ),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'ط§ط³ظ… ط§ظ„ظ…ط¨ظ„ظ‘ط؛',
              ),
            ),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'ظ‡ط§طھظپ ط§ظ„ظ…ط¨ظ„ظ‘ط؛',
              ),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(
                labelText: 'ط§ظ„ط¹ظ†ظˆط§ظ† / ط§ظ„ظ…ظˆظ‚ط¹ ط§ظ„ظ†طµظٹ',
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: lat,
                    decoration: const InputDecoration(
                      labelText: 'ط®ط· ط§ظ„ط¹ط±ط¶',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lng,
                    decoration: const InputDecoration(
                      labelText: 'ط®ط· ط§ظ„ط·ظˆظ„',
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : pick,
                  icon: const Icon(Icons.map),
                  label: const Text('طھط­ط¯ظٹط¯ ط¹ظ„ظ‰ ط§ظ„ط®ط±ظٹط·ط©'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : gps,
                  icon: const Icon(Icons.my_location),
                  label: const Text('ظ…ظˆظ‚ط¹ ط§ظ„ظ‡ط§طھظپ'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('ط¥ظ„ط؛ط§ط،'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: busy ? const CircularProgressIndicator() : const Text('ط­ظپط¸'),
      ),
    ],
  );
}

class WorkOrderForm extends StatefulWidget {
  final ApiClient api;
  const WorkOrderForm({super.key, required this.api});
  @override
  State<WorkOrderForm> createState() => _WorkOrderFormState();
}

class _WorkOrderFormState extends State<WorkOrderForm> {
  final title = TextEditingController(),
      description = TextEditingController(),
      notes = TextEditingController(),
      lat = TextEditingController(),
      lng = TextEditingController();
  String status = 'pending', priority = 'medium';
  int? complaintId, assignedTo;
  ApiList? complaints, users;
  SessionUser? me;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    me = await widget.api.session();
    try {
      complaints = await widget.api.list(
        '/complaints',
        query: {'per_page': '100'},
      );
    } catch (_) {}
    if (me?.permissions.contains('tasks.assign') == true &&
        me?.permissions.contains('users.view') == true) {
      try {
        users = await widget.api.users();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    notes.dispose();
    lat.dispose();
    lng.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || description.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ط§ظ„ط¹ظ†ظˆط§ظ† ظˆط§ظ„ظˆطµظپ ظ…ط·ظ„ظˆط¨ط§ظ†.'),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final b = <String, dynamic>{
        'title': title.text.trim(),
        'description': description.text.trim(),
        'status': status,
        'priority': priority,
        if (complaintId != null) 'complaint_id': complaintId,
        if (assignedTo != null) 'assigned_to': assignedTo,
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
        if (double.tryParse(lat.text) != null) 'latitude': double.parse(lat.text),
        if (double.tryParse(lng.text) != null) 'longitude': double.parse(lng.text),
      };
      final r = await widget.api.create('/work-orders', b);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            r['queued'] == true
                ? 'طھظ… ط­ظپط¸ ط§ظ„ظ…ظ‡ظ…ط© ظ„ظ„ظ…ط²ط§ظ…ظ†ط© ظ„ط§ط­ظ‚ظ‹ط§'
                : 'طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ظ…ظ‡ظ…ط©',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final cs = complaints?.items ?? [];
    final us = users?.items ?? [];
    return AlertDialog(
      title: const Text('ط¥ظ†ط´ط§ط، ظ…ظ‡ظ…ط© ظ…ظٹط¯ط§ظ†ظٹط©'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'ط§ظ„ط¹ظ†ظˆط§ظ† *',
                ),
              ),
              TextField(
                controller: description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'ط§ظ„ظˆطµظپ *'),
              ),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'ط§ظ„ط­ط§ظ„ط©'),
                items: const [
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('ظ‚ظٹط¯ ط§ظ„ط§ظ†طھط¸ط§ط±'),
                  ),
                  DropdownMenuItem(
                    value: 'assigned',
                    child: Text('ظ…ط³ظ†ط¯ط©'),
                  ),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('ظ‚ظٹط¯ ط§ظ„طھظ†ظپظٹط°'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('ظ…ظƒطھظ…ظ„ط©'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('ظ…ظ„ط؛ط§ط©'),
                  ),
                ],
                onChanged: (v) => setState(() => status = v ?? 'pending'),
              ),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: 'ط§ظ„ط£ظˆظ„ظˆظٹط©',
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('ظ…ظ†ط®ظپط¶ط©')),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text('ظ…طھظˆط³ط·ط©'),
                  ),
                  DropdownMenuItem(value: 'high', child: Text('ط¹ط§ظ„ظٹط©')),
                  DropdownMenuItem(value: 'urgent', child: Text('ط·ط§ط±ط¦ط©')),
                ],
                onChanged: (v) => setState(() => priority = v ?? 'medium'),
              ),
              DropdownButtonFormField<int?>(
                value: complaintId,
                decoration: const InputDecoration(
                  labelText: 'ط±ط¨ط· ط¨ط´ظƒظˆظ‰',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ط¨ط¯ظˆظ† ط´ظƒظˆظ‰'),
                  ),
                  ...cs.map(
                    (x) => DropdownMenuItem<int?>(
                      value: (x['id'] as num).toInt(),
                      child: Text('${x['complaint_number']} â€” ${x['title']}'),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => complaintId = v),
              ),
              if (us.isNotEmpty)
                DropdownButtonFormField<int?>(
                  value: assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'ط§ظ„ظ…ظˆط¸ظپ ط§ظ„ظ…ط³ظ†ط¯ ط¥ظ„ظٹظ‡',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ط¨ط¯ظˆظ† ط¥ط³ظ†ط§ط¯'),
                    ),
                    ...us
                        .where((x) => x['is_active'] == true)
                        .map(
                          (x) => DropdownMenuItem<int?>(
                            value: (x['id'] as num).toInt(),
                            child: Text('${x['name']}'),
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() => assignedTo = v),
                )
              else if (me?.permissions.contains('tasks.assign') == true)
                TextButton.icon(
                  onPressed: () => setState(() => assignedTo = me?.id),
                  icon: const Icon(Icons.person),
                  label: Text(
                    'ط¥ط³ظ†ط§ط¯ ظ„ظ„ظ…ط³طھط®ط¯ظ… ط§ظ„ط­ط§ظ„ظٹ: ${me?.name ?? ''}',
                  ),
                ),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'ظ…ظ„ط§ط­ط¸ط§طھ'),
              ),
              Row(children: [
                Expanded(child: TextField(controller: lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'خط العرض'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: 'خط الطول'))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: busy ? null : pick, icon: const Icon(Icons.map), label: const Text('تحديد على الخريطة')),
                OutlinedButton.icon(onPressed: busy ? null : gps, icon: const Icon(Icons.my_location), label: const Text('موقع الهاتف')),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('ط¥ظ„ط؛ط§ط،'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child:
              busy ? const CircularProgressIndicator() : const Text('ط­ظپط¸'),
        ),
      ],
    );
  }
}

class ComplaintDetailsPage extends StatefulWidget {
  final ApiClient api;
  final int id;
  const ComplaintDetailsPage({super.key, required this.api, required this.id});
  @override
  State<ComplaintDetailsPage> createState() => _ComplaintDetailsPageState();
}

class _ComplaintDetailsPageState extends State<ComplaintDetailsPage> {
  Map<String, dynamic>? d;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await widget.api.getOne('/complaints/${widget.id}');
      if (mounted) setState(() => d = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> convert() async {
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ConvertDialog(api: widget.api, data: d!),
    );
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) {
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final x = d!;
    final w = (x['work_orders'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('${x['complaint_number']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            rows: {
              'ط§ظ„ط¹ظ†ظˆط§ظ†': '${x['title'] ?? ''}',
              'ط§ظ„ط­ط§ظ„ط©': statusLabel('${x['status'] ?? ''}'),
              'ط§ظ„ط£ظˆظ„ظˆظٹط©': priorityLabel('${x['priority'] ?? ''}'),
              'ط§ظ„ظˆطµظپ': '${x['description'] ?? ''}',
              'ط§ظ„ظ…ط¨ظ„ظ‘ط؛': '${x['contact_name'] ?? '-'}',
              'ط§ظ„ظ‡ط§طھظپ': '${x['contact_phone'] ?? '-'}',
              'ط¹ظ†ظˆط§ظ† ط§ظ„ظ…ظˆظ‚ط¹': '${x['address'] ?? '-'}',
              'ط§ظ„ط¥ط­ط¯ط§ط«ظٹط§طھ':
                  '${x['latitude'] ?? '-'}, ${x['longitude'] ?? '-'}',
            },
          ),
          if (w.isNotEmpty)
            Card(
              child: ExpansionTile(
                title: Text('ط§ظ„ظ…ظ‡ط§ظ… ط§ظ„ظ…ط±طھط¨ط·ط© (${w.length})'),
                children: [
                  ...w.map(
                    (a) => ListTile(
                      title: Text(
                        '${a['work_order_number']} â€” ${a['title']}',
                      ),
                      subtitle: Text(statusLabel('${a['status']}')),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          if (x['status'] != 'closed' && x['status'] != 'cancelled')
            FilledButton.icon(
              onPressed: convert,
              icon: const Icon(Icons.engineering),
              label: const Text('طھط­ظˆظٹظ„ ط§ظ„ط´ظƒظˆظ‰ ط¥ظ„ظ‰ ظ…ظ‡ظ…ط©'),
            ),
        ],
      ),
    );
  }
}

class WorkOrderDetailsPage extends StatefulWidget {
  final ApiClient api;
  final int id;
  const WorkOrderDetailsPage({super.key, required this.api, required this.id});
  @override
  State<WorkOrderDetailsPage> createState() => _WorkOrderDetailsPageState();
}

class _WorkOrderDetailsPageState extends State<WorkOrderDetailsPage> {
  Map<String, dynamic>? d;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await widget.api.getOne('/work-orders/${widget.id}');
      if (mounted) setState(() => d = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final x = d!;
    final q = (x['complaints'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text('${x['work_order_number']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            rows: {
              'ط§ظ„ط¹ظ†ظˆط§ظ†': '${x['title'] ?? ''}',
              'ط§ظ„ط­ط§ظ„ط©': statusLabel('${x['status'] ?? ''}'),
              'ط§ظ„ط£ظˆظ„ظˆظٹط©': priorityLabel('${x['priority'] ?? ''}'),
              'ط§ظ„ظˆطµظپ': '${x['description'] ?? ''}',
              'ط§ظ„ظ…ط³ظ†ط¯ ط¥ظ„ظٹظ‡':
                  '${(x['assigned_to'] as Map?)?['name'] ?? '-'}',
              'ظ…ظ„ط§ط­ط¸ط§طھ': '${x['notes'] ?? '-'}',
              'ط¨ط¯ط£طھ': '${x['started_at'] ?? '-'}',
              'ط§ظƒطھظ…ظ„طھ': '${x['completed_at'] ?? '-'}',
            },
          ),
          if (q.isNotEmpty)
            Card(
              child: ExpansionTile(
                title: Text('ط§ظ„ط´ظƒط§ظˆظ‰ ط§ظ„ظ…ط±طھط¨ط·ط© (${q.length})'),
                children: [
                  ...q.map(
                    (a) => ListTile(
                      title: Text('${a['complaint_number']} â€” ${a['title']}'),
                      subtitle: Text(statusLabel('${a['status']}')),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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

class ConvertDialog extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic> data;
  const ConvertDialog({super.key, required this.api, required this.data});
  @override
  State<ConvertDialog> createState() => _ConvertDialogState();
}

class _ConvertDialogState extends State<ConvertDialog> {
  late final title = TextEditingController(
    text: '${widget.data['title'] ?? ''}',
  );
  late final description = TextEditingController(
    text: '${widget.data['description'] ?? ''}',
  );
  final notes = TextEditingController();
  String priority = 'medium';
  int? assignedTo;
  ApiList? users;
  SessionUser? me;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    priority = '${widget.data['priority'] ?? 'medium'}';
    load();
  }

  Future<void> load() async {
    me = await widget.api.session();
    final raw = (widget.data['assigned_to'] as Map?)?['id'];
    assignedTo = raw is num ? raw.toInt() : null;
    if (assignedTo == null &&
        me?.permissions.contains('tasks.assign') == true) {
      assignedTo = me!.id;
    }
    if (me?.permissions.contains('users.view') == true &&
        me?.permissions.contains('tasks.assign') == true) {
      try {
        users = await widget.api.users();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (assignedTo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ظٹط¬ط¨ طھط­ط¯ظٹط¯ ط§ظ„ظ…ظˆط¸ظپ ط§ظ„ظ…ط³ظ†ط¯ ط¥ظ„ظٹظ‡.',
          ),
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.api.convertComplaint(
        (widget.data['id'] as num).toInt(),
        title: title.text.trim(),
        description: description.text.trim(),
        priority: priority,
        assignedTo: assignedTo!,
        notes: notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext c) {
    final us = users?.items ?? [];
    return AlertDialog(
      title: const Text('طھط­ظˆظٹظ„ ط§ظ„ط´ظƒظˆظ‰ ط¥ظ„ظ‰ ظ…ظ‡ظ…ط©'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'ط¹ظ†ظˆط§ظ† ط§ظ„ظ…ظ‡ظ…ط©',
                ),
              ),
              TextField(
                controller: description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'ظˆطµظپ ط§ظ„ظ…ظ‡ظ…ط©',
                ),
              ),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(
                  labelText: 'ط§ظ„ط£ظˆظ„ظˆظٹط©',
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('ظ…ظ†ط®ظپط¶ط©')),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text('ظ…طھظˆط³ط·ط©'),
                  ),
                  DropdownMenuItem(value: 'high', child: Text('ط¹ط§ظ„ظٹط©')),
                  DropdownMenuItem(value: 'urgent', child: Text('ط·ط§ط±ط¦ط©')),
                ],
                onChanged: (v) => setState(() => priority = v ?? priority),
              ),
              if (us.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'ط§ظ„ظ…ظˆط¸ظپ *',
                  ),
                  items:
                      us
                          .where((x) => x['is_active'] == true)
                          .map(
                            (x) => DropdownMenuItem(
                              value: (x['id'] as num).toInt(),
                              child: Text('${x['name']}'),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => assignedTo = v),
                )
              else
                Text('ط§ظ„ظ…ط³ظ†ط¯ ط¥ظ„ظٹظ‡: ${me?.name ?? '-'}'),
              TextField(
                controller: notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'ظ…ظ„ط§ط­ط¸ط§طھ'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('ط¥ظ„ط؛ط§ط،'),
        ),
        FilledButton(
          onPressed: busy ? null : save,
          child:
              busy
                  ? const CircularProgressIndicator()
                  : const Text('طھط­ظˆظٹظ„ ظˆط¥ظ†ط´ط§ط، ط§ظ„ظ…ظ‡ظ…ط©'),
        ),
      ],
    );
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});
  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  LatLng? selected;
  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('طھط­ط¯ظٹط¯ ظ…ظˆظ‚ط¹ ط§ظ„ط´ظƒظˆظ‰')),
    body: FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(31.42, 34.36),
        initialZoom: 13,
        onTap: (p, x) => setState(() => selected = x),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
        ),
        if (selected != null)
          MarkerLayer(
            markers: [
              Marker(
                point: selected!,
                width: 55,
                height: 55,
                child: const Icon(Icons.location_on, size: 48),
              ),
            ],
          ),
      ],
    ),
    floatingActionButton:
        selected == null
            ? null
            : FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, selected),
              icon: const Icon(Icons.check),
              label: const Text('ط§ط¹طھظ…ط§ط¯ ط§ظ„ظ…ظˆظ‚ط¹'),
            ),
  );
}

class MapPage extends StatefulWidget {
  final ApiClient api;
  const MapPage({super.key, required this.api});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  Map<String, dynamic>? d;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await widget.api.operationalMap();
      if (mounted) setState(() => d = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void feature(Map<String, dynamic> m, bool complaint) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    complaint ? 'ط´ظƒظˆظ‰' : 'ظ…ظ‡ظ…ط© ظ…ظٹط¯ط§ظ†ظٹط©',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    '${m['number'] ?? '-'}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${m['title'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${m['description'] ?? ''}'),
                  Text('ط§ظ„ط­ط§ظ„ط©: ${statusLabel('${m['status'] ?? ''}')}'),
                  Text(
                    'ط§ظ„ط£ظˆظ„ظˆظٹط©: ${priorityLabel('${m['priority'] ?? ''}')}',
                  ),
                  Text('ط§ظ„ظ…ط³ظ†ط¯ ط¥ظ„ظٹظ‡: ${m['assigned_to'] ?? '-'}'),
                  if (m['address'] != null)
                    Text('ط§ظ„ط¹ظ†ظˆط§ظ†: ${m['address']}'),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('ط¥ط؛ظ„ط§ظ‚'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final markers = <Marker>[];
    final complaints = (d?['complaints'] as List?) ?? const [];
    final orders = (d?['work_orders'] as List?) ?? const [];
    for (final raw in complaints) {
      final m = Map<String, dynamic>.from(raw);
      final a = (m['latitude'] as num?)?.toDouble(),
          b = (m['longitude'] as num?)?.toDouble();
      if (a != null && b != null) {
        markers.add(
          Marker(
            point: LatLng(a, b),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => feature(m, true),
              child: const Icon(
                Icons.report_problem,
                color: Colors.red,
                size: 36,
              ),
            ),
          ),
        );
      }
    }
    for (final raw in orders) {
      final m = Map<String, dynamic>.from(raw);
      final a = (m['latitude'] as num?)?.toDouble(),
          b = (m['longitude'] as num?)?.toDouble();
      if (a != null && b != null) {
        markers.add(
          Marker(
            point: LatLng(a, b),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () => feature(m, false),
              child: const Icon(
                Icons.engineering,
                color: Colors.orange,
                size: 36,
              ),
            ),
          ),
        );
      }
    }
    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(31.42, 34.36),
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'ط§ظ„ط´ظƒط§ظˆظ‰: ${complaints.length} | ط§ظ„ظ…ظ‡ط§ظ…: ${orders.length}',
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 18,
          right: 18,
          child: FloatingActionButton(
            onPressed: load,
            child: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}

class ProfilePage extends StatelessWidget {
  final SessionUser user;
  final ApiClient api;
  final VoidCallback onLogout;
  const ProfilePage({
    super.key,
    required this.user,
    required this.api,
    required this.onLogout,
  });
  @override
  Widget build(BuildContext c) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user.name),
          subtitle: Text(user.email),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('ط§ظ„ط£ط¯ظˆط§ط±'),
          subtitle: Text(user.roles.join('طŒ ')),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('ط§ظ„طµظ„ط§ط­ظٹط§طھ'),
          subtitle: Text(user.permissions.join('طŒ ')),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.tonalIcon(
        onPressed: () async {
          await api.logout();
          onLogout();
        },
        icon: const Icon(Icons.logout),
        label: const Text('طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬'),
      ),
    ],
  );
}
