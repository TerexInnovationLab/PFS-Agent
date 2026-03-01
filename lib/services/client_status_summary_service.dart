import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pfs_agent/config/api_config.dart';

class ClientStatusSummary {
  final int total;
  final int approved;
  final int pending;
  final int rejected;
  final int bounced;

  const ClientStatusSummary({
    required this.total,
    required this.approved,
    required this.pending,
    required this.rejected,
    required this.bounced,
  });

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'approved': approved,
      'pending': pending,
      'rejected': rejected,
      'bounced': bounced,
    };
  }

  factory ClientStatusSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ClientStatusSummary(
      total: parseInt(json['total']),
      approved: parseInt(json['approved']),
      pending: parseInt(json['pending']),
      rejected: parseInt(json['rejected']),
      bounced: parseInt(json['bounced']),
    );
  }
}

class ClientStatusSummaryService {
  const ClientStatusSummaryService();
  static const String _summaryCacheKey = 'client_status_summary_cache';
  static ClientStatusSummary? _memorySummary;

  String _normalizeStatus(String? raw) {
    final status = (raw ?? '').trim().toLowerCase();
    if (status == 'denied') return 'rejected';
    if (status == 'bounce') return 'bounced';
    return status;
  }

  Future<ClientStatusSummary?> getCachedSummary() async {
    if (_memorySummary != null) return _memorySummary;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_summaryCacheKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final summary = ClientStatusSummary.fromJson(decoded);
      _memorySummary = summary;
      return summary;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedSummary(ClientStatusSummary summary) async {
    _memorySummary = summary;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_summaryCacheKey, jsonEncode(summary.toJson()));
  }

  Future<ClientStatusSummary?> fetchSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/registrations'),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final registrations = decoded['registrations'];
    if (registrations is! List) {
      return null;
    }

    int approved = 0;
    int pending = 0;
    int rejected = 0;
    int bounced = 0;

    for (final item in registrations) {
      if (item is! Map) continue;

      switch (_normalizeStatus(item['status']?.toString())) {
        case 'approved':
          approved++;
          break;
        case 'pending':
          pending++;
          break;
        case 'rejected':
          rejected++;
          break;
        case 'bounced':
          bounced++;
          break;
      }
    }

    final summary = ClientStatusSummary(
      total: registrations.length,
      approved: approved,
      pending: pending,
      rejected: rejected,
      bounced: bounced,
    );

    await _saveCachedSummary(summary);
    return summary;
  }
}
