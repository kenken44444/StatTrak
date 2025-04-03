import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:stattrak/RouteTrackingPage.dart' show RouteTrackingPage;
import 'package:stattrak/utils/Smsservice.dart';
// Import logic functions
import 'models/map_page_functions.dart' as mf;
import 'package:stattrak/weather_service.dart';
import 'package:stattrak/widgets/appbar.dart';    // Ensure path is correct
import 'package:supabase_flutter/supabase_flutter.dart';

// Ensure API Key is loaded
final String geoapifyApiKey = 'b443d51cf9934664828c14742e5476d9';

class MapPage extends StatefulWidget {
  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // --- State Variables ---
  LatLng? marker1;
  LatLng? marker2;
  List<mf.RouteInfo> routeAlternatives = [];
  double zoomLevel = 13.0;
  bool showMarkerDetails = false;
  String? _avatarUrl;
  final userId = Supabase.instance.client.auth.currentUser?.id;

  // --- Loading/Busy Flags ---
  bool _isLoadingAvatar = true;
  bool _isLoadingRoutes = false;
  bool _isLoadingLocation = false;
  // bool _isSharingRoute = false; // Add if share feature is re-added

  // --- Controllers ---
  final MapController mapController = MapController();
  TextEditingController searchController = TextEditingController();
  TextEditingController marker1Controller = TextEditingController();
  TextEditingController marker2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    searchController.dispose();
    marker1Controller.dispose();
    marker2Controller.dispose();
    mapController.dispose();
    super.dispose();
  }

  // --- Initial Data Fetch ---
  Future<void> _fetchInitialData() async {
    if (userId != null) {
      setState(() => _isLoadingAvatar = true);
      final url = await mf.fetchUserAvatar(userId!);
      if (mounted) setState(() { _avatarUrl = url; _isLoadingAvatar = false; });
    } else {
      if (mounted) setState(() => _isLoadingAvatar = false);
    }
  }

  // --- UI Feedback Helpers ---
  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Theme.of(context).snackBarTheme.backgroundColor,
      duration: Duration(seconds: isError ? 4 : 2),
    ));
  }
  void _showInfoSnackbar(String message) => _showSnackbar(message);
  void _showErrorSnackbar(String message) => _showSnackbar(message, isError: true);

  // --- Callbacks for Logic Functions ---
  void _triggerWeatherFetch(LatLng location) {
    WeatherService.fetchDetailedForecast(lat: location.latitude, lon: location.longitude)
        .then((forecast) { if (mounted) showDetailedForecastDialog(forecast); })
        .catchError((error) { _showErrorSnackbar("Could not fetch weather data."); });
  }

  void _triggerRouteFetch() {
    if (marker1 != null && marker2 != null) {
      setState(() => _isLoadingRoutes = true);
      mf.fetchAndSetRoutes(
        marker1: marker1!, marker2: marker2!,
        routeListToUpdate: routeAlternatives,
        updateStateCallback: () { if (mounted) setState(() => _isLoadingRoutes = false); },
        fitMapCallback: () => mf.fitMapToRoutes(routeAlternatives: routeAlternatives, mapController: mapController),
        apiKey: 'b443d51cf9934664828c14742e5476d9',
        showInfoMessage: _showInfoSnackbar,
        showErrorMessage: _showErrorSnackbar,
      ).catchError((e){ if (mounted) setState(() => _isLoadingRoutes = false); });
    }
  }

  void _updateMarkerText() {
    marker1Controller.text = marker1 != null ? "${marker1!.latitude.toStringAsFixed(6)}, ${marker1!.longitude.toStringAsFixed(6)}" : "";
    marker2Controller.text = marker2 != null ? "${marker2!.latitude.toStringAsFixed(6)}, ${marker2!.longitude.toStringAsFixed(6)}" : "";
  }

  // --- UI Dialog ---
  void showDetailedForecastDialog(OneCallForecast forecast) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Detailed Forecast"),
          content: SingleChildScrollView(),
          actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("Close")) ],
        );
      },
    );
  }

  // --- Navigation ---
  void _startRouteTracking(mf.RouteInfo selectedRoute) {
    if (marker1 == null || marker2 == null) {
      _showErrorSnackbar("Start and end markers required for tracking.");
      return;
    }
    // Navigate to the new RouteTrackingPage
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RouteTrackingPage(
          startPoint: marker1!,
          endPoint: marker2!,
          selectedRoute: selectedRoute,
        ),
      ),
    );
  }

  Future<void> notifyFriendOfSharedRoute({
    required String friendUserId,
    required double lat,
    required double lng,
  }) async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) return;

    try {
      final userProfile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', currentUser.id)
          .single();

      final friendProfile = await supabase
          .from('profiles')
          .select('phone')
          .eq('id', friendUserId)
          .single();

      final String? phone = friendProfile['phone'];
      final String name = userProfile['full_name'];

      if (phone != null && phone.isNotEmpty) {
        final message = SmsService.locationShareMessage(name, lat, lng);
        await SmsService.sendSms(number: phone, message: message);
      } else {
        print("❗ Friend has no phone number.");
      }
    } catch (e) {
      print("❌ Error sending SMS: $e");
    }
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final routeColors = {
      'balanced': colorScheme.primary.withOpacity(0.8),
      'short': Colors.green.withOpacity(0.8),
      'less_maneuvers': colorScheme.tertiary.withOpacity(0.8),
    };

    return Scaffold(
      appBar: MyCustomAppBar(
        onNotificationPressed: () { /* Nav */ },
        onGroupPressed: () { /* Nav */ },
        avatarUrl: _avatarUrl,
        isLoading: _isLoadingAvatar,
      ),
      // --- Bottom Sheet: Select Route for Tracking ---
      bottomSheet: routeAlternatives.isNotEmpty
          ? Container(
        color: theme.cardColor,
        padding: EdgeInsets.all(12.0),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35), // Slightly more height
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select a Route to Start Tracking:",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: routeAlternatives.length,
                itemBuilder: (context, index) {
                  final route = routeAlternatives[index];
                  final distanceKm = (route.distanceMeters / 1000).toStringAsFixed(1);
                  final timeMin = (route.timeSeconds / 60).toStringAsFixed(0);
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
                    leading: CircleAvatar(radius: 8, backgroundColor: routeColors[route.type] ?? Colors.grey),
                    title: Text("${route.type.toUpperCase()} (${distanceKm}km, ~${timeMin}min)", style: theme.textTheme.bodyMedium),
                    // Trailing button to start tracking THIS route
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        textStyle: theme.textTheme.labelSmall,
                      ),
                      onPressed: () => _startRouteTracking(route), // Navigate on press
                      child: Text("Track"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      )
          : null,
      // --- Main Body: Map ---
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: LatLng(14.6760, 121.0437), // QC
              initialZoom: zoomLevel,
              maxZoom: 19, minZoom: 5,
              // Map Tap -> Call Logic
              onTap: (pos, latLng) => mf.handleMapTap(
                location: latLng, currentMarker1: marker1, currentMarker2: marker2,
                setMarker1: (loc) => setState(() { marker1 = loc; _updateMarkerText(); }),
                setMarker2: (loc) => setState(() { marker2 = loc; _updateMarkerText(); }),
                triggerWeatherFetch: _triggerWeatherFetch, triggerRouteFetch: _triggerRouteFetch,
                showInfoMessage: _showInfoSnackbar,
              ),
              onPositionChanged: (pos, gesture) {
                if (mounted && pos.zoom != null && pos.zoom != zoomLevel) {
                  setState(() => zoomLevel = pos.zoom!);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: ['a','b','c'],
                userAgentPackageName: 'com.stattrak.app', // Your package name
                tileProvider: CancellableNetworkTileProvider(),
              ),
              if (routeAlternatives.isNotEmpty)
                PolylineLayer(
                  polylines: routeAlternatives.map((route) => Polyline(
                    points: route.points, strokeWidth: 5.0,
                    color: (routeColors[route.type] ?? Colors.grey).withOpacity(0.8),
                    borderStrokeWidth: 1.0, borderColor: Colors.white.withOpacity(0.6),
                  )).toList(),
                ),
              MarkerLayer(
                markers: [
                  if (marker1 != null)
                    Marker(
                      point: marker1!, width: 80, height: 80, alignment: Alignment.topCenter,
                      child: Tooltip( message: "Start / Point 1\nTap to remove",
                        child: GestureDetector(
                          // Marker Tap -> Call Logic
                          onTap: () { mf.handleRemoveMarker(markerNumber: 1, clearMarker1State: ()=> setState((){ marker1=null; _updateMarkerText(); }), clearMarker2State: (){}, routesToClear: routeAlternatives); setState((){});},
                          child: Icon(Icons.location_on, color: colorScheme.primary, size: 40),
                        ),
                      ),
                    ),
                  if (marker2 != null)
                    Marker(
                      point: marker2!, width: 80, height: 80, alignment: Alignment.topCenter,
                      child: Tooltip( message: "End / Point 2\nTap to remove",
                        child: GestureDetector(
                          // Marker Tap -> Call Logic
                          onTap: () { mf.handleRemoveMarker(markerNumber: 2, clearMarker1State: (){}, clearMarker2State: ()=> setState((){ marker2=null; _updateMarkerText(); }), routesToClear: routeAlternatives); setState((){});},
                          child: Icon(Icons.location_on, color: colorScheme.secondary, size: 40),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // --- Marker Details Card ---
          Positioned(
            top: 70, left: 10, right: 10,
            child: Card(
              elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 250), padding: EdgeInsets.all(12.0),
                constraints: BoxConstraints(minHeight: 50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row( /* ... Header with expand/collapse ... */
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Markers & Routes", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(showMarkerDetails ? Icons.expand_less : Icons.expand_more),
                          tooltip: showMarkerDetails ? "Collapse Details" : "Expand Details",
                          padding: EdgeInsets.zero, constraints: BoxConstraints(),
                          onPressed: () => setState(() => showMarkerDetails = !showMarkerDetails),
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: Container(),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField( controller: marker1Controller, readOnly: true, /* ... Decoration ... */
                              decoration: InputDecoration( labelText: "Start / Marker 1", hintText: "Tap map to set", isDense: true, prefixIcon: Icon(Icons.pin_drop, size: 18, color: colorScheme.primary),
                                suffixIcon: marker1 == null ? null : IconButton( icon: Icon(Icons.clear, color: Colors.grey[600], size: 20), tooltip: "Remove Marker 1",
                                    onPressed: () { mf.handleRemoveMarker(markerNumber: 1, clearMarker1State: ()=> setState((){ marker1=null; _updateMarkerText(); }), clearMarker2State: (){}, routesToClear: routeAlternatives); setState((){});}),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12), ), style: theme.textTheme.bodySmall,
                            ),
                            SizedBox(height: 10),
                            TextField( controller: marker2Controller, readOnly: true, /* ... Decoration ... */
                              decoration: InputDecoration( labelText: "End / Marker 2", hintText: "Tap map to set", isDense: true, prefixIcon: Icon(Icons.flag, size: 18, color: colorScheme.secondary),
                                suffixIcon: marker2 == null ? null : IconButton( icon: Icon(Icons.clear, color: Colors.grey[600], size: 20), tooltip: "Remove Marker 2",
                                    onPressed: () { mf.handleRemoveMarker(markerNumber: 2, clearMarker1State: (){}, clearMarker2State: ()=> setState((){ marker2=null; _updateMarkerText(); }), routesToClear: routeAlternatives); setState((){});}),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12), ), style: theme.textTheme.bodySmall,
                            ),
                            if (marker1 != null && marker2 != null) ...[
                              SizedBox(height: 15),
                              ElevatedButton.icon(
                                icon: _isLoadingRoutes ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary)) : Icon(Icons.directions),
                                label: Text(routeAlternatives.isEmpty ? "Find Routes" : "Refresh Routes"),
                                onPressed: _isLoadingRoutes ? null : _triggerRouteFetch, // Calls logic wrapper
                                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 36)),
                              ),
                            ]
                          ],
                        ),
                      ),
                      crossFadeState: showMarkerDetails ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: Duration(milliseconds: 250),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Search Bar ---
          Positioned( top: 8, left: 10, right: 10,
            child: Card( elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: TypeAheadField<Map<String, dynamic>>(
                debounceDuration: Duration(milliseconds: 400),
                textFieldConfiguration: TextFieldConfiguration( /* ... Decoration ... */
                  controller: searchController,
                  decoration: InputDecoration( hintText: "Search location...", prefixIcon: Icon(Icons.search, color: theme.hintColor, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 14.0),
                    suffixIcon: searchController.text.isNotEmpty ? IconButton( icon: Icon(Icons.clear, size: 20), tooltip: "Clear search",
                      onPressed: () { searchController.clear(); if (mounted) setState(() {}); FocusScope.of(context).unfocus(); }, ) : null, ),
                  onChanged: (value) { if (mounted) setState(() {}); },
                ),
                // Suggestions -> Call Logic
                suggestionsCallback: (pattern) async => await mf.fetchLocations(pattern, geoapifyApiKey),
                itemBuilder: (context, suggestion) => ListTile( /* ... UI ... */
                  leading: Icon(Icons.location_pin, size: 18, color: Colors.grey), title: Text(suggestion['name'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis), dense: true,
                ),
                // Selection -> Call Logic
                onSuggestionSelected: (suggestion) {
                  final location = suggestion['latlng'] as LatLng?; final name = suggestion['name'] as String?;
                  if (location != null) {
                    searchController.text = name ?? ''; FocusScope.of(context).unfocus();
                    mf.moveToLocation(mapController, location, 14.0); // Call logic
                    mf.handleMapTap( // Call logic
                      location: location, currentMarker1: marker1, currentMarker2: marker2,
                      setMarker1: (loc) => setState(() { marker1 = loc; _updateMarkerText(); }), setMarker2: (loc) => setState(() { marker2 = loc; _updateMarkerText(); }),
                      triggerWeatherFetch: _triggerWeatherFetch, triggerRouteFetch: _triggerRouteFetch, showInfoMessage: _showInfoSnackbar, );
                  } else { _showErrorSnackbar("Invalid location data."); }
                },
                loadingBuilder: (context) => Center(child: Padding(padding: const EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2))),
                noItemsFoundBuilder: (context) => Padding(padding: const EdgeInsets.all(12.0), child: Text('No locations found.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                errorBuilder: (context, error) => Padding(padding: const EdgeInsets.all(12.0), child: Text('Error fetching locations', textAlign: TextAlign.center, style: TextStyle(color: Colors.red))),
              ),
            ),
          ),
        ],
      ),
      // --- FABs ---
      floatingActionButton: Padding(
        // Adjust padding based on bottom sheet
        padding: EdgeInsets.only(bottom: routeAlternatives.isNotEmpty ? (MediaQuery.of(context).size.height * 0.35 + 20) : 20, right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton( // My Location
              heroTag: "currentLocation", tooltip: "Go to my current location",
              onPressed: _isLoadingLocation ? null : () async {
                setState(() => _isLoadingLocation = true);
                // Call Logic
                await mf.handleGetMyLocation(
                  currentMarker1: marker1, currentMarker2: marker2,
                  // Corrected callback: Wrap mf.moveToLocation
                  moveMapCallback: (loc, {targetZoom}) {
                    mf.moveToLocation(mapController, loc, targetZoom ?? zoomLevel);
                  },
                  setMarker1: (loc) => setState(() { marker1 = loc; _updateMarkerText(); }),
                  setMarker2: (loc) => setState(() { marker2 = loc; _updateMarkerText(); }),
                  triggerRouteFetch: _triggerRouteFetch,
                  showInfoMessage: _showInfoSnackbar,
                  showErrorMessage: _showErrorSnackbar,
                );
                if (mounted) setState(() => _isLoadingLocation = false);
              },
              child: _isLoadingLocation ? CircularProgressIndicator(color: colorScheme.onPrimary,) : Icon(Icons.my_location),
            ),
            SizedBox(height: 12),
            FloatingActionButton( // Zoom In
              heroTag: "zoomIn", mini: true, tooltip: "Zoom In",
              onPressed: () {
                // Use the min/max zoom values defined in MapOptions (e.g., 5.0 and 19.0)
                double currentZoom = mapController.camera.zoom;
                double nextZoom = (currentZoom + 1.0).clamp(5.0, 19.0); // Use actual values
                mf.moveToLocation(mapController, mapController.camera.center, nextZoom);
                setState(() => zoomLevel = nextZoom);
              },
              child: Icon(Icons.add),
            ),
            SizedBox(height: 8),
            FloatingActionButton( // Zoom Out
              heroTag: "zoomOut", mini: true, tooltip: "Zoom Out",
              onPressed: () {
                // Use the min/max zoom values defined in MapOptions (e.g., 5.0 and 19.0)
                double currentZoom = mapController.camera.zoom;
                // Correct typo 'clam$p' to 'clamp' and use actual min/max zoom values
                double nextZoom = (currentZoom - 1.0).clamp(5.0, 19.0);
                mf.moveToLocation(mapController, mapController.camera.center, nextZoom);
                setState(() => zoomLevel = nextZoom);
              },
              child: Icon(Icons.remove),
            ),
          ],
        ),
      ),
    );
  }
}