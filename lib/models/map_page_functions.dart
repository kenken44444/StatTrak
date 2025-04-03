import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

/// Holds route data including geometry and metadata.
class RouteInfo {
  final String id;
  final String type;
  final List<LatLng> points;
  final double distanceMeters;
  final double timeSeconds;

  RouteInfo({
    required this.id,
    required this.type,
    required this.points,
    required this.distanceMeters,
    required this.timeSeconds,
  });
}

/// Holds calculated progress details.
class RouteProgress {
  final double coveredDistanceMeters;
  final double percentage;

  RouteProgress({
    required this.coveredDistanceMeters,
    required this.percentage,
  });
}

/// Fetches a specific route type from Geoapify. (Internal use)
Future<RouteInfo?> _fetchRouteByTypeInternal({
  required LatLng marker1,
  required LatLng marker2,
  required String type,
  required String mode,
  required String apiKey,
}) async {
  if (apiKey.isEmpty || apiKey == "YOUR_GEOAPIFY_API_KEY") {
    print("Geoapify API Key is missing or invalid.");
    return null;
  }

  final url = "https://api.geoapify.com/v1/routing?"
      "waypoints=${marker1.latitude},${marker1.longitude}|${marker2.latitude},${marker2.longitude}"
      "&mode=$mode"
      "&type=$type"
      "&format=geojson"
      "&apiKey=$apiKey";

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded['features'] == null || decoded['features'].isEmpty) {
        print("No features found in Geoapify response for type $type, mode $mode.");
        return null;
      }

      final feature = decoded['features'][0];
      final geometry = feature['geometry'];
      if (geometry == null || geometry['coordinates'] == null) {
        print("No coordinates found for type $type, mode $mode.");
        return null;
      }

      List<LatLng> points = [];
      if (geometry['type'] == 'MultiLineString') {
        final List<dynamic> multiLineCoordinates = geometry['coordinates'];
        points = multiLineCoordinates.expand((line) {
          return (line as List).map((coord) {
            if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
              return LatLng(coord[1].toDouble(), coord[0].toDouble());
            }
            return null;
          });
        }).whereType<LatLng>().toList();
      } else if (geometry['type'] == 'LineString') {
        final List<dynamic> lineCoordinates = geometry['coordinates'];
        points = lineCoordinates.map((coord) {
          if (coord is List && coord.length >= 2 && coord[0] is num && coord[1] is num) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }
          return null;
        }).whereType<LatLng>().toList();
      }


      if (points.isEmpty) {
        print("Parsed points list is empty for type $type, mode $mode.");
        return null;
      }

      final props = feature['properties'];
      double distanceMeters = (props['distance'] ?? 0.0).toDouble();
      double timeSeconds = (props['time'] ?? 0.0).toDouble();

      return RouteInfo(
        id: "${type}_${DateTime.now().millisecondsSinceEpoch}",
        type: type,
        points: points,
        distanceMeters: distanceMeters,
        timeSeconds: timeSeconds,
      );
    } else {
      print("Error fetching route type $type, mode $mode: ${response.statusCode} ${response.body}");
      return null;
    }
  } catch (e) {
    print("Exception fetching route type $type, mode $mode: $e");
    return null;
  }
}

/// Fetches location suggestions from Geoapify Geocoding API.
Future<List<Map<String, dynamic>>> fetchLocations(String query, String apiKey) async {
  if (apiKey.isEmpty || apiKey == "b443d51cf9934664828c14742e5476d9") {
    print("Geoapify API Key is missing or invalid for location search.");
    return [];
  }
  if (query.length < 3) return [];

  final String url = 'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeComponent(query)}&apiKey=$apiKey&limit=5';

  try {
    final http.Response response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      print('Failed to fetch locations: HTTP ${response.statusCode}');
      return [];
    }

    final Map<String, dynamic> data = json.decode(response.body);

    if (data['features'] == null || data['features'] is! List) {
      return [];
    }

    return List<Map<String, dynamic>>.from((data['features'] as List).map((feature) {
      try {
        final properties = feature['properties'] as Map<String, dynamic>;
        final geometry = feature['geometry'] as Map<String, dynamic>;
        final List<dynamic> coordinates = geometry['coordinates'] as List<dynamic>;
        final double longitude = (coordinates[0] as num).toDouble();
        final double latitude = (coordinates[1] as num).toDouble();
        final String name = properties['formatted'] ?? 'Unknown location';

        return {
          'name': name,
          'latlng': LatLng(latitude, longitude),
          'address': name,
        };
      } catch (e) {
        print("Error processing location feature: $e");
        return null;
      }
    }).where((item) => item != null));
  } catch (e) {
    print("Error in fetchLocations: $e");
    return [];
  }
}

/// Fetches route alternatives and updates the provided list via callbacks.
Future<void> fetchAndSetRoutes({
  required LatLng marker1,
  required LatLng marker2,
  required List<RouteInfo> routeListToUpdate,
  required Function updateStateCallback,
  required Function fitMapCallback,
  required String apiKey,
  required Function(String) showInfoMessage,
  required Function(String) showErrorMessage,
  String mode = 'drive',
}) async {
  if (apiKey.isEmpty || apiKey == "MISSING_GEOAPIFY_KEY") {
    showErrorMessage("Cannot fetch routes: Geoapify API Key is missing.");
    return;
  }

  showInfoMessage("Finding routes...");
  routeListToUpdate.clear();
  updateStateCallback();

  final routeTypes = ['balanced', 'short', 'less_maneuvers'];
  List<Future<RouteInfo?>> futures = [];

  for (final type in routeTypes) {
    futures.add(_fetchRouteByTypeInternal(
      marker1: marker1,
      marker2: marker2,
      type: type,
      mode: mode,
      apiKey: apiKey,
    ));
  }

  try {
    final results = await Future.wait(futures);
    routeListToUpdate.addAll(results.whereType<RouteInfo>());

    updateStateCallback();

    if (routeListToUpdate.isNotEmpty) {
      fitMapCallback();
    } else {
      showErrorMessage("No routes found between markers.");
    }
  } catch (e) {
    print("Error waiting for route futures: $e");
    showErrorMessage("An error occurred while fetching routes.");
    updateStateCallback();
  }
}

/// Fetches the user's avatar URL from Supabase.
Future<String?> fetchUserAvatar(String userId) async {
  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .maybeSingle();
    return response?['avatar_url'] as String?;
  } catch (error) {
    print("Error loading avatar: $error");
    return null;
  }
}

// == Map Page Marker/Interaction Logic ==

/// Handles logic for placing markers on the main map page.
void handleMapTap({
  required LatLng location,
  required LatLng? currentMarker1,
  required LatLng? currentMarker2,
  required Function(LatLng) setMarker1,
  required Function(LatLng) setMarker2,
  required Function(LatLng) triggerWeatherFetch,
  required Function triggerRouteFetch,
  required Function(String) showInfoMessage,
}) {
  if (currentMarker1 == null) {
    setMarker1(location);
    triggerWeatherFetch(location);
  } else if (currentMarker2 == null) {
    setMarker2(location);
    triggerRouteFetch();
  } else {
    showInfoMessage("Both markers are set. Remove one to add a new location.");
  }
}

/// Handles logic for removing a marker on the main map page.
void handleRemoveMarker({
  required int markerNumber,
  required Function clearMarker1State,
  required Function clearMarker2State,
  required List<RouteInfo> routesToClear,
}) {
  if (markerNumber == 1) {
    clearMarker1State();
  } else if (markerNumber == 2) {
    clearMarker2State();
  }
  if (routesToClear.isNotEmpty) {
    routesToClear.clear();
  }
}

/// Moves the map view using the provided MapController.
void moveToLocation(MapController mapController, LatLng location, double zoom) {
  try {
    mapController.move(location, zoom);
  } catch (e) {
    print("Error moving map: $e");
  }
}

/// Adjusts map camera to fit all points from the provided routes.
void fitMapToRoutes({
  required List<RouteInfo> routeAlternatives,
  required MapController mapController,
}) {
  if (routeAlternatives.isEmpty) return;
  final allPoints = routeAlternatives.expand((r) => r.points).toList();
  if (allPoints.isEmpty) return;

  try {
    final bounds = LatLngBounds.fromPoints(allPoints);
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.all(50.0),
      ),
    );
  } catch (e) {
    print("Error fitting map to bounds: $e");
  }
}

/// Gets the current device location once. Handles permissions.
Future<LatLng?> getCurrentLocation(Function(String)? showErrorMessage) async {
  bool serviceEnabled;
  LocationPermission permission;

  try {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      showErrorMessage?.call("Location services are disabled.");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        showErrorMessage?.call("Location permissions are denied.");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      showErrorMessage?.call("Location permissions permanently denied. Enable in settings.");
      return null;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
    return LatLng(position.latitude, position.longitude);
  } catch (e) {
    print("Error getting current location: $e");
    showErrorMessage?.call("Could not get current location.");
    return null;
  }
}


/// Handles the "Get My Location" action on the main map page.
Future<void> handleGetMyLocation({
  required LatLng? currentMarker1,
  required LatLng? currentMarker2,
  required Function(LatLng, {double? targetZoom}) moveMapCallback,
  required Function(LatLng) setMarker1,
  required Function(LatLng) setMarker2,
  required Function triggerRouteFetch,
  required Function(String) showInfoMessage,
  required Function(String) showErrorMessage,
}) async {
  showInfoMessage("Getting your location...");
  final LatLng? userLocation = await getCurrentLocation(showErrorMessage);

  if (userLocation != null) {
    moveMapCallback(userLocation, targetZoom: 15.0);

    if (currentMarker1 == null) {
      setMarker1(userLocation);
    } else if (currentMarker2 == null) {
      setMarker2(userLocation);
      triggerRouteFetch();
    } else {
      showInfoMessage("Both markers already set. Location centered.");
    }
  }
}

Future<List<Map<String, dynamic>>> fetchFriendList(
    String userId,
    Function(String) showErrorMessage,
    ) async {
  print("Fetching friend list for user: $userId");
  try {
    final friendshipResponse = await Supabase.instance.client
        .from('user_friendships')
        .select('user_id, friend_id')
        .or('user_id.eq.$userId,friend_id.eq.$userId')
        .eq('status', 'accepted');

    if (friendshipResponse == null) {
      throw Exception("Received null response fetching friendships.");
    }

    final friendships = (friendshipResponse as List<dynamic>).cast<Map<String, dynamic>>();

    if (friendships.isEmpty) {
      print("No accepted friendships found for user $userId.");
      return [];
    }

    final friendIds = friendships
        .map<String?>((friendship) {
      return (friendship['user_id'] == userId)
          ? friendship['friend_id'] as String?
          : friendship['user_id'] as String?;
    })
        .where((id) => id != null && id != userId)
        .toSet()
        .toList();

    if (friendIds.isEmpty) {
      print("Friend IDs list is empty after filtering.");
      return [];
    }

    print("Found friend IDs: $friendIds");

    final profileResponse = await Supabase.instance.client
        .from('profiles')
        .select('id, username, full_name, avatar_url')
        .inFilter('id', friendIds);

    if (profileResponse == null) {
      throw Exception("Received null response fetching profiles.");
    }

    final profiles = (profileResponse as List<dynamic>).cast<Map<String, dynamic>>();
    print("Fetched ${profiles.length} friend profiles.");
    return profiles;

  } on PostgrestException catch (error) {
    print("Supabase Postgrest error fetching friends: ${error.message}");
    showErrorMessage("Error fetching friends list. (${error.code ?? 'Supabase Error'})");
    return [];
  } catch (error) {
    print("Unexpected error fetching friends: $error");
    showErrorMessage("An unexpected error occurred while fetching friends.");
    return [];
  }
}


/// Inserts the shared route details into the Supabase 'shared_routes' table.
/// Returns true on success, false on failure.
Future<bool> shareRouteWithFriendDb({
  required String currentUserId,
  required String friendId,
  required LatLng marker1, // Start point
  required LatLng marker2, // End point
  required Function(String) showSuccessMessage,
  required Function(String) showErrorMessage,
}) async {
  print("Attempting DB insert to share route from $currentUserId to $friendId...");

  try {
    await Supabase.instance.client
        .from('shared_routes')
        .insert({
      'owner_user_id': currentUserId,
      'friend_user_id': friendId,
      'start_lat': marker1.latitude,
      'start_lng': marker1.longitude,
      'end_lat': marker2.latitude,
      'end_lng': marker2.longitude,
    });

    print("Route shared successfully in DB with friend $friendId");
    showSuccessMessage("Route shared successfully!");
    return true;

  } on PostgrestException catch (error) {
    print("Supabase Postgrest error sharing route: ${error.message}");
    String uiError = "Failed to share route. (${error.code ?? 'DB Error'})";
    if (error.message.contains("violates row-level security policy")) {
      uiError = "Failed to share route. (Permission denied)";
    } else if (error.message.contains("violates foreign key constraint")) {
      uiError = "Failed to share route. (Invalid friend ID)";
    }
    showErrorMessage(uiError);
    return false;
  } catch (e) {
    print("Generic exception sharing route: $e");
    showErrorMessage("An error occurred while sharing route.");
    return false;
  }
}

Future<List<RouteInfo>> fetchAllRoutesForTwoPoints({
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  required String apiKey,
  String mode = 'drive',
  Function(String)? showErrorMessage,
}) async {
  if (apiKey.isEmpty || apiKey == "YOUR_GEOAPIFY_API_KEY") {
    print("Geoapify API Key is missing or invalid.");
    showErrorMessage?.call("API Key is missing, cannot fetch route geometry.");
    return [];
  }

  print("Fetching route geometry for shared route...");

  LatLng marker1 = LatLng(startLat, startLng);
  LatLng marker2 = LatLng(endLat, endLng);

  final routeTypes = ['balanced', 'short', 'less_maneuvers'];
  List<RouteInfo> routes = [];
  List<Future<RouteInfo?>> futures = [];

  for (String type in routeTypes) {
    futures.add(_fetchRouteByTypeInternal(
      marker1: marker1,
      marker2: marker2,
      type: type,
      mode: mode,
      apiKey: apiKey,
    ));
  }

  try {
    final results = await Future.wait(futures);
    routes.addAll(results.whereType<RouteInfo>());

    print("Fetched ${routes.length} route geometries.");
    if (routes.isEmpty) {
      showErrorMessage?.call("Could not fetch route geometry between the points.");
    }
    return routes;
  } catch (e) {
    print("Error fetching routes for two points: $e");
    showErrorMessage?.call("An error occurred while fetching route geometry.");
    return [];
  }
}

/// Gets high-accuracy location with more aggressive settings for indoor use
Future<LatLng?> getHighAccuracyLocation(Function(String)? showErrorMessage) async {
  try {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
      timeLimit: Duration(seconds: 5),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (e) {
    if (e is TimeoutException) {
      print("Location request timed out.");
      if (!kIsWeb) { // Only try last known on non-web platforms
        print("Trying with last known position.");
        try {
          Position? position = await Geolocator.getLastKnownPosition();
          if (position != null) {
            return LatLng(position.latitude, position.longitude);
          } else {
            print("Last known position is null.");
          }
        } catch (fallbackError) {
          // Handle potential errors on mobile too, though less likely
          print("Error getting last known position: $fallbackError");
        }
      } else {
        print("Skipping getLastKnownPosition on web platform.");
      }
      // *** END CHANGE ***
    }
    print("Error getting high accuracy location: $e");
    // showErrorMessage?.call("Location error. Ensure GPS/Location is enabled."); // Modified message
    return null;
  }
}

StreamSubscription<Position>? startLocationUpdatesStream({
  required Function(LatLng) onLocationUpdate,
  required Function(String) onError,
  LocationAccuracy accuracy = LocationAccuracy.high,
  int distanceFilter = 0,
  int timeInterval = 1000,
}) {
  try {
    final LocationSettings locationSettings = AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      intervalDuration: Duration(milliseconds: timeInterval),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: "Location Tracking Active",
        notificationText: "Tracking your route progress",
        enableWakeLock: true,
      ),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
        onLocationUpdate(LatLng(position.latitude, position.longitude));
      },
      onError: (error) {
        print("Error in location stream: $error");
        onError("Location updates failed: ${error.toString()}");
      },
      cancelOnError: false,
    );
  } catch (e) {
    print("Could not start location stream: $e");
    onError("Failed to start location tracking: ${e.toString()}");
    return null;
  }
}

/// Enhanced route progress calculation with improved nearest point detection
RouteProgress calculateRouteProgress({
  required LatLng currentLocation,
  required List<LatLng> routePoints,
  required double totalRouteDistanceMeters,
}) {
  if (routePoints.isEmpty || totalRouteDistanceMeters <= 0) {
    return RouteProgress(coveredDistanceMeters: 0, percentage: 0);
  }

  double minDistanceToRoute = double.infinity;
  int closestSegmentIndex = 0;
  double progressOnSegment = 0.0;

  for (int i = 0; i < routePoints.length - 1; i++) {
    final p1 = routePoints[i];
    final p2 = routePoints[i + 1];

    final result = _pointToLineSegmentDistance(
        currentLocation, p1, p2
    );

    if (result.distance < minDistanceToRoute) {
      minDistanceToRoute = result.distance;
      closestSegmentIndex = i;
      progressOnSegment = result.progress;
    }
  }

  double coveredDistance = 0;
  for (int i = 0; i < closestSegmentIndex; i++) {
    final p1 = routePoints[i];
    final p2 = routePoints[i + 1];
    coveredDistance += Geolocator.distanceBetween(
        p1.latitude, p1.longitude, p2.latitude, p2.longitude
    );
  }

  final currentSegmentStart = routePoints[closestSegmentIndex];
  final currentSegmentEnd = routePoints[closestSegmentIndex + 1];
  final currentSegmentLength = Geolocator.distanceBetween(
      currentSegmentStart.latitude, currentSegmentStart.longitude,
      currentSegmentEnd.latitude, currentSegmentEnd.longitude
  );

  coveredDistance += currentSegmentLength * progressOnSegment;

  double percentage = (coveredDistance / totalRouteDistanceMeters * 100).clamp(0.0, 100.0);

  return RouteProgress(
    coveredDistanceMeters: coveredDistance,
    percentage: percentage,
  );
}

/// Helper class to return both distance and progress along segment
class SegmentProjection {
  final double distance;
  final double progress;

  SegmentProjection(this.distance, this.progress);
}

/// Calculate the perpendicular distance from a point to a line segment
/// and the normalized progress (0-1) along that segment
SegmentProjection _pointToLineSegmentDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {

  double scaleFactorLat = 111111.0;
  double scaleFactorLng = 111111.0 * cos(lineStart.latitude * (pi / 180.0));

  double x = point.latitude * scaleFactorLat;
  double y = point.longitude * scaleFactorLng;
  double x1 = lineStart.latitude * scaleFactorLat;
  double y1 = lineStart.longitude * scaleFactorLng;
  double x2 = lineEnd.latitude * scaleFactorLat;
  double y2 = lineEnd.longitude * scaleFactorLng;

  double dx = x2 - x1;
  double dy = y2 - y1;
  double segmentLengthSquared = dx * dx + dy * dy;

  if (segmentLengthSquared < 0.0001) {
    double distance = sqrt(pow(x - x1, 2) + pow(y - y1, 2));
    return SegmentProjection(distance, 0.0);
  }

  double t = ((x - x1) * dx + (y - y1) * dy) / segmentLengthSquared;
  t = t.clamp(0.0, 1.0);
  double projX = x1 + t * dx;
  double projY = y1 + t * dy;
  double distance = sqrt(pow(x - projX, 2) + pow(y - projY, 2));

  return SegmentProjection(distance, t);
}

double calculateNearestDistanceToRoute({
  required LatLng currentLocation,
  required List<LatLng> routePoints,
}) {
  double minDistance = double.infinity;
  for (int i = 0; i < routePoints.length - 1; i++) {
    final segmentStart = routePoints[i];
    final segmentEnd = routePoints[i + 1];
    final result = _pointToLineSegmentDistance(currentLocation, segmentStart, segmentEnd);
    if (result.distance < minDistance) {
      minDistance = result.distance;
    }
  }
  return minDistance;
}


/// For better backend sync - with error fallback
Future<void> syncProgressWithSupabase({
  required String routeId,
  required LatLng currentLocation,
  required double progress,
}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;

  if (userId == null) {
    print("User not logged in");
    return;
  }

  try {
    final response = await Supabase.instance.client
        .from('route_progress')
        .insert({
      'route_id': routeId,
      'user_id': userId,
      'lat': currentLocation.latitude,
      'lng': currentLocation.longitude,
      'progress': progress,
      'timestamp': DateTime.now().toIso8601String(),
    });

    print("Successfully synced with Supabase: $progress%");
  } catch (e) {
    print("Supabase sync error: $e");
  }
}

Future<void> updateSharedRouteLiveProgress({
  required String ownerUserId,
  required String friendUserId,
  required LatLng currentLocation,
  required double progress,
}) async {
  try {
    await Supabase.instance.client
        .from('shared_routes')
        .update({
      'current_lat': currentLocation.latitude,
      'current_lng': currentLocation.longitude,
      'progress': progress,
      'created_at': DateTime.now().toIso8601String(),
    })
        .match({
      'owner_user_id': ownerUserId,
      'friend_user_id': friendUserId,
    });

    print("✅ Shared route live progress updated.");
  } catch (e) {
    print("❌ Failed to update shared route live progress: $e");
  }
}