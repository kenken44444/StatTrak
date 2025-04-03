import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../weather_service.dart';

class WeatherProvider with ChangeNotifier {
  WeatherData? _weatherData;
  WeatherData? get weatherData => _weatherData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  LatLng? _marker1;
  LatLng? get marker1 => _marker1;

  void updateMarker1(LatLng marker) {
    _marker1 = marker;
    notifyListeners();
    fetchWeather(marker.latitude, marker.longitude);
  }

  Future<void> fetchWeather(double lat, double lon) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final data = await WeatherService.fetchWeatherByLatLon(
        lat: lat,
        lon: lon,
      );
      _weatherData = data;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
