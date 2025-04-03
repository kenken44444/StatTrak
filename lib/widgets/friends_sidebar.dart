import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/ProfilePage.dart';

class FriendsModal extends StatefulWidget {
  final String currentUserId;
  final double? lat;
  final double? long;

  const FriendsModal({
    super.key,
    required this.currentUserId,
    this.lat,
    this.long,
  });

  @override
  State<FriendsModal> createState() => _FriendsModalState();
}

class _FriendsModalState extends State<FriendsModal> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic>? _pendingRequests;
  List<dynamic>? _friendsList;

  // Flags to prevent re-fetching
  bool _pendingFetched = false;
  bool _friendsFetched = false;

  // ---------------------------------------------------------------------------
  // Search users by full name (excluding the current user)
  // ---------------------------------------------------------------------------
  Future<void> _searchUsers(String query) async {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .ilike('full_name', '%$query%')
        .neq('id', widget.currentUserId);

    setState(() {
      _searchResults = response;
    });
  }

  // ---------------------------------------------------------------------------
  // Load pending friend requests using a Postgres RPC
  // ---------------------------------------------------------------------------
  Future<void> _loadPendingRequests() async {
    final response = await Supabase.instance.client.rpc('get_pending_requests', params: {
      'current_user_id': widget.currentUserId
    });

    debugPrint("Pending requests: $response");

    setState(() {
      _pendingRequests = response;
      _pendingFetched = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Load accepted friends using a Postgres RPC
  // ---------------------------------------------------------------------------
  Future<void> _loadFriends() async {
    if (_friendsFetched) return;
    final response = await Supabase.instance.client.rpc('get_friends_list', params: {
      'current_user_id': widget.currentUserId
    });
    setState(() {
      _friendsList = response;
      _friendsFetched = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Accept a friend request: update relationship status and send a notification
  // ---------------------------------------------------------------------------
  Future<void> _acceptRequest(String fromUserId) async {
    final supabase = Supabase.instance.client;

    try {
      // Update the relationship to 'accepted'
      await supabase
          .from('user_friendships')
          .update({'status': 'accepted'})
          .match({'user_id': fromUserId, 'friend_id': widget.currentUserId});

      // Insert a notification for the original sender
      await supabase.from('notifications').insert({
        'type': 'friend_request_accepted',
        'user_id': fromUserId,              // Notify the sender
        'actor_user_id': widget.currentUserId, // Who accepted the request
        'related_entity_id': widget.currentUserId,
        'related_entity_type': 'user_friendships',
        'is_read': false,
      });

      await _loadPendingRequests();
      setState(() {
        _friendsFetched = false;
      });
    } catch (e) {
      debugPrint("Error accepting friend request: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // Reject or cancel a friend request
  // ---------------------------------------------------------------------------
  Future<void> _rejectRequest(String userId) async {
    await Supabase.instance.client
        .from('user_friendships')
        .delete()
        .or('user_id.eq.${widget.currentUserId},friend_id.eq.${widget.currentUserId}')
        .filter('user_id', 'in', '(${widget.currentUserId},"$userId")')
        .filter('friend_id', 'in', '(${widget.currentUserId},"$userId")');

    await _loadPendingRequests();
  }

  // ---------------------------------------------------------------------------
  // Send a friend request: insert a pending friendship and notify the recipient
  // ---------------------------------------------------------------------------
  Future<void> _sendFriendRequest(String toUserId) async {
    final supabase = Supabase.instance.client;
    final fromUserId = supabase.auth.currentUser?.id;
    if (fromUserId == null) {
      debugPrint("No user is logged in, cannot send friend request.");
      return;
    }

    try {
      // Insert a pending friend relationship
      await supabase.from('user_friendships').insert({
        'user_id': fromUserId,
        'friend_id': toUserId,
        'status': 'pending',
      });

      // Insert a 'friend_request_received' notification for the recipient
      await supabase.from('notifications').insert({
        'type': 'friend_request_received',
        'user_id': toUserId,           // Recipient gets notified
        'actor_user_id': fromUserId,   // Sender is the actor
        'related_entity_id': fromUserId, // Optionally, link back to sender or the friendship row
        'related_entity_type': 'user_friendships',
        'is_read': false,
      });

      debugPrint("Friend request sent to $toUserId, notification inserted.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Friend request sent.")),
      );
    } catch (e) {
      debugPrint("Error sending friend request: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // Open a user's profile
  // ---------------------------------------------------------------------------
  void _openProfile(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userId: id,
          initialLat: widget.lat,
          initialLong: widget.long,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build the Friends UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).canvasColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text("Friends", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          // Search text field
          TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: const InputDecoration(
              hintText: 'Search users...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // Display search results or pending/friends list
          Expanded(
            child: _searchController.text.isNotEmpty
                ? ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                  ),
                  title: Text(user['full_name']),
                  subtitle: Text('@${user['username']}'),
                  onTap: () => _openProfile(user['id']),
                  // Button to send a friend request
                  trailing: IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: () => _sendFriendRequest(user['id']),
                  ),
                );
              },
            )
                : ListView(
              children: [
                ListTile(
                  title: const Text("Pending Requests"),
                  onTap: _loadPendingRequests,
                ),
                if (_pendingRequests != null)
                  ..._pendingRequests!.map((user) {
                    final direction = user['direction']; // 'sent' or 'received'
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                      ),
                      title: Text(user['full_name']),
                      subtitle: Text('@${user['username']}'),
                      trailing: direction == 'received'
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () => _acceptRequest(user['id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _rejectRequest(user['id']),
                          ),
                        ],
                      )
                          : IconButton(
                        icon: const Icon(Icons.cancel),
                        onPressed: () => _rejectRequest(user['id']), // cancel sent request
                      ),
                      onTap: () => _openProfile(user['id']),
                    );
                  }),
                const Divider(),
                ListTile(
                  title: const Text("My Friends"),
                  onTap: _loadFriends,
                ),
                if (_friendsList != null)
                  ..._friendsList!.map((user) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(user['avatar_url'] ?? ''),
                    ),
                    title: Text(user['full_name']),
                    subtitle: Text('@${user['username']}'),
                    onTap: () => _openProfile(user['id']),
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
