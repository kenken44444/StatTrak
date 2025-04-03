import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/models/Post.dart';

class PostProvider with ChangeNotifier {
  final List<Post> _posts = [];
  final int _pageSize = 5;
  bool _hasMore = true;
  bool _isLoading = false;

  List<Post> get posts => _posts;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;

  final supabase = Supabase.instance.client;

  /// Load the first 5-7 posts
  Future<void> fetchInitialPosts() async {
    _posts.clear();
    _hasMore = true;
    await _fetchPosts(offset: 0);
  }

  /// Load the next page of posts
  Future<void> loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    await _fetchPosts(offset: _posts.length);
  }

  Future<void> _fetchPosts({required int offset}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await supabase
          .from('posts')
          .select('*, profiles(username)')
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      final List<dynamic> data = response;

      if (data.isEmpty || data.length < _pageSize) {
        _hasMore = false;
      }

      for (final item in data) {
        final profile = item['profiles'];

        _posts.add(Post(
          username: profile?['username'] ?? 'Unknown',
          date: DateTime.parse(item['created_at']),
          location: '', // optional: if you store location in profiles or posts
          title: item['content'] ?? '',
          distance: 0.0,
          elevation: 0.0,
          imageUrls: (item['photos'] != null && item['photos'] is List)
              ? List<String>.from(item['photos'])
              : item['photos'] is String
              ? [item['photos']]
              : [],
          likes: 0,
        ));
      }
    } catch (e) {
      debugPrint("Error loading posts: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addPost(Post post) {
    _posts.insert(0, post);
    notifyListeners();
  }
}
