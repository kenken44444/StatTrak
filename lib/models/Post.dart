class Post {
  final String username;
  final DateTime date;
  final String location;
  final String title;
  final double distance;
  final double elevation;
  final List<String> imageUrls;
  final int likes;

  Post({
    required this.username,
    required this.date,
    required this.location,
    required this.title,
    required this.distance,
    required this.elevation,
    required this.imageUrls,
    required this.likes,
  });
}
