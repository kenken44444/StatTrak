import 'package:flutter/material.dart';
import 'package:stattrak/DashboardPage.dart';
import 'package:stattrak/map_page.dart';
import 'package:stattrak/ProfilePage.dart';
import 'package:stattrak/widgets/friends_sidebar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final double height;
  final VoidCallback onNotificationPressed;
  final VoidCallback onGroupPressed;

  final String? avatarUrl; // The user’s avatar
  final double? lat;
  final double? long;

  const MyCustomAppBar({
    Key? key,
    this.height = kToolbarHeight,
    required this.onNotificationPressed,
    required this.onGroupPressed,
    this.lat,
    this.long,
    this.avatarUrl, required bool isLoading,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF2196F3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side icons
              _buildAppBarButton(
                context,
                "assets/icons/Home.png",
                Colors.white,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DashboardPage()),
                  );
                },
              ),
              _buildAppBarButton(
                context,
                "assets/icons/Map.png",
                Colors.white,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MapPage()),
                  );
                },
              ),

              // Right side icons
              _buildAppBarButton(
                context,
                "assets/icons/Friends.png",
                Colors.white,
                    () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SizedBox(
                        width: 400, // set fixed width
                        height: 500, // or use MediaQuery
                        child: FriendsModal(
                          currentUserId: Supabase.instance.client.auth.currentUser!.id,
                          lat: lat,
                          long: long,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _buildAppBarButton(
                context,
                "assets/icons/Group.png",
                Colors.white,
                onGroupPressed,
              ),
              _buildAppBarButton(
                context,
                "assets/icons/Notification.png",
                Colors.white,
                onNotificationPressed,
              ),

              // Profile Avatar (with conditional fallback)
              avatarUrl != null && avatarUrl!.isNotEmpty
                  ? GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        initialLat: lat,
                        initialLong: long,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 10,
                  backgroundImage: NetworkImage(avatarUrl!),
                  backgroundColor: Colors.grey[200],
                ),
              )
                  : _buildAppBarButton(
                context,
                "assets/icons/Profile.png",
                Colors.white,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfilePage(
                        initialLat: lat,
                        initialLong: long,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton(BuildContext context, String assetPath, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Image.asset(
        assetPath,
        color: color,
        width: 24,  // standardize icon size
        height: 24,
      ),
      padding: EdgeInsets.zero,  // removes padding around the button
      splashRadius: 20,  // adds a small splash area for touch feedback
      onPressed: onPressed,
    );
  }
}
