import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:stattrak/PostWidget.dart';
import 'package:stattrak/providers/post_provider.dart';
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/utils/responsive_layout.dart';
import 'package:stattrak/widgets/CreatePostWidget.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:stattrak/widgets/NotificationSidebar.dart';
import 'package:stattrak/widgets/GroupSidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SidebarType { none, notification, group }

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  SidebarType _activeSidebar = SidebarType.none;
  double? _latitude;
  double? _longitude;
  String? _avatarUrl;
  bool _isLoadingAvatar = true;

  @override
  void initState() {
    super.initState();
    _requestLocationAndFetchWeather();
    _fetchUserAvatar();

    Future.microtask(() {
      context.read<PostProvider>().fetchInitialPosts();
    });
  }

  Future<void> _fetchUserAvatar() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingAvatar = false); // Stop loading if no user
      return;
    }

    // Keep isLoadingAvatar true initially (already set in declaration)
    // setState(() => _isLoadingAvatar = true); // Not needed if initialized to true

    try {
      final response = await supabase
          .from('profiles')
          .select('avatar_url')
          .eq('id', user.id)
          .single();

      if (mounted) { // Check mounted after await
        setState(() {
          if (response != null && response['avatar_url'] != null) {
            _avatarUrl = response['avatar_url'] as String;
          }
          _isLoadingAvatar = false; // <-- Set to false after fetch attempt
        });
      }
    } catch (e) {
      debugPrint('Error fetching user avatar: $e');
      if (mounted) {
        setState(() {
          _isLoadingAvatar = false; // <-- Also set to false on error
        });
      }
    }
  }

  Future<void> _requestLocationAndFetchWeather() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });

    context.read<WeatherProvider>().fetchWeather(
      position.latitude,
      position.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyCustomAppBar(
        avatarUrl: _avatarUrl,
        isLoading: _isLoadingAvatar,
        onNotificationPressed: () {
          setState(() {
            _activeSidebar = (_activeSidebar == SidebarType.notification)
                ? SidebarType.none
                : SidebarType.notification;
          });
        },
        onGroupPressed: () {
          setState(() {
            _activeSidebar = (_activeSidebar == SidebarType.group)
                ? SidebarType.none
                : SidebarType.group;
          });
        },
      ),
      body: ResponsiveLayout(
        mobileLayout: _buildMobileLayout(),
        tabletLayout: _buildTabletLayout(),
        desktopLayout: _buildDesktopLayout(),
      ),
    );
  }

  // Desktop layout - side by side content and sidebar
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column (posts) takes up most of the width
        Expanded(
          child: _buildPostFeed(),
        ),
        // Right column (weather and sidebars) has a fixed width
        SizedBox(
          width: 300,
          child: _buildSidebarAndWeather(),
        ),
      ],
    );
  }

  // Tablet layout - similar to desktop but with different proportions
  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column (posts) takes up most of the width
        Expanded(
          flex: 2,
          child: _buildPostFeed(),
        ),
        // Right column (weather and sidebars)
        Expanded(
          flex: 1,
          child: _buildSidebarAndWeather(),
        ),
      ],
    );
  }

  // Mobile layout - stacked vertical design
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Posts feed takes most of the height
        Expanded(
          child: _buildPostFeed(),
        ),
        // Weather widget at the bottom with limited height
        SizedBox(
          height: 150, // Fixed height for weather on mobile
          width: double.infinity,
          child: _buildWeatherWidget(), // Only show weather, not the full sidebar
        ),
      ],
    );
  }

  // Extract the Post Feed Widget
  Widget _buildPostFeed() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CreatePostWidget(),
            const SizedBox(height: 16),
            Consumer<PostProvider>(
              builder: (context, postProvider, _) {
                final posts = postProvider.posts;

                if (postProvider.isLoading && posts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    ...posts.map((post) => PostWidget(post: post)).toList(),
                    if (postProvider.hasMore && !postProvider.isLoading)
                      ElevatedButton(
                        onPressed: () {
                          postProvider.loadMorePosts();
                        },
                        child: const Text("Load More"),
                      ),
                    if (postProvider.isLoading && posts.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Just the weather widget for mobile
  Widget _buildWeatherWidget() {
    final provider = context.watch<WeatherProvider>();

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(8),
      child: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
          ? Center(child: Text('Error: ${provider.error}'))
          : provider.weatherData != null
          ? Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wb_sunny, size: 32),
            const SizedBox(width: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weather for Today',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold
                  ),
                ),
                Text(
                  '${provider.weatherData!.temperature.toStringAsFixed(1)} °C',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ],
        ),
      )
          : const Center(child: Text('No weather data available')),
    );
  }

  // Full sidebar with weather for desktop/tablet
  Widget _buildSidebarAndWeather() {
    final provider = context.watch<WeatherProvider>();

    return Container(
      color: Colors.grey.shade100,
      height: double.infinity,
      child: Stack(
        children: [
          // Weather widget at the top
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: provider.isLoading
                ? const CircularProgressIndicator()
                : provider.error != null
                ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Text('Error: ${provider.error}'),
            )
                : provider.weatherData != null
                ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weather for Today',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny),
                      const SizedBox(width: 8),
                      Text(
                        '${provider.weatherData!.temperature.toStringAsFixed(1)} °C',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                ],
              ),
            )
                : Container(),
          ),
          // Sidebars
          if (_activeSidebar == SidebarType.notification)
            const Positioned(
              top: 120, // Place below weather widget
              left: 0,
              right: 0,
              bottom: 0,
              child: NotificationSidebar(),
            ),
          if (_activeSidebar == SidebarType.group)
            const Positioned(
              top: 120, // Place below weather widget
              left: 0,
              right: 0,
              bottom: 0,
              child: GroupSidebar(),
            ),
        ],
      ),
    );
  }
}