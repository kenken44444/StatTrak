import 'dart:convert';
import 'package:http/http.dart' as http;

class SmsService {
  static const String _apiKey = 'efced85d8b2a04051fd1075c7c989dc0';
  static const String _baseUrl = 'https://cors-anywhere.herokuapp.com/https://api.semaphore.co/api/v4/messages';
  static const String _senderName = 'StaTrak';

  static Future<void> sendSms({
    required String number,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'apikey': _apiKey,
        'number': number,
        'message': message,
        'sendername': _senderName,
      }),
    );

    if (response.statusCode == 200) {
      print("✅ SMS sent to $number");
    } else {
      print("❌ SMS failed: ${response.body}");
    }
  }

  static String locationShareMessage(String username, double lat, double lng) {
    return "$username just shared their live location: https://maps.google.com/?q=$lat,$lng";
  }

  static String routeCompletedMessage(String username, String routeName) {
    return "$username has completed the route: $routeName!";
  }

  static String routeDetourMessage(String username, String routeName) {
    return "⚠️ $username may have detoured from the route: $routeName. Check their location.";
  }
}
