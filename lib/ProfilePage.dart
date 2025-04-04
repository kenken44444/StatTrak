import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stattrak/providers/weather_provider.dart';
import 'package:stattrak/youtube_player_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/EditProfilePage.dart';


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
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _youtubeLink1Controller = TextEditingController();
  final TextEditingController _youtubeLink2Controller = TextEditingController();
  final TextEditingController _youtubeLink3Controller = TextEditingController();
  List<String> _featuredPhotos = [];
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  String _username = "Full name";
  String _avatarUrl = "";
  int _following = 2;
  int _activities = 1;
  List<Map<String, dynamic>> _suggestedFriends = [];
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _groups = [];
  double? _latitude;
  double? _longitude;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool get _isOwnProfile => widget.userId == null || widget.userId == Supabase.instance.client.auth.currentUser?.id;
  String get _targetUserId => widget.userId ?? Supabase.instance.client.auth.currentUser!.id;
  final GlobalKey _searchBoxKey = GlobalKey();

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


  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _fetchProfile(),
        _fetchPosts(),
        _fetchGroups(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error loading data: $e")));
      }
    } finally {
      if (mounted) {
        if (!_isOwnProfile) {
          _loadDummyDataIfNeeded();
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchProfile() async {
    final supabase = Supabase.instance.client;
    final profileUserId = _targetUserId;

    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', profileUserId)
          .single();

      if (mounted) {
        setState(() {
          _username = row['full_name'] ?? 'Full name';
          _avatarUrl = row['avatar_url'] ?? '';
          _latitude = row['lat'] as double?;
          _longitude = row['long'] as double?;
          _youtubeLink1Controller.text = row['youtube_link1'] ?? '';
          _youtubeLink2Controller.text = row['youtube_link2'] ?? '';
          _youtubeLink3Controller.text = row['youtube_link3'] ?? '';
        });

        if (!_isOwnProfile && _latitude != null && _longitude != null) {
          context.read<WeatherProvider>().fetchWeather(_latitude!, _longitude!);
        } else if (_isOwnProfile && _latitude != null && _longitude != null) {
          context.read<WeatherProvider>().fetchWeather(_latitude!, _longitude!);
        }

      }
    } catch (e) {
      if(mounted){
        print("Error fetching profile for $profileUserId: $e");
        setState(() {
          _username = "User not found";
          _avatarUrl = "";
        });
      }
    }
  }

  Future<void> _fetchFriendCount() async {
    final supabase = Supabase.instance.client;
    final userId = _targetUserId;

    try {
      final result = await supabase
          .from('user_friendships')
          .select()
          .or('and(user_id.eq.$userId,status.eq.accepted),and(friend_id.eq.$userId,status.eq.accepted)');

      if (mounted) {
        setState(() {
          _following = result.length;
        });
      }
    } catch (e) {
      print("Error fetching friends: $e");
    }
  }

  Future<void> _fetchPosts() async {
    final supabase = Supabase.instance.client;
    final profileUserId = _targetUserId;

    try {
      final response = await supabase
          .from('posts')
          .select('''
            id, content, photos, created_at, user_id, distance, time,
            profiles:profiles!user_id(id, full_name, avatar_url, username),
            post_likes(user_id)
          ''')
          .eq('user_id', profileUserId)
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(response as List);
          _activities = _posts.length;
        });
      }
    } catch (e) {
      if(mounted){
        print("Error fetching posts for $profileUserId: $e");
      }
    }
  }

  Future<void> _fetchGroups() async {
    final userId = _targetUserId;
    if (userId.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('group_members')
          .select('groups!inner(id, name, group_image)')
          .eq('user_id', userId);


      if (mounted) {
        final List<Map<String, dynamic>> fetchedGroups = (response as List).map((item) {
          final groupData = item['groups'] as Map<String, dynamic>? ?? {};
          return {
            'id': groupData['id'] ?? '',
            'name': groupData['name'] ?? 'Unknown Group',
            'avatar': groupData['group_image'] ?? '',
          };
        }).toList();

        setState(() {
          _groups = fetchedGroups;
        });
      }
    } catch (e) {
      if (mounted) {
        print("Error fetching groups for $userId: $e");
      }
    }
  }

  void _loadDummyDataIfNeeded() {
    if (!_isOwnProfile) {
      if (_suggestedFriends.isEmpty) {
        _suggestedFriends = List.generate(
            6, (index) => {'name': 'Friend Name ${index + 1}', 'avatar': ''});
      }

      if (_groups.isEmpty) {
        _groups = List.generate(3, (index) => {
          'id': 'dummy_group_${index + 1}',
          'name': 'Dummy Group ${index + 1}',
          'avatar': ''
        });
      }

      if (_posts.isEmpty) {
        _posts = [
          {
            'id': 'dummy_post_1',
            'content': 'Dummy Post: Ride to heaven',
            'created_at': DateTime.now().subtract(Duration(days: 1)).toIso8601String(),
            'profiles': {'full_name': 'Dummy User', 'avatar_url': ''},
            'distance': 36.85,
            'time': '2h 50m',
            'post_likes': [],
            'photos': [],
            'map_image': 'assets/sample_map.png',
          },
        ];
      }
    }
  }

  String _formatDate(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      String timeStr = "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
      String dateStr = "";

      if (difference.inDays == 0 && now.day == dateTime.day) {
        dateStr = "Today at $timeStr";
      } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != dateTime.day)) {
        dateStr = "Yesterday at $timeStr";
      } else {
        dateStr = "${dateTime.month}/${dateTime.day}/${dateTime.year} at $timeStr";
      }
      return '$dateStr · Location Placeholder';
    } catch (_) {
      return 'Date unknown · Location unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(70),
            child: Container(
              color: const Color(0xFF1c4966),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SafeArea(
                child: Row(
                  children: [
                    Image.asset('assets/icons/Stattrak_Logo.png', height: 30),
                    const SizedBox(width: 24),
                    Text('Home', style: TextStyle(color: Colors.cyanAccent[100], fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    const Text('Maps', style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildSearchBox()),
                    const SizedBox(width: 24),
                    IconButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                      },
                      icon: const Icon(Icons.power_settings_new),
                      color: Colors.cyanAccent[100],
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: !_isLoading
              ? _buildBody()
              : const Center(child: CircularProgressIndicator()),
        ),

        if (_isSearching && _searchResults.isNotEmpty)
          Positioned(
            top: _getSearchBoxRect().bottom + 4,
            left: _getSearchBoxRect().left,
            width: _getSearchBoxRect().width,
            child: _buildSearchDropdown(),
          ),
      ],
    );
  }

  Rect _getSearchBoxRect() {
    final renderBox = _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    }
    return Rect.zero;
  }

  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    final supabase = Supabase.instance.client;
    setState(() => _isSearching = true);

    final userResults = await supabase
        .from('profiles')
        .select('id, full_name, username, avatar_url')
        .or('full_name.ilike.%$query%,username.ilike.%$query%');

    final groupResults = await supabase
        .from('groups')
        .select('id, name, group_image')
        .ilike('name', '%$query%');

    setState(() {
      _searchResults = [
        ...List<Map<String, dynamic>>.from(userResults).map((e) => {...e, 'type': 'user'}),
        ...List<Map<String, dynamic>>.from(groupResults).map((e) => {...e, 'type': 'group'}),
      ];
    });
  }

  Offset _getSearchBoxOffset() {
    final renderBox = _searchBoxKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.localToGlobal(Offset.zero);
    }
    return Offset.zero;
  }

  Widget _buildSearchBox() {
    return Container(
      key: _searchBoxKey, //
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search for friend/group',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchDropdown() {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        constraints: const BoxConstraints(maxHeight: 300),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final item = _searchResults[index];
            final isUser = item['type'] == 'user';
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (item['avatar_url'] ?? item['group_image'])?.toString().isNotEmpty == true
                    ? NetworkImage(item['avatar_url'] ?? item['group_image'])
                    : null,
                child: (item['avatar_url'] ?? item['group_image']) == null
                    ? Icon(isUser ? Icons.person : Icons.group)
                    : null,
              ),
              title: Text(isUser ? item['full_name'] ?? 'N/A' : item['name'] ?? 'Group'),
              subtitle: Text(isUser ? '@${item['username']}' : 'Group'),
              onTap: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                });

                if (isUser) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: item['id'])));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => GroupPage(
                    groupId: item['id'],
                    groupName: item['name'],
                    groupImageUrl: item['group_image'] ?? '',
                  )));
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _showEditProfileDialog() async {
    if (!_isOwnProfile) return;

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          avatarUrl: _avatarUrl,
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
        _avatarUrl = result['avatar_url'] ?? _avatarUrl;
        _usernameController.text = result['username'] ?? _usernameController.text;
        _fullNameController.text = result['full_name'] ?? _fullNameController.text;
        _bioController.text = result['bio'] ?? _bioController.text;
        _youtubeLink1Controller.text = result['youtube_link1'] ?? _youtubeLink1Controller.text;
        _youtubeLink2Controller.text = result['youtube_link2'] ?? _youtubeLink2Controller.text;
        _youtubeLink3Controller.text = result['youtube_link3'] ?? _youtubeLink3Controller.text;
        _latitude = result['latitude'] ?? _latitude;
        _longitude = result['longitude'] ?? _longitude;
        if (result['featured_photos'] is List) {
          _featuredPhotos = List<String>.from(result['featured_photos']);
        }
      });
    }
  }

  Widget _buildBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildLeftSidebarContent(),
            ),
          ),
        ),

        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey[100],
            margin: const EdgeInsets.symmetric(horizontal: 1),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildCenterContent(),
            ),
          ),
        ),

        if (_isOwnProfile)
          Expanded(
            flex: 1,
            child: Container(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "Weather Today",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 8),
                    _buildWeatherWidget(),
                    const SizedBox(height: 24),

                    Text(
                        'Groups',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.group_add),
                        label: const Text('Create Group'),
                        onPressed: () { },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            minimumSize: Size(150, 36)
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_groups.isEmpty && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0),
                        child: Center(child: Text("You haven't joined any groups yet.")),
                      )
                    else if (_groups.isEmpty && _isLoading)
                      Center(child: CircularProgressIndicator())
                    else
                      ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _groups.length,
                          itemBuilder: (context, index) {
                            final group = _groups[index];
                            return _buildGroupListItem(group);
                          }
                      ),


                    const SizedBox(height: 24),

                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Powered by Supabase © Macrotech™',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLeftSidebarContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isOwnProfile ? _showEditProfileDialog : null,
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Colors.grey[300],
            backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
            child: _avatarUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
          ),
        ),
        if (_isOwnProfile)
          TextButton.icon(
            icon: Icon(Icons.edit, color: Colors.blue),
            label: Text('Edit Profile', style: TextStyle(color: Colors.blue)),
            onPressed: _showEditProfileDialog,
          ),
        const SizedBox(height: 16),
        Text(_username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatColumn('Friends', _following.toString()),
            Container(height: 30, width: 1, color: Colors.grey[300]),
            _buildStatColumn('Activities', _activities.toString()),
          ],
        ),
        const Divider(height: 32),
        Align(alignment: Alignment.centerLeft, child: Text('Latest Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Text('Yesterday at 1:50 PM · Mendez, Cavite', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const Divider(height: 32),
        Align(alignment: Alignment.centerLeft, child: Text('Tutorial Video for Beginners', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        if (_youtubeLink1Controller.text.isNotEmpty)
          _buildVideoCard(_youtubeLink1Controller.text),
        if (_youtubeLink2Controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildVideoCard(_youtubeLink2Controller.text),
          ),
        if (_youtubeLink3Controller.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildVideoCard(_youtubeLink3Controller.text),
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

  Widget _buildCenterContent() {
    return Column(
      children: [
        if (_isOwnProfile) ...[
          _buildPostCreationBox(),
          const SizedBox(height: 24),
        ],
        if (_posts.isEmpty && !_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Text( _isOwnProfile ? "You haven't posted anything yet." : "This user hasn't posted anything yet."),
          )
        else
          ..._posts.map((post) => _buildPostItem(post)).toList(),
      ],
    );
  }

  Widget _buildPostCreationBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Column(
        children: [
          TextField( controller: _postController, decoration: const InputDecoration(hintText: "What's new...?", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)), maxLines: 3, minLines: 1,),
          const SizedBox(height: 16),
          Row( mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon( icon: const Icon(Icons.add_photo_alternate), label: const Text('Add Photos'), onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, side: const BorderSide(color: Colors.grey)),),
              ElevatedButton( onPressed: () { }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('Post'),),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildWeatherWidget() {
    final weather = context.watch<WeatherProvider>();

    if (weather.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (weather.error != null) {
      return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
          child: Text('Weather error: ${weather.error}', style: TextStyle(color: Colors.red[700], fontSize: 12))
      );
    } else if (weather.weatherData != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${weather.weatherData!.temperature.toStringAsFixed(1)} °C",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return const Text("Weather data unavailable.", style: TextStyle(color: Colors.grey));
    }
  }



  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }


  Widget _buildPostItem(Map<String, dynamic> post) {
    final String name = post['profiles']?['full_name'] ?? 'Unknown User';
    final String avatar = post['profiles']?['avatar_url'] ?? '';
    final String content = post['content'] ?? '';
    final String date = post['created_at'] != null ? _formatDate(post['created_at']) : 'Date Unknown';
    final List likesList = post['post_likes'] is List ? post['post_likes'] : [];
    final int likes = likesList.length;
    final bool hasLiked = Supabase.instance.client.auth.currentUser != null ? likesList.any((like) => like is Map && like['user_id'] == Supabase.instance.client.auth.currentUser!.id) : false;
    final List<String> photos = post['photos'] is List ? List<String>.from(post['photos']) : [];
    final String? mapImage = post['map_image'];
    final String distance = post['distance'] != null ? '${post['distance']} km' : '';
    final String time = post['time'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar( backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null, child: avatar.isEmpty ? const Icon(Icons.person) : null, ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(date, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          if (content.isNotEmpty)
            Padding( padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text(content, style: const TextStyle(fontSize: 16)), ),
          if(distance.isNotEmpty || time.isNotEmpty)
            Padding( padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  if (distance.isNotEmpty) Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Distance', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(distance, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))],),),
                  if (distance.isNotEmpty && time.isNotEmpty) const SizedBox(width: 16),
                  if (time.isNotEmpty) Expanded( child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Time', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)) ],),),
                ],
              ),
            ),
          if (mapImage != null && mapImage.isNotEmpty)
            mapImage.startsWith('http')
                ? Image.network(mapImage, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[200], child: Center(child: Icon(Icons.error))) )
                : Image.asset(mapImage, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 200, color: Colors.grey[200], child: Center(child: Text("Error loading asset"))) ),
          Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                IconButton( icon: Icon(hasLiked ? Icons.favorite : Icons.favorite_border), color: hasLiked ? Colors.red : Colors.grey, iconSize: 20, constraints: BoxConstraints(), padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  onPressed: () {
                    final postId = post['id'] as String?;
                    if (postId != null && Supabase.instance.client.auth.currentUser != null) { print("Like toggle for $postId"); }
                  },
                ),
                Text('$likes', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildGroupListItem(Map<String, dynamic> group) {
    final String groupName = group['name'] ?? 'Unknown Group';
    final String groupAvatar = group['avatar'] ?? '';
    final String groupId = group['id'] ?? '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundImage: (groupAvatar.isNotEmpty && groupAvatar.startsWith('http'))
            ? NetworkImage(groupAvatar)
            : null,
        backgroundColor: Colors.grey[200],
        child: (groupAvatar.isEmpty || !groupAvatar.startsWith('http'))
            ? const Icon(Icons.group, size: 20)
            : null,
      ),
      title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: ElevatedButton(
        onPressed: () {
          if (groupId.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(builder: (_) =>
                GroupPage(
                  groupId: groupId,
                  groupName: groupName,
                  groupImageUrl: groupAvatar,
                )
            ));
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white, foregroundColor: Colors.blue,
          side: const BorderSide(color: Colors.blue), minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 12), elevation: 1,
        ),
        child: const Text('View Group'),
      ),
      onTap: () {
        if (groupId.isNotEmpty) {
          Navigator.push(context, MaterialPageRoute(builder: (_) =>
              GroupPage(
                groupId: groupId,
                groupName: groupName,
                groupImageUrl: groupAvatar,
              )
          ));
        }
      },
    );
  }

  @override
  void dispose() {
    _postController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _youtubeLink1Controller.dispose();
    _youtubeLink2Controller.dispose();
    _youtubeLink3Controller.dispose();
    super.dispose();
  }
}

class GroupPage extends StatelessWidget {
  final String groupId;
  final String groupName;
  final String groupImageUrl;

  const GroupPage({required this.groupId, required this.groupName, required this.groupImageUrl, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(groupName)));
  }
}