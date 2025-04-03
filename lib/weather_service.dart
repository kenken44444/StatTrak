import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WeatherData {
  final double temperature;
  final String description;
  final double lat;
  final double lon;

  WeatherData({
    required this.temperature,
    required this.description,
    required this.lat,
    required this.lon,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '',
      lat: (json['coord']['lat'] as num).toDouble(),
      lon: (json['coord']['lon'] as num).toDouble(),
    );
  }
}

class OneCallForecast {
  final double currentTemp;
  final String currentDescription;
  final List<DailyForecast> dailyForecasts;

  OneCallForecast({
    required this.currentTemp,
    required this.currentDescription,
    required this.dailyForecasts,
  });

  factory OneCallForecast.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    final daily = json['daily'] as List<dynamic>? ?? [];

    return OneCallForecast(
      currentTemp: (current['temp'] as num).toDouble(),
      currentDescription: current['weather'][0]['description'] ?? '',
      dailyForecasts: daily.map((dayJson) => DailyForecast.fromJson(dayJson)).toList(),
    );
  }
}

class DailyForecast {
  final double dayTemp;
  final double nightTemp;
  final String description;

  DailyForecast({
    required this.dayTemp,
    required this.nightTemp,
    required this.description,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    final temp = json['temp'];
    return DailyForecast(
      dayTemp: (temp['day'] as num).toDouble(),
      nightTemp: (temp['night'] as num).toDouble(),
      description: json['weather'][0]['description'] ?? '',
    );
  }
}

class WeatherService {

  static final String? _apiKey = '81a7e2e158c24c8339a1b849c9343fb5';

  static Future<WeatherData> fetchWeatherByLatLon({
    required double lat,
    required double lon,
  }) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
          '?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = jsonDecode(response.body);
      return WeatherData.fromJson(jsonBody);
    } else {
      throw Exception('Failed to fetch weather data (HTTP ${response.statusCode})');
    }
  }

  static Future<OneCallForecast> fetchDetailedForecast({
    required double lat,
    required double lon,
  }) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/onecall'
          '?lat=$lat&lon=$lon&exclude=minutely&units=metric&appid=$_apiKey',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final jsonBody = jsonDecode(response.body);
      return OneCallForecast.fromJson(jsonBody);
    } else {
      throw Exception('Failed to fetch detailed forecast (HTTP ${response.statusCode})');
    }
  }
}
