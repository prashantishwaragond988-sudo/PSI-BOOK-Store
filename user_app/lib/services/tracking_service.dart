import "dart:convert";

import "package:http/http.dart" as http;

class TrackingService {
  TrackingService({String? baseUrl}) : _baseUrl = baseUrl ?? defaultBaseUrl;

  static const String defaultBaseUrl = "http://10.0.2.2:5000";

  final String _baseUrl;

  Future<Map<String, dynamic>> trackOrder(String orderId) async {
    final res = await http.get(
      Uri.parse("$_baseUrl/track-order?order_id=${Uri.encodeQueryComponent(orderId)}"),
      headers: {"Accept": "application/json"},
    );

    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      final err = body is Map<String, dynamic>
          ? (body["error"] ?? "Tracking failed")
          : "Tracking failed";
      throw Exception(err.toString());
    }

    if (body is! Map<String, dynamic>) {
      throw Exception("Invalid tracking response");
    }

    return body;
  }
}
