import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../api.dart';
import '../utils.dart';

class MapScreen extends StatefulWidget {
  final ApiClient api;

  const MapScreen({super.key, required this.api});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Map<String, dynamic>? data;
  final mapController = MapController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final x = await widget.api.operationalMap();
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
    mapController.dispose();
    super.dispose();
  }

  void _showFeatureDetails(Map<String, dynamic> m, bool isComplaint) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplaint ? 'شكوى' : 'مهمة ميدانية',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${m['number'] ?? '-'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m['title'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'الحالة',
                      statusLabel('${m['status'] ?? ''}'),
                    ),
                    _buildDetailRow(
                      'الأولوية',
                      priorityLabel('${m['priority'] ?? ''}'),
                    ),
                    if (m['assigned_to'] != null)
                      _buildDetailRow(
                        'المسؤول',
                        m['assigned_to'] is Map
                            ? m['assigned_to']['name'] ?? '-'
                            : '${m['assigned_to']}',
                      ),
                    if (m['description'] != null &&
                        (m['description'] as String).isNotEmpty)
                      _buildDetailRow('الوصف', '${m['description']}'),
                    if (m['address'] != null)
                      _buildDetailRow('العنوان', '${m['address']}'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إغلاق'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    final complaints = (data?['complaints'] as List?) ?? const [];
    final workOrders = (data?['work_orders'] as List?) ?? const [];

    // Add complaint markers
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
              onTap: () => _showFeatureDetails(m, true),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.report_problem,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Add work order markers
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
              onTap: () => _showFeatureDetails(m, false),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.engineering,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      }
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
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Stats card
        Positioned(
          top: 12,
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
                ],
              ),
            ),
          ),
        ),
        // Refresh button
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
