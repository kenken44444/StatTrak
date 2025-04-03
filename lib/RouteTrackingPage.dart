import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:stattrak/utils/Smsservice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/map_page_functions.dart' as mf;

class TrackingState {
  final LatLng? userLocation;
  final mf.RouteProgress progress;
  final bool isLoading;
  final bool isCompleted;
  final DateTime? lastUpdateTime;

  TrackingState({
    this.userLocation,
    required this.progress,
    this.isLoading = false,
    this.isCompleted = false,
    this.lastUpdateTime,
  });

  TrackingState copyWith({
    LatLng? userLocation,
    mf.RouteProgress? progress,
    bool? isLoading,
    bool? isCompleted,
    DateTime? lastUpdateTime,
  }) {
    return TrackingState(
      userLocation: userLocation ?? this.userLocation,
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }
}

LatLng? _previousLoggedLocation;

class RouteTrackingPage extends StatefulWidget {
  final LatLng startPoint;
  final LatLng endPoint;
  final mf.RouteInfo selectedRoute;

  const RouteTrackingPage({
    Key? key,
    required this.startPoint,
    required this.endPoint,
    required this.selectedRoute,
  }) : super(key: key);

  @override
  _RouteTrackingPageState createState() => _RouteTrackingPageState();
}

class _RouteTrackingPageState extends State<RouteTrackingPage> {
  final MapController mapController = MapController();
  StreamSubscription<Position>? _locationSubscription;
  Timer? _periodicUpdateTimer;
  Timer? _backendSyncTimer;
  Timer? _logLocationTimer;

  double zoomLevel = 16.0;
  bool autoFollow = true;

  TrackingState _trackingState = TrackingState(
    progress: mf.RouteProgress(coveredDistanceMeters: 0, percentage: 0),
    isLoading: true,
  );

  String? _selectedFriendId;

  @override
  void initState() {
    super.initState();
    _initializeTracking();

    _periodicUpdateTimer = Timer.periodic(
        const Duration(seconds: 1), (_) => _refreshLocationState());

    _backendSyncTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _syncWithBackend());

    _logLocationTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _logUserLocation());
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _toggleAutoFollow() {
    setState(() {
      autoFollow = !autoFollow;
      if (autoFollow && _trackingState.userLocation != null) {
        mf.moveToLocation(mapController, _trackingState.userLocation!, zoomLevel);
      }
    });
  }

  Future<void> _showFriendPickerAndShareRoute() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final friends = await mf.fetchFriendList(userId, _showErrorSnackbar);

    if (!mounted || friends.isEmpty) {
      _showErrorSnackbar("You have no friends to share the route with.");
      return;
    }

    final friend = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return ListView(
          children: friends.map((friend) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(friend['avatar_url'] ?? ''),
              ),
              title: Text(friend['full_name'] ?? friend['username']),
              subtitle: Text('@${friend['username']}'),
              onTap: () => Navigator.pop(context, friend),
            );
          }).toList(),
        );
      },
    );

    if (friend == null) return;

    final success = await mf.shareRouteWithFriendDb(
      currentUserId: userId,
      friendId: friend['id'],
      marker1: widget.startPoint,
      marker2: widget.endPoint,
      showSuccessMessage: _showSuccessSnackbar,
      showErrorMessage: _showErrorSnackbar,
    );

    if (success) {
      setState(() {
        _selectedFriendId = friend['id'];
      });

      // ✅ Fetch friend's phone number from Supabase
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('phone, full_name')
          .eq('id', friend['id'])
          .maybeSingle();

      final phoneNumber = profile?['phone'];
      final fullName = profile?['full_name'] ?? friend['username'];

      if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
        final message = "Hi $fullName! Your friend just shared a live route with you on StaTrak 🚴. Check the app for updates.";

        try {
          await SmsService.sendSms(
            number: phoneNumber.toString(),
            message: message,
          );
          _showSuccessSnackbar("SMS sent to $fullName");
        } catch (e) {
          _showErrorSnackbar("Failed to send SMS: $e");
        }
      } else {
        _showErrorSnackbar("No phone number found for $fullName");
      }
    }
  }

  Future<void> _initializeTracking() async {
    setState(() {
      _trackingState = _trackingState.copyWith(isLoading: true);
    });

    await _checkAndRequestPermissions();

    final initialLocation = await mf.getCurrentLocation(_showErrorSnackbar);
    if (!mounted) return;

    if (initialLocation != null) {
      final progress = mf.calculateRouteProgress(
        currentLocation: initialLocation,
        routePoints: widget.selectedRoute.points,
        totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
      );

      setState(() {
        _trackingState = _trackingState.copyWith(
          userLocation: initialLocation,
          progress: progress,
          isLoading: false,
        );
      });

      if (autoFollow) {
        mf.moveToLocation(mapController, initialLocation, zoomLevel);
      }
    } else {
      setState(() {
        _trackingState = _trackingState.copyWith(isLoading: false);
      });
      _showErrorSnackbar("Could not get initial location. Tracking started with last known position.");
    }

    _locationSubscription = mf.startLocationUpdatesStream(
      onLocationUpdate: _handleLocationUpdate,
      onError: _showErrorSnackbar,
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      timeInterval: 1000,
    );
  }

  Future<void> _checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackbar("Location services are disabled. Please enable in settings.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackbar("Location permissions denied. Tracking may not work properly.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackbar("Location permissions permanently denied. Please enable in app settings.");
    }
  }

  Future<void> _handleLocationUpdate(LatLng newLocation) async {
    if (!mounted) return;

    final bool hasLocationChanged = _trackingState.userLocation == null ||
        _calculateDistance(_trackingState.userLocation!, newLocation) > 0.1;

    if (hasLocationChanged) {
      final newProgress = mf.calculateRouteProgress(
        currentLocation: newLocation,
        routePoints: widget.selectedRoute.points,
        totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
      );

      bool isCompleted = newProgress.percentage >= 99.0;

      setState(() {
        _trackingState = _trackingState.copyWith(
          userLocation: newLocation,
          progress: newProgress,
          isCompleted: isCompleted,
          lastUpdateTime: DateTime.now(),
        );
      });

      if (autoFollow) {
        mf.moveToLocation(mapController, newLocation, zoomLevel);
      }

      final nearestDistance = mf.calculateNearestDistanceToRoute(
        currentLocation: newLocation,
        routePoints: widget.selectedRoute.points,
      );

// Customize your threshold
      if (nearestDistance > 50 && !_trackingState.isCompleted) {
        print("⚠️ Possible detour detected.");

        if (_selectedFriendId != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('phone, full_name')
              .eq('id', _selectedFriendId!)
              .maybeSingle();

          final phoneNumber = profile?['phone'];
          final fullName = profile?['full_name'] ?? "Your friend";

          if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
            final username = Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'A friend';
            final message = SmsService.routeDetourMessage(username, "a shared route");

            try {
              await SmsService.sendSms(number: phoneNumber.toString(), message: message);
              _showSuccessSnackbar("SMS sent: Possible detour.");
            } catch (e) {
              _showErrorSnackbar("Failed to send detour SMS.");
            }
          }
        }
      }

      if (isCompleted && !_trackingState.isCompleted) {
        _showSuccessSnackbar("Route completed!");

        // 📤 Send SMS to friend
        if (_selectedFriendId != null) {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('phone, full_name')
              .eq('id', _selectedFriendId!)
              .maybeSingle();

          final phoneNumber = profile?['phone'];
          final fullName = profile?['full_name'] ?? "Your friend";

          if (phoneNumber != null && phoneNumber.toString().isNotEmpty) {
            final username = Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'A friend';
            final message = SmsService.routeCompletedMessage(username, "a shared route");

            try {
              await SmsService.sendSms(number: phoneNumber.toString(), message: message);
              _showSuccessSnackbar("SMS sent: Route completed.");
            } catch (e) {
              _showErrorSnackbar("Failed to send route completion SMS.");
            }
          }
        }

        // Cancel timers/subscriptions
        _locationSubscription?.pause();
        _periodicUpdateTimer?.cancel();
        _backendSyncTimer?.cancel();
        _logLocationTimer?.cancel();
      }
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
        point1.latitude, point1.longitude, point2.latitude, point2.longitude);
  }

  Future<void> _refreshLocationState() async {
    if (_trackingState.isCompleted) return;

    try {
      final location = await mf.getHighAccuracyLocation(_showErrorSnackbar);
      if (!mounted || location == null) return;

      final progress = mf.calculateRouteProgress(
        currentLocation: location,
        routePoints: widget.selectedRoute.points,
        totalRouteDistanceMeters: widget.selectedRoute.distanceMeters,
      );

      setState(() {
        _trackingState = _trackingState.copyWith(
          userLocation: location,
          progress: progress,
          lastUpdateTime: DateTime.now(),
        );
      });

      if (autoFollow) {
        mf.moveToLocation(mapController, location, zoomLevel);
      }

      if (progress.percentage >= 99.0 && !_trackingState.isCompleted) {
        setState(() {
          _trackingState = _trackingState.copyWith(isCompleted: true);
        });
        _showSuccessSnackbar("Route completed!");
        _periodicUpdateTimer?.cancel();
        _backendSyncTimer?.cancel();
        _logLocationTimer?.cancel();
      }
    } catch (e) {
      print("Location refresh error: $e");
    }
  }

  Future<void> _syncWithBackend() async {
    if (_trackingState.userLocation == null || _selectedFriendId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await mf.updateSharedRouteLiveProgress(
        ownerUserId: userId,
        friendUserId: _selectedFriendId!,
        currentLocation: _trackingState.userLocation!,
        progress: _trackingState.progress.percentage,
      );
    } catch (e) {
      print("Backend sync error: $e");
    }
  }

  void _logUserLocation() {
    if (_trackingState.userLocation != null) {
      final lat = _trackingState.userLocation!.latitude;
      final lng = _trackingState.userLocation!.longitude;
      final now = DateTime.now();
      final timestamp = "${now.hour}:${now.minute}:${now.second}";
      print("📍 User Location at $timestamp - Lat: $lat, Lng: $lng");

      if (_previousLoggedLocation != null) {
        final distance = _calculateDistance(_previousLoggedLocation!, _trackingState.userLocation!);
        print("📏 Distance moved: ${distance.toStringAsFixed(2)} meters since last log");
      }

      _previousLoggedLocation = _trackingState.userLocation;
    } else {
      print("📍 User location not available yet.");
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _periodicUpdateTimer?.cancel();
    _backendSyncTimer?.cancel();
    _logLocationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final routeColor = widget.selectedRoute.type == 'short'
        ? Colors.green
        : widget.selectedRoute.type == 'less_maneuvers'
        ? Colors.purple
        : colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking Route'),
        backgroundColor: theme.appBarTheme.backgroundColor ?? colorScheme.primary,
        foregroundColor: theme.appBarTheme.foregroundColor ?? colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _showFriendPickerAndShareRoute,
            tooltip: 'Share route with a friend',
          ),
          IconButton(
            icon: Icon(autoFollow ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: _toggleAutoFollow,
            tooltip: autoFollow ? "Disable Auto-Follow" : "Enable Auto-Follow",
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _trackingState.userLocation ?? widget.startPoint,
              initialZoom: zoomLevel,
              maxZoom: 19,
              minZoom: 5,
              onPositionChanged: (position, hasGesture) {
                if (!mounted) return;
                bool zoomChanged = false;
                if (position.zoom != null && position.zoom != zoomLevel) {
                  zoomLevel = position.zoom!;
                  zoomChanged = true;
                }
                if (hasGesture && autoFollow) {
                  setState(() {
                    autoFollow = false;
                  });
                } else if (zoomChanged) {
                  setState(() {});
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.stattrak.app',
                tileProvider: CancellableNetworkTileProvider(),
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.selectedRoute.points,
                    strokeWidth: 6.0,
                    color: routeColor.withOpacity(0.7),
                    borderStrokeWidth: 1.0,
                    borderColor: Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.startPoint,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: "Start",
                      child: Icon(Icons.trip_origin, color: Colors.redAccent, size: 35),
                    ),
                  ),
                  Marker(
                    point: widget.endPoint,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: "Destination",
                      child: Icon(Icons.flag, color: colorScheme.secondary, size: 35),
                    ),
                  ),
                  if (_trackingState.userLocation != null)
                    Marker(
                      point: _trackingState.userLocation!,
                      width: 80,
                      height: 80,
                      alignment: Alignment.center,
                      child: Tooltip(
                        message: "You are here",
                        child: Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.blue,
                          size: 40,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 5.0)],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_trackingState.isLoading)
            Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: _trackingState.progress.percentage / 100.0,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(routeColor),
                      minHeight: 6,
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Progress: ${_trackingState.progress.percentage.toStringAsFixed(1)}%",
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_trackingState.userLocation != null)
                          Text(
                            "Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}