import "dart:async";

import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";

import "../services/tracking_service.dart";

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final TrackingService _trackingService = TrackingService();
  late final TextEditingController _orderCtrl;
  bool _loading = false;
  String _error = "";
  Map<String, dynamic>? _tracking;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _orderCtrl = TextEditingController(text: widget.orderId);
    if (widget.orderId.trim().isNotEmpty) {
      _fetch();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final orderId = _orderCtrl.text.trim();
    if (orderId.isEmpty) {
      setState(() => _error = "Order ID required");
      return;
    }

    setState(() {
      _loading = true;
      _error = "";
    });

    try {
      final data = await _trackingService.trackOrder(orderId);
      if (!mounted) {
        return;
      }
      setState(() => _tracking = data);

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_orderCtrl.text.trim().isNotEmpty) {
          _fetch();
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    final flow = tracking?["flow"] is List
        ? List<Map<String, dynamic>>.from(
            (tracking!["flow"] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e)),
          )
        : <Map<String, dynamic>>[];

    final location = tracking?["latest_location"] is Map
        ? Map<String, dynamic>.from(tracking!["latest_location"] as Map)
        : null;
    final lat = double.tryParse("${location?["latitude"] ?? ""}");
    final lng = double.tryParse("${location?["longitude"] ?? ""}");
    final hasLocation = lat != null && lng != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Track Order")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _orderCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: "Order ID",
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loading ? null : _fetch,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Track"),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: Colors.red)),
          ],
          if (tracking != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order ${tracking["order_id"]}",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text("Status: ${tracking["status"] ?? "-"}"),
                    Text(
                      "Delivery Agent: ${tracking["delivery_agent_name"] ?? "Not assigned"}",
                    ),
                    Text(
                      "ETA: ${tracking["estimated_delivery_time"] ?? "-"}",
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: flow
                          .map(
                            (step) => Chip(
                              label: Text((step["name"] ?? "-").toString()),
                              backgroundColor: (step["active"] == true)
                                  ? Colors.blue.shade100
                                  : (step["completed"] == true)
                                      ? Colors.green.shade100
                                      : Colors.grey.shade200,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: Card(
              child: hasLocation
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(lat, lng),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId("agent"),
                          position: LatLng(lat, lng),
                          infoWindow: const InfoWindow(title: "Delivery Agent"),
                        ),
                      },
                    )
                  : const Center(child: Text("Live location unavailable")),
            ),
          ),
        ],
      ),
    );
  }
}
