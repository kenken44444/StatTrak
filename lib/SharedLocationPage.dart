import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:stattrak/models/map_page_functions.dart' as mf;
import 'dart:async';

class SharedRoutePage extends StatefulWidget {
  final String routeId;

  const SharedRoutePage({Key? key, required this.routeId}) : super(key: key);

  @override
  State<SharedRoutePage> createState() => _SharedRoutePageState();
}

class _SharedRoutePageState extends State<SharedRoutePage> {
  final MapController _mapController = MapController();

  LatLng? _startMarker;
  LatLng? _endMarker;
  LatLng? _liveMarker;
  double? _progress;
  String? _avatarUrl;
  List<mf.RouteInfo> _routeAlternatives = [];

  bool _isLoading = true;
  String? _errorMsg;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchRouteData();
    _subscribeToLiveUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchRouteData() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('shared_routes')
          .select('start_lat, start_lng, end_lat, end_lng, current_lat, current_lng, progress, owner_user_id')
          .eq('id', widget.routeId)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMsg = "No shared route found for ID: ${widget.routeId}";
          _isLoading = false;
        });
        return;
      }

      final startLat = response['start_lat'] as double?;
      final startLng = response['start_lng'] as double?;
      final endLat = response['end_lat'] as double?;
      final endLng = response['end_lng'] as double?;

      _liveMarker = (response['current_lat'] != null && response['current_lng'] != null)
          ? LatLng(response['current_lat'], response['current_lng'])
          : null;

      _progress = response['progress'] as double?;

      final ownerUserId = response['owner_user_id'] as String?;

      if (ownerUserId != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', ownerUserId)
            .maybeSingle();

        _avatarUrl = profile?['avatar_url'] as String?;
      }

      if (startLat == null || startLng == null || endLat == null || endLng == null) {
        setState(() {
          _errorMsg = "Invalid or missing coordinates in DB.";
          _isLoading = false;
        });
        return;
      }

      _startMarker = LatLng(startLat, startLng);
      _endMarker = LatLng(endLat, endLng);

      final fetchedRoutes = await mf.fetchAllRoutesForTwoPoints(
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        apiKey: 'b443d51cf9934664828c14742e5476d9',
      );

      setState(() {
        _routeAlternatives = fetchedRoutes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = "Error fetching route: $e";
        _isLoading = false;
      });
    }
  }

  void _subscribeToLiveUpdates() {
    _channel = Supabase.instance.client
        .channel('public:shared_routes')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'shared_routes',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: widget.routeId,
      ),
      callback: (payload) {
        final data = payload.newRecord;
        if (data != null && data['current_lat'] != null && data['current_lng'] != null) {
          setState(() {
            _liveMarker = LatLng(data['current_lat'], data['current_lng']);
            _progress = data['progress'];
          });
          _mapController.move(_liveMarker!, _mapController.zoom);
        }
      },
    ).subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final routeColors = {
      'balanced': Colors.blue.withOpacity(0.8),
      'short': Colors.green.withOpacity(0.8),
      'less_maneuvers': Colors.purple.withOpacity(0.8),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text("Live Shared Route"),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMsg != null
          ? Center(child: Text(_errorMsg!))
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: _startMarker ?? LatLng(0, 0),
          zoom: 13.0,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            tileProvider: CancellableNetworkTileProvider(),
          ),
          if (_routeAlternatives.isNotEmpty)
            PolylineLayer(
              polylines: _routeAlternatives.map((route) {
                final color = routeColors[route.type] ?? Colors.red;
                return Polyline(
                  points: route.points,
                  strokeWidth: 5.0,
                  color: color,
                  borderStrokeWidth: 1.0,
                  borderColor: Colors.white.withOpacity(0.6),
                );
              }).toList(),
            ),
          MarkerLayer(
            markers: [
              if (_startMarker != null)
                Marker(
                  point: _startMarker!,
                  width: 50,
                  height: 50,
                  child: _avatarUrl != null
                      ? CircleAvatar(
                    backgroundImage: NetworkImage(_avatarUrl!),
                    radius: 20,
                  )
                      : Icon(Icons.flag, color: Colors.red),
                ),
              if (_endMarker != null)
                Marker(
                  point: _endMarker!,
                  width: 40,
                  height: 40,
                  child: Icon(Icons.flag, color: Colors.green),
                ),
              if (_liveMarker != null)
                Marker(
                  point: _liveMarker!,
                  width: 60,
                  height: 60,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    child: Icon(Icons.directions_walk, color: Colors.blue, size: 40),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _progress != null
          ? Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
          boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _progress!.clamp(0.0, 100.0) / 100.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 6),
            Text("Progress: ${_progress!.toStringAsFixed(1)}%",
                style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      )
          : null,
    );
  }
}
