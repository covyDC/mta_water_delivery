import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Real-time GPS tracking widget for staff dashboard
/// Shows live driver locations on a map with delivery status
class DriverTrackingMap extends StatefulWidget {
  final List<DriverLocation> drivers;
  final Function(String driverId) onDriverTapped;
  final LatLng initialCenter;
  final double initialZoom;

  const DriverTrackingMap({
    super.key,
    required this.drivers,
    required this.onDriverTapped,
    this.initialCenter = const LatLng(14.5995, 120.9842), // Manila center
    this.initialZoom = 12,
  });

  @override
  State<DriverTrackingMap> createState() => _DriverTrackingMapState();
}

class _DriverTrackingMapState extends State<DriverTrackingMap> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  @override
  void didUpdateWidget(DriverTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drivers != widget.drivers) {
      _updateMarkers();
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    for (final driver in widget.drivers) {
      final markerColor = _getMarkerColor(driver.status);
      markers.add(
        Marker(
          markerId: MarkerId(driver.id),
          position: LatLng(driver.latitude, driver.longitude),
          infoWindow: InfoWindow(
            title: driver.name,
            snippet: '${driver.status} • ${driver.activeDeliveries} deliveries',
            onTap: () => widget.onDriverTapped(driver.id),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(markerColor),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });
  }

  double _getMarkerColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'active':
        return BitmapDescriptor.hueGreen;
      case 'on_delivery':
        return BitmapDescriptor.hueBlue;
      case 'break':
        return BitmapDescriptor.hueYellow;
      case 'offline':
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueRose;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
      initialCameraPosition: CameraPosition(
        target: widget.initialCenter,
        zoom: widget.initialZoom,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      mapToolbarEnabled: true,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

/// Data model for driver location
class DriverLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String status; // online, on_delivery, break, offline
  final int activeDeliveries;
  final DateTime lastUpdate;
  final String? currentOrder;

  DriverLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.activeDeliveries,
    required this.lastUpdate,
    this.currentOrder,
  });

  factory DriverLocation.fromMap(Map<String, dynamic> map) {
    return DriverLocation(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'offline',
      activeDeliveries: map['activeDeliveries'] ?? 0,
      lastUpdate: map['lastUpdate'] is DateTime
          ? map['lastUpdate']
          : DateTime.now(),
      currentOrder: map['currentOrder'],
    );
  }
}

/// Driver location list card for sidebar view
class DriverLocationCard extends StatelessWidget {
  final DriverLocation driver;
  final VoidCallback onTap;
  final VoidCallback? onCall;
  final VoidCallback? onNavigate;

  const DriverLocationCard({
    super.key,
    required this.driver,
    required this.onTap,
    this.onCall,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(driver.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(driver.status),
            color: statusColor,
            size: 20,
          ),
        ),
        title: Text(
          driver.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              driver.status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${driver.activeDeliveries} active delivery${driver.activeDeliveries != 1 ? 'ies' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onCall != null)
                IconButton(
                  icon: const Icon(Icons.call, size: 18),
                  onPressed: onCall,
                  tooltip: 'Call driver',
                ),
              if (onNavigate != null)
                IconButton(
                  icon: const Icon(Icons.location_on, size: 18),
                  onPressed: onNavigate,
                  tooltip: 'Navigate',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'on_delivery':
        return Colors.blue;
      case 'break':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Icons.check_circle;
      case 'on_delivery':
        return Icons.local_shipping;
      case 'break':
        return Icons.pause_circle;
      case 'offline':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
