import 'package:flutter/material.dart';
import 'package:stattrak/models/Post.dart';

class PostWidget extends StatefulWidget {
  final Post post;

  const PostWidget({super.key, required this.post});

  @override
  _PostWidgetState createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> {
  bool isLiked = false;
  int likeCount = 0;

  @override
  void initState() {
    super.initState();
    likeCount = widget.post.likes;
  }

  void _toggleLike() {
    setState(() {
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.username,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${widget.post.date} • ${widget.post.location}",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.post.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _infoChip(Icons.directions_bike, "${widget.post.distance} km"),
                const SizedBox(width: 8),
                _infoChip(Icons.landscape, "${widget.post.elevation} m"),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.post.imageUrls.isNotEmpty)
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: PageView(
                    children: widget.post.imageUrls.map((url) => _buildImage(url)).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$likeCount people liked this",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      key: ValueKey(isLiked),
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                  ),
                  onPressed: _toggleLike,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18, color: Colors.blue[700]),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      backgroundColor: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildImage(String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Image.network(url, width: double.infinity, height: 200, fit: BoxFit.cover),
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}