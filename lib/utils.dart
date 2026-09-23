import 'package:flutter/material.dart';

String statusLabel(String v) =>
    const {
      'open': 'مفتوحة',
      'in_progress': 'قيد المعالجة',
      'resolved': 'محلولة',
      'closed': 'مغلقة',
      'cancelled': 'ملغاة',
      'pending': 'قيد الانتظار',
      'assigned': 'مسندة',
      'completed': 'مكتملة',
    }[v] ??
    v;

String priorityLabel(String v) =>
    const {
      'low': 'منخفضة',
      'medium': 'متوسطة',
      'high': 'عالية',
      'urgent': 'طارئة',
    }[v] ??
    v;

Color statusColor(String v) => {
  'open': Colors.blue,
  'in_progress': Colors.orange,
  'resolved': Colors.green,
  'closed': Colors.grey,
  'cancelled': Colors.red,
  'pending': Colors.amber,
  'assigned': Colors.indigo,
  'completed': Colors.green,
}.withDefault(v, Colors.grey);

Color priorityColor(String v) => {
  'low': Colors.blue,
  'medium': Colors.amber,
  'high': Colors.orange,
  'urgent': Colors.red,
}.withDefault(v, Colors.grey);

IconData statusIcon(String v) => {
  'open': Icons.hourglass_top,
  'in_progress': Icons.hourglass_bottom,
  'resolved': Icons.check_circle,
  'closed': Icons.done_all,
  'cancelled': Icons.cancel,
  'pending': Icons.schedule,
  'assigned': Icons.assignment,
  'completed': Icons.task_alt,
}.withDefault(v, Icons.info);

extension on Map<String, Color> {
  Color withDefault(String key, Color defaultValue) =>
      this[key] ?? defaultValue;
}

extension on Map<String, IconData> {
  IconData withDefault(String key, IconData defaultValue) =>
      this[key] ?? defaultValue;
}
