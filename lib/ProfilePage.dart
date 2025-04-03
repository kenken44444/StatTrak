import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stattrak/EditProfilePage.dart';
import 'package:stattrak/login_page.dart';
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/widgets/appbar.dart';
import 'package:stattrak/youtube_player_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';


class ProfilePage extends StatefulWidget {
  final String? userId;
  final double? initialLat;
  final double? initialLong;

  const ProfilePage({
    Key? key,
    this.userId,
    this.initialLat,
    this.initialLong,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _bioController = TextEditingController();
  final _youtubeLink1Controller = TextEditingController();
  final _youtubeLink2Controller = TextEditingController();
  final _youtubeLink3Controller = TextEditingController();

  bool _isLoading = true;
  String? _friendshipStatus;
  double? _latitude;
  double? _longitude;
  List<Map<String, dynamic>> _userPosts = [];
  List<String> _featuredPhotos = [];

  final int _maxFeaturedPhotos = 4;

  bool get _isOwnProfile {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return widget.userId == null || widget.userId == currentUser?.id;
  }

  String get _targetUserId {
    return widget.userId ?? Supabase.instance.client.auth.currentUser!.id;
  }


  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLat;
    _longitude = widget.initialLong;

    _initData();

    if (_latitude != null && _longitude != null) {
      Future.microtask(() {
        if (mounted) {
          context.read<WeatherProvider>().fetchWeather(_latitude!, _longitude!);
        }
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _avatarUrlController.dispose();
    _bioController.dispose();
    _youtubeLink1Controller.dispose();
    _youtubeLink2Controller.dispose();
    _youtubeLink3Controller.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchProfile(),
        _fetchUserPosts(),
        if (!_isOwnProfile) _checkFriendshipStatus(),
      ]);
    } catch (e) {
      debugPrint("Error initializing profile data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading profile data: $e"))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProfile() async {
    final supabase = Supabase.instance.client;
    final targetUserId = _targetUserId;

    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', targetUserId)
          .single();

      if (mounted) {
        _usernameController.text = row['username'] ?? '';
        _fullNameController.text = row['full_name'] ?? '';
        _avatarUrlController.text = row['avatar_url'] ?? '';
        _bioController.text = row['bio'] ?? '';
        _latitude = row['lat'] as double?;
        _longitude = row['long'] as double?;
        _youtubeLink1Controller.text = row['youtube_link1'] ?? '';
        _youtubeLink2Controller.text = row['youtube_link2'] ?? '';
        _youtubeLink3Controller.text = row['youtube_link3'] ?? '';

        final featuredPhotosData = row['featured_photos'];
        if (featuredPhotosData != null && featuredPhotosData is List) {
          _featuredPhotos = List<String>.from(featuredPhotosData.whereType<String>());
        } else {
          _featuredPhotos = [];
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile for $targetUserId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not load profile: ${e is PostgrestException ? e.message : e.toString()}"))
        );
      }
    }
  }

  Future<void> _fetchUserPosts() async {
    final supabase = Supabase.instance.client;
    final targetUserId = _targetUserId;

    try {
      final response = await supabase
          .from('posts')
          .select('''
            id, content, photos, created_at, user_id,
            profiles:profiles!user_id(id, full_name, avatar_url, username),
            post_likes(user_id)
          ''')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _userPosts = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('Error fetching user posts for $targetUserId: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not load posts."))
        );
      }
    }
  }

  Future<void> _likePost(String postId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || postId.isEmpty) return;

    try {
      await Supabase.instance.client.from('post_likes').insert({
        'user_id': currentUser.id,
        'post_id': postId,
      });
      await _fetchUserPosts();
    } catch (e) {
      if (e is PostgrestException && e.code == '23505') {
        debugPrint("Post $postId already liked by ${currentUser.id}");
      } else {
        debugPrint("Error liking post $postId: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to like post")));
      }
    }
  }

  Future<void> _unlikePost(String postId) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null || postId.isEmpty) return;

    try {
      await Supabase.instance.client
          .from('post_likes')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('post_id', postId);
      await _fetchUserPosts();
    } catch (e) {
      debugPrint("Error unliking post $postId: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to unlike post")));
    }
  }

  Future<void> _checkFriendshipStatus() async {
    if (_isOwnProfile) return;

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final targetUserId = widget.userId;

    if (currentUser == null || targetUserId == null) {
      setState(() => _friendshipStatus = 'none');
      return;
    }

    try {
      final result = await supabase
          .from('user_friendships')
          .select('status')
          .or('and(user_id.eq.${currentUser.id},friend_id.eq.$targetUserId),and(user_id.eq.$targetUserId,friend_id.eq.${currentUser.id})')
          .maybeSingle();

      if (mounted) {
        setState(() {
          _friendshipStatus = result?['status'] ?? 'none';
        });
      }
    } catch (e) {
      debugPrint('Error checking friendship status: $e');
      if (mounted) setState(() => _friendshipStatus = 'none');
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isOwnProfile || _friendshipStatus != 'none') return;

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    final targetUserId = widget.userId;

    if (currentUser == null || targetUserId == null) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from('user_friendships').insert({
        'user_id': currentUser.id,
        'friend_id': targetUserId,
        'status': 'pending',
      });

      if (mounted) {
        setState(() {
          _friendshipStatus = 'pending';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
      }
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending request: ${e is PostgrestException ? e.message : e}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditProfileDialog() async {
    if (!_isOwnProfile) return;

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          avatarUrl: _avatarUrlController.text,
          username: _usernameController.text,
          fullName: _fullNameController.text,
          bio: _bioController.text,
          youtubeLink1: _youtubeLink1Controller.text,
          youtubeLink2: _youtubeLink2Controller.text,
          youtubeLink3: _youtubeLink3Controller.text,
          featuredPhotos: List<String>.from(_featuredPhotos),
          latitude: _latitude,
          longitude: _longitude,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _avatarUrlController.text = result['avatar_url'] ?? _avatarUrlController.text;
        _usernameController.text = result['username'] ?? _usernameController.text;
        _fullNameController.text = result['full_name'] ?? _fullNameController.text;
        _bioController.text = result['bio'] ?? _bioController.text;
        _youtubeLink1Controller.text = result['youtube_link1'] ?? _youtubeLink1Controller.text;
        _youtubeLink2Controller.text = result['youtube_link2'] ?? _youtubeLink2Controller.text;
        _youtubeLink3Controller.text = result['youtube_link3'] ?? _youtubeLink3Controller.text;
        _latitude = result['latitude'] as double? ?? _latitude;
        _longitude = result['longitude'] as double? ?? _longitude;

        if (result['featured_photos'] != null && result['featured_photos'] is List) {
          _featuredPhotos = List<String>.from(result['featured_photos']);
        }
      });
    }
  }

  Future<void> _launchYouTubeUrl(String url) async {
    if (url.isEmpty) return;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final Uri? uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint("Could not launch $url: $e");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch URL: $url')));
      }
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid or unlaunchable URL: $url')));
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: MyCustomAppBar(
        onGroupPressed: () {},
        onNotificationPressed: () {},
        lat: _latitude,
        long: _longitude,
        avatarUrl: _avatarUrlController.text,
        isLoading: _isLoading,
      ),
      body: _isLoading && _userPosts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (screenWidth > 800) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: _buildProfileInfoColumn(),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: _buildPostsColumn(),
        ),
        const SizedBox(width: 24),
        SizedBox(
          width: 250,
          child: _buildWeatherColumn(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileInfoColumn(),
        const SizedBox(height: 24),
        _buildWeatherColumn(),
        const SizedBox(height: 24),
        _buildPostsColumn(),
      ],
    );
  }


  Widget _buildProfileInfoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isOwnProfile ? _showEditProfileDialog : null,
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey.shade300,
            backgroundImage: (_avatarUrlController.text.isNotEmpty)
                ? NetworkImage(_avatarUrlController.text)
                : null,
            child: (_avatarUrlController.text.isEmpty)
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _fullNameController.text.isNotEmpty ? _fullNameController.text : 'User',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (_usernameController.text.isNotEmpty)
          Text(
            '@${_usernameController.text}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 16),

        if (_isOwnProfile) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.edit, size: 18, color: Colors.blue,),
            label: const Text('Edit Profile', style: TextStyle(color: Colors.blue,)),
            onPressed: _showEditProfileDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, // Background color
              foregroundColor: Colors.white, // Text and icon color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Colors.blue,  // Border color
                  width: 1,  // Border width
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 18, color: Colors.red),
            label: const Text('Logout', style: TextStyle(color: Colors.red)),
            onPressed: _logout,
            style: TextButton.styleFrom(minimumSize: const Size(150, 36)),
          ),
        ] else if (_friendshipStatus != null) ...[
          ElevatedButton.icon(
            icon: Icon( _friendshipStatus == 'accepted' ? Icons.person_remove_outlined
                : _friendshipStatus == 'pending' ? Icons.hourglass_top_outlined
                : Icons.person_add_alt_1, size: 18),
            label: Text(
              _friendshipStatus == 'accepted' ? 'Friends'
                  : _friendshipStatus == 'pending' ? 'Request Sent'
                  : 'Add Friend',
            ),
            onPressed: _friendshipStatus == 'none' ? _sendFriendRequest : null,
            style: ElevatedButton.styleFrom(minimumSize: const Size(150, 36)),
          ),
        ] else ... [
          const SizedBox(height: 36, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
        ],

        const SizedBox(height: 24),

        if (_bioController.text.isNotEmpty) ...[
          const Divider(),
          const SizedBox(height: 8),
          Text(
            _bioController.text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          const Divider(),
        ],

        if (_featuredPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Featured Photos', style: Theme.of(context).textTheme.titleMedium)
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredPhotos.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _featuredPhotos[index],
                      width: 100,
                      height: 120,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress == null ? child : Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null)),
                      errorBuilder: (context, error, stackTrace) => Container(width: 100, height: 120, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        if (_youtubeLink1Controller.text.isNotEmpty ||
            _youtubeLink2Controller.text.isNotEmpty ||
            _youtubeLink3Controller.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('Featured Videos', style: Theme.of(context).textTheme.titleMedium)
          ),
          const SizedBox(height: 8),
          if (_youtubeLink1Controller.text.isNotEmpty)
            _buildVideoCard(_youtubeLink1Controller.text),
          if (_youtubeLink2Controller.text.isNotEmpty)
            _buildVideoCard(_youtubeLink2Controller.text),
          if (_youtubeLink3Controller.text.isNotEmpty)
            _buildVideoCard(_youtubeLink3Controller.text),
        ],
      ],
    );
  }


  Widget _buildPostsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('User Posts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_userPosts.isEmpty && !_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(child: Text('This user hasn\'t posted anything yet.')),
          )
        else if (_userPosts.isEmpty && _isLoading)
          const Center(child: CircularProgressIndicator())
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _userPosts.length,
            itemBuilder: (context, index) {
              final post = _userPosts[index];
              final dynamic photosData = post['photos'];
              final List<String> photos = (photosData is List) ? List<String>.from(photosData.whereType<String>()) : [];
              final String content = post['content'] as String? ?? '';
              final String createdAtRaw = post['created_at'] as String? ?? '';
              final String postId = post['id'] as String? ?? '';
              final List<dynamic> likes = post['post_likes'] as List<dynamic>? ?? [];
              final String postUserId = post['user_id'] as String? ?? '';

              String formattedTime = 'Unknown date';
              if (createdAtRaw.isNotEmpty) {
                try {
                  final dt = DateTime.parse(createdAtRaw).toLocal();
                  formattedTime = "${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
                } catch (_) {}
              }

              final bool hasLiked = Supabase.instance.client.auth.currentUser != null
                  ? likes.any((like) => like is Map && like['user_id'] == Supabase.instance.client.auth.currentUser!.id)
                  : false;
              final int likeCount = likes.length;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (content.isNotEmpty) ...[
                        Text(content),
                        const SizedBox(height: 8),
                      ],
                      if (photos.isNotEmpty) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: photos.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: (MediaQuery.of(context).size.width > 600) ? 3 : 2,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childAspectRatio: 1.0,
                          ),
                          itemBuilder: (context, photoIndex) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                photos[photoIndex],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.error_outline)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(formattedTime, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                          Row(
                            children: [
                              IconButton(
                                iconSize: 20,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  hasLiked ? Icons.favorite : Icons.favorite_border,
                                  color: (postUserId == Supabase.instance.client.auth.currentUser?.id || Supabase.instance.client.auth.currentUser == null)
                                      ? Colors.grey
                                      : (hasLiked ? Colors.red : Colors.grey),
                                ),
                                onPressed: (postUserId == Supabase.instance.client.auth.currentUser?.id || Supabase.instance.client.auth.currentUser == null || postId.isEmpty)
                                    ? null
                                    : () {
                                  if (hasLiked) { _unlikePost(postId); }
                                  else { _likePost(postId); }
                                },
                              ),
                              const SizedBox(width: 4),
                              Text("$likeCount", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildWeatherColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weather', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Consumer<WeatherProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (provider.error != null) {
              return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Text('Weather error: ${provider.error}', style: TextStyle(color: Colors.red[700]))
              );
            } else if (provider.weatherData != null) {
              final weather = provider.weatherData!;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.blue.shade50,
                ),
                child: Row(
                  children: [
                    Icon(Icons.wb_sunny, size: 32, color: Colors.orangeAccent),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${weather.temperature.toStringAsFixed(1)}°C', style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                  ],
                ),
              );
            } else {
              return const Text('Weather data unavailable. Ensure location is enabled.');
            }
          },
        ),
      ],
    );
  }

  Widget _buildVideoCard(String url) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: YouTubeVideoPlayer(url: url),
    );
  }

  Future<void> _pickAndUploadFeaturedPhoto() async {
    if (_featuredPhotos.length >= _maxFeaturedPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxFeaturedPhotos featured photos allowed')),
      );
      return;
    }
    await _uploadPhoto(isAvatar: false);
  }

  Future<void> _pickAndUploadAvatar() async {
    await _uploadPhoto(isAvatar: true);
  }

  Future<void> _uploadPhoto({required bool isAvatar}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final fileBytes = await pickedFile.readAsBytes();
      final String fileExt = pickedFile.path.split('.').last;
      final String fileName = '${isAvatar ? 'avatar' : 'featured'}_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final String bucket = isAvatar ? 'avatar-url' : 'featured-photos';

      await supabase.storage.from(bucket).uploadBinary(
        fileName,
        fileBytes,
        fileOptions: FileOptions(cacheControl: '3600', upsert: isAvatar),
      );

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(fileName);

      if (isAvatar) {
        await supabase.from('profiles')
            .update({'avatar_url': publicUrl, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', user.id);
        if (mounted) setState(() => _avatarUrlController.text = publicUrl);
      } else {
        if (mounted) setState(() => _featuredPhotos.add(publicUrl));
        await supabase.from('profiles')
            .update({'featured_photos': _featuredPhotos, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', user.id);
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo uploaded successfully!')));

    } catch (e) {
      debugPrint('Error uploading photo: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error uploading photo: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage()),
            (route) => false,
      );
    } catch(e) {
      debugPrint("Logout error: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Logout failed: $e")));
    }
  }

}