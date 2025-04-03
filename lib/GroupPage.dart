import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/widgets/appbar.dart'; // Your custom MyCustomAppBar
import 'package:stattrak/providers/weather_provider.dart'; // Needed for weather widget
import 'package:stattrak/utils/responsive_layout.dart';
import 'package:geolocator/geolocator.dart'; // Import for location services

class GroupPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String groupImageUrl;

  const GroupPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupImageUrl,
  }) : super(key: key);

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  bool _isMember = false;
  bool _checkedAccess = false;
  final userId = Supabase.instance.client.auth.currentUser?.id;
  final TextEditingController _postController = TextEditingController();
  String? _avatarUrl;
  bool _isLoadingAvatar = true;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (userId != null) {
      _checkMembership();
      _loadUserProfile();
      _getCurrentLocation();
    } else {
      _checkedAccess = true;
      _isLoadingAvatar = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please log in to view groups."))
          );
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (userId == null) {
      if (mounted) setState(() => _isLoadingAvatar = false);
      return;
    }
    try {
      final result = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', userId!)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _avatarUrl = result?['avatar_url'];
          _isLoadingAvatar = false;
        });
      }
    } catch(e) {
      print("Error loading profile in GroupPage: $e");
      if(mounted) {
        setState(() => _isLoadingAvatar = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("Location services disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          debugPrint("Location permission denied.");
          return;
        }
      }
      if (permission == LocationPermission.deniedForever){
        debugPrint("Location permission permanently denied.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
      }
    } catch (e) {
      debugPrint("Error getting location for GroupPage AppBar: $e");
    }
  }

  Future<void> _checkMembership() async {
    if (userId == null) {
      // This case should ideally be handled by initState check, but added for safety
      _denyAccess("You must be logged in.");
      return;
    }
    try {
      // --- FIX Start ---
      // Select 'id' (or any column) and use maybeSingle to check existence.
      // Remove the FetchOptions argument.
      final result = await Supabase.instance.client
          .from('group_members')
          .select('id') // Select a column to check if a row exists
          .eq('group_id', widget.groupId)
          .eq('user_id', userId!)
          .maybeSingle(); // Returns the row map or null
      // --- FIX End ---

      if (!mounted) return;

      // --- FIX Start ---
      // Check if result is not null (meaning a row was found)
      if (result != null) {
        // --- FIX End ---
        setState(() {
          _isMember = true;
          _checkedAccess = true;
        });
      } else {
        _denyAccess("You are not a member of this group.");
      }

    } catch (e) {
      print("Error checking membership: $e");
      if(mounted) {
        _denyAccess("Error checking group membership.");
      }
    }
  }

  void _denyAccess(String message) {
    if (!mounted) return;
    setState(() {
      _isMember = false;
      _checkedAccess = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGroupPosts() async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select('''
            id, content, created_at, user_id,
            profiles:profiles!user_id(id, full_name, avatar_url, username),
            post_likes(user_id)
          ''')
          .eq('group_id', widget.groupId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print("Error fetching group posts: $e");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading posts.")));
      return [];
    }
  }

  Future<void> _createPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty || userId == null) return;

    try {
      await Supabase.instance.client.from('posts').insert({
        'user_id': userId,
        'group_id': widget.groupId,
        'content': content,
      });
      _postController.clear();
      setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to post: $e")));
    }
  }

  Future<void> _likePost(String postId) async {
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('post_likes').insert({
        'user_id': userId,
        'post_id': postId,
      });
      setState(() {});
    } catch (e) {
      print("Error liking post: $e");
      if (mounted && e is PostgrestException && e.code == '23505') {
        // Already liked
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error liking post.")));
      }
    }
  }

  Future<void> _unlikePost(String postId) async {
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('post_likes')
          .delete()
          .eq('user_id', userId!)
          .eq('post_id', postId);
      setState(() {});
    } catch (e) {
      print("Error unliking post: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error unliking post.")));
    }
  }

  void _toggleMembership() async {
    if (!_isMember || userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Group"),
        content: Text("Are you sure you want to leave '${widget.groupName}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Leave")),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('group_members')
            .delete()
            .eq('group_id', widget.groupId)
            .eq('user_id', userId!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the group.')),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAccess && userId != null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isMember) {
      return Scaffold(
        appBar: AppBar(title: Text("Access Denied")),
        body: const Center(child: Text("You are not a member of this group or not logged in.")),
      );
    }

    return Scaffold(
      appBar: MyCustomAppBar(
        onNotificationPressed: () {},
        onGroupPressed: () {},
        avatarUrl: _avatarUrl,
        isLoading: _isLoadingAvatar,
        lat: _latitude,
        long: _longitude,
      ),
      body: ResponsiveLayout(
        mobileLayout: _buildMobileLayout(),
        tabletLayout: _buildTabletLayout(),
        desktopLayout: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeftSidebar(),
        Expanded(child: _buildContentFeed()),
        _buildRightSidebar(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded( flex: 2, child: _buildContentFeed() ),
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildGroupInfoSection(),
                const SizedBox(height: 20),
                _buildWeatherWidget(),
                const SizedBox(height: 20),
                _buildMembersSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildContentFeed(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildMembersSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebar() {
    return Container(
      width: 250,
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: _buildGroupInfoSection(),
    );
  }

  Widget _buildRightSidebar() {
    return Container(
      width: 300,
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildWeatherWidget(),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildMembersSection(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupInfoSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: NetworkImage(widget.groupImageUrl),
          backgroundColor: Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          widget.groupName,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _toggleMembership,
          icon: const Icon(Icons.logout, size: 18),
          label: const Text("Leave Group"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.redAccent,
            elevation: 1,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.black12),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentFeed() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(widget.groupImageUrl),
                  fit: BoxFit.cover,
                ),
                color: Colors.grey[200],
              ),
            ),
            Positioned(
              top: 16, left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: "Back",
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_isMember) _buildPostCreationWidget(),

        const Divider(height: 32, indent: 16, endIndent: 16),

        _buildPostsFeed(),
      ],
    );
  }

  Widget _buildPostCreationWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _postController,
                decoration: const InputDecoration(
                  hintText: "Share something with the group...",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                maxLines: 3,
                minLines: 1,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _createPost,
                  child: const Text("Post"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsFeed() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchGroupPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding( padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(child: Text("Error loading posts: ${snapshot.error}")),
          );
        }
        final posts = snapshot.data;
        if (posts == null || posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20.0),
            child: Center(child: Text("No posts in this group yet.")),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final profileData = post['profiles'] as Map<String, dynamic>? ?? {};
            final likesList = post['post_likes'] as List<dynamic>? ?? [];

            final String fullName = profileData['full_name'] as String? ?? 'Unknown User';
            final String username = profileData['username'] as String? ?? '';
            final String avatarUrl = profileData['avatar_url'] as String? ?? '';
            final String postId = post['id'] as String? ?? '';
            final String content = post['content'] as String? ?? '';
            final String createdAtRaw = post['created_at'] as String? ?? '';
            final String postUserId = post['user_id'] as String? ?? '';

            String formattedTime = '';
            if (createdAtRaw.isNotEmpty) {
              try {
                final dt = DateTime.parse(createdAtRaw).toLocal();
                formattedTime = "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
              } catch (e) { formattedTime = 'Invalid date'; }
            }

            final bool hasLiked = likesList.any((like) => like is Map && like['user_id'] == userId);
            final int likeCount = likesList.length;

            return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage: (avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                        backgroundColor: Colors.grey[200],
                        child: (avatarUrl.isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Row(
                              children: [
                              Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (username.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: Text('@$username', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ),
                  Text(formattedTime, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(content),
                  const SizedBox(height: 8),
                  Row(
                      children: [
                  if (postUserId != userId && userId != null)
                  IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  iconSize: 20,
                  icon: Icon(
                    hasLiked ? Icons.favorite : Icons.favorite_border,
                    color: hasLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: postId.isEmpty ? null : () {
                    if (hasLiked) {
                      _unlikePost(postId);
                    } else {
                      _likePost(postId);
                    }
                  },
                )
                else if (userId == null)
            const Icon(Icons.favorite_border, color: Colors.grey, size: 20),
            const Icon(Icons.favorite, color: Colors.grey, size: 20),

            const SizedBox(width: 4),
            Text("$likeCount like${likeCount == 1 ? '' : 's'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            ),
            ],
            ),
            ),
            ],
            ),
            ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeatherWidget() {
    final weather = context.watch<WeatherProvider>();

    if (weather.isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (weather.error != null) {
      return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
          child: Text('Weather error: ${weather.error}', style: TextStyle(color: Colors.red[700]))
      );
    } else if (weather.weatherData != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text( "Weather Today", style: Theme.of(context).textTheme.titleMedium ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.orangeAccent),
                const SizedBox(width: 8),
                Text(
                  "${weather.weatherData!.temperature.toStringAsFixed(1)} °C",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      return const Text("Weather data unavailable.", style: TextStyle(color: Colors.grey));
    }
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("MEMBERS", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildMembersList(),
      ],
    );
  }

  Widget _buildMembersList() {
    return FutureBuilder<List<Member>>(
      future: _fetchGroupMembers(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: Text("Error loading members: ${snapshot.error}")),
          );
        }
        final members = snapshot.data;
        if (members == null || members.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: Text("No members found in this group.")),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: NetworkImage(member.avatarUrl),
                backgroundColor: Colors.grey[200],
              ),
              title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(member.role),
            );
          },
        );
      },
    );
  }
}

class Member {
  final String fullName;
  final String avatarUrl;
  final String role;
  final String username;

  Member({
    required this.fullName,
    required this.avatarUrl,
    required this.role,
    required this.username,
  });
}

Future<List<Member>> _fetchGroupMembers(String groupId) async {
  try{
    final response = await Supabase.instance.client
        .from('group_members')
        .select('role, profiles!inner(id, full_name, avatar_url, username)')
        .eq('group_id', groupId);

    final data = response as List;

    return data.map((item) {
      final profileData = item['profiles'] as Map<String, dynamic>? ?? {};
      final String avatar = profileData['avatar_url'] as String? ?? 'https://via.placeholder.com/80';

      return Member(
        fullName: profileData['full_name'] as String? ?? 'Unknown Member',
        avatarUrl: avatar.isNotEmpty ? avatar : 'https://via.placeholder.com/80',
        role: item['role'] as String? ?? 'Member',
        username: profileData['username'] as String? ?? '',
      );
    }).toList();
  } catch (e) {
    print("Error fetching group members: $e");
    return [];
  }
}