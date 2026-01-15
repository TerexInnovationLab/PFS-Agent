import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class TargetsService {
  Timer? _timer;

  final Function(Map<String, dynamic>) onDataReceived;
  final Function(String) onError;

  TargetsService({required this.onDataReceived, required this.onError});

  /// Starts the polling process every 10 seconds
  void startPolling() {
    // 1. Load cached data first so the UI isn't empty
    loadCachedData();

    // 2. Fetch fresh data immediately
    _fetchData();

    // 3. Set up the interval
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchData();
    });
  }

  void stopPolling() {
    _timer?.cancel();
  }

  /// NEW: Loads data from SharedPreferences if it exists
  Future<void> loadCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedJson = prefs.getString('target_data');
    if (cachedJson != null) {
      onDataReceived(jsonDecode(cachedJson));
    }
  }

  Future<void> _fetchData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        onError("Authentication token missing.");
        return;
      }

      const String url = ApiConfig.baseUrl+"/targets";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // --- PERSISTENCE LOGIC ---
        // Save the raw JSON string to SharedPreferences
        await prefs.setString('target_data', response.body);
        // -------------------------

        onDataReceived(data);

        print("server working");
      } else {
        onError("Server error: ${response.statusCode}");
      }
    } catch (e) {
      onError("Network error: $e");
    }
  }
}