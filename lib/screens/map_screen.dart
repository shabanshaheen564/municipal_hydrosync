import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../api.dart';
import '../models.dart';
import '../sync_service.dart';
import '../mobile_management.dart';
import '../maintenance_screens.dart';

class MapScreen extends StatefulWidget {
  final ApiClient api;
  final SyncService syncService;
  final SessionUser user;

  const MapScreen({super.key, required this.api, required this.syncService, required this.user});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Map<String, dynamic>? data;
  final mapController = MapController();
  final searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool searching = false;
  LatLng? searchPoint;

  Future<void> _searchPlaces(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      searching = true;
      searchResults = [];
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '10',
        'addressdetails': '1',
        'accept-language': 'ar',
        'countrycodes': 'ps',
        'viewbox': '34.30,31.50,34.45,31.35',
        'bounded': '1',
      });
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'DeirAlBalahMunicipalityWaterApp/1.0',
      });
      if (response.statusCode != 200) throw Exception();
      final decoded = jsonDecode(response.body);
      if (decoded is! List) throw Exception();
      final results = decoded.whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)).toList();
      if (!mounted) return;
      setState(() {
        searching = false;
        searchResults = results;
      });
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على نتائج ضمن المنطقة.')),
        );
      } else {
        _showSearchResults();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر البحث حالياً، حاول مرة أخرى.')),
      );
    }
  }

  String _resultTitle(Map<String, dynamic> result) {
    final name = '${result['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    final displayName = '${result['display_name'] ?? ''}'.trim();
    return displayName.isEmpty ? 'نتيجة بدون اسم' : displayName.split(',').first;
  }

  void _showSearchResults() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.62,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text('نتائج البحث',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final result = searchResults[index];
                    final lat = double.tryParse('${result['lat']}');
                    final lon = double.tryParse('${result['lon']}');
                    return ListTile(
                      leading: const Icon(Icons.location_on),
                      title: Text(_resultTitle(result)),
                      subtitle: Text('${result['display_name'] ?? ''}',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: lat == null || lon == null ? null : () {
                        Navigator.pop(context);
                        final point = LatLng(lat, lon);
                        setState(() => searchPoint = point);
                        mapController.move(point, 16);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.syncService.revision.addListener(_syncRevisionChanged);
    load();
  }

  void _syncRevisionChanged() {
    if (mounted) load(forceRefresh: true);
  }

  Future<void> load({bool forceRefresh = false}) async {
    try {
      final x = await widget.api.operationalMap(forceRefresh: forceRefresh);
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  void dispose() {
    widget.syncService.revision.removeListener(_syncRevisionChanged);
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    final complaints = (data?['complaints'] as List?) ?? const [];
    final workOrders = (data?['work_orders'] as List?) ?? const [];
    final maintenance = (data?['maintenance'] as List?) ?? const [];

    for (final raw in complaints) {
      final m = Map<String, dynamic>.from(raw);
      final lat = (m['latitude'] as num?)?.toDouble();
      final lng = (m['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () async {
                final navigator = Navigator.of(context);
                try {
                  final fresh = await widget.api.getOne('/complaints/${m['id']}');
                  if (!mounted) return;
                  await showModalBottomSheet<bool>(
                    context: navigator.context,
                    isScrollControlled: true,
                    builder: (_) => ComplaintManager(api: widget.api, data: fresh),
                  );
                  await load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.report_problem, color: Colors.white, size: 28),
              ),
            ),
          ),
        );
      }
    }

    for (final raw in workOrders) {
      final m = Map<String, dynamic>.from(raw);
      final lat = (m['latitude'] as num?)?.toDouble();
      final lng = (m['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () async {
                final navigator = Navigator.of(context);
                try {
                  final fresh = await widget.api.getOne('/work-orders/${m['id']}');
                  if (!mounted) return;
                  await showModalBottomSheet<bool>(
                    context: navigator.context,
                    isScrollControlled: true,
                    builder: (_) => WorkOrderManager(api: widget.api, data: fresh),
                  );
                  await load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.engineering, color: Colors.white, size: 28),
              ),
            ),
          ),
        );
      }
    }

    for (final raw in maintenance) {
      final m = Map<String, dynamic>.from(raw);
      final lat = (m['latitude'] as num?)?.toDouble();
      final lng = (m['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 48,
            height: 48,
            child: GestureDetector(
              onTap: () async {
                final navigator = Navigator.of(context);
                try {
                  final fresh = await widget.api.getOne(
                    '/maintenance/requests/${m['id']}',
                    forceRefresh: true,
                  );
                  if (!mounted) return;
                  await showModalBottomSheet<bool>(
                    context: navigator.context,
                    isScrollControlled: true,
                    builder: (_) => MaintenanceDetailsPage(
                      api: widget.api,
                      user: widget.user,
                      id: (m['id'] as num).toInt(),
                      initialData: fresh,
                    ),
                  );
                  await load(forceRefresh: true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.build, color: Colors.white, size: 28),
              ),
            ),
          ),
        );
      }
    }

    if (searchPoint != null) {
      markers.add(Marker(
        point: searchPoint!,
        width: 48,
        height: 48,
        child: const Icon(Icons.location_on, color: Colors.blue, size: 44),
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: const MapOptions(
            initialCenter: LatLng(31.42, 34.36),
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ps.modb.water',
              maxNativeZoom: 19,
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Card(
            elevation: 4,
            child: TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _searchPlaces,
              decoration: InputDecoration(
                hintText: 'ابحث عن شارع أو معلم أو منطقة...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'بحث',
                        onPressed: () => _searchPlaces(searchController.text),
                        icon: const Icon(Icons.search),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
        ),
        Positioned(
          top: 78,
          right: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${complaints.length} شكاوى'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${workOrders.length} مهام'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${maintenance.length} صيانة'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
