import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:stattrak/SharedLocationPage.dart';

/// Create a location link in the format "latlng:latitude,longitude"
String createLocationLink({required double latitude, required double longitude}) {
  return "latlng:$latitude,$longitude";
}

/// Share a location using the share_plus package
void shareLocation(double latitude, double longitude) {
  String link = createLocationLink(latitude: latitude, longitude: longitude);
  Share.share(link);
}

/// Navigate to the SharedRoutePage with a route ID
void navigateToSharedLocationPage(BuildContext context, String routeId) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => SharedRoutePage(routeId: routeId),
    ),
  );
}