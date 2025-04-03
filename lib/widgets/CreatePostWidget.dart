import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/models/Post.dart';
import 'package:stattrak/providers/post_provider.dart';

class CreatePostWidget extends StatefulWidget {
  const CreatePostWidget({Key? key}) : super(key: key);

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  final _postController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _postController,
              decoration: InputDecoration(
                hintText: "What's on your mind?",
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.grey, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2.0),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _pickAndUploadImage,
                  icon: const Icon(Icons.image, color: Colors.blue,),
                  label: const Text('Upload Image', style: TextStyle(color: Colors.blue)),
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
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _createPost,
                  icon: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.send, color: Colors.blue,),
                  label: const Text('Post' , style: TextStyle(color: Colors.blue)),
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

              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final content = _postController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
      }).select();

      final insertedPost = response.first;

      final postProvider = context.read<PostProvider>();
      postProvider.addPost(
        Post(
          username: user.userMetadata?['full_name'] ?? 'Unknown',
          date: DateTime.now(),
          location: 'Bulacan',
          title: content,
          distance: 0.0,
          elevation: 0.0,
          imageUrls: [],
          likes: 0,
        ),
      );
      _postController.clear();
    } catch (error) {
      debugPrint('Error creating post: $error');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final content = _postController.text.trim();
    if (content.isEmpty) {
      debugPrint("No text entered!");
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isSubmitting = true);

    try {
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      await supabase.storage.from('post-images').uploadBinary(
        fileName,
        fileBytes,
        fileOptions: FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = supabase.storage.from('post-images').getPublicUrl(fileName);

      final response = await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
        'photos': [imageUrl],
      }).select();

      final postProvider = context.read<PostProvider>();
      postProvider.addPost(
        Post(
          username: user.userMetadata?['full_name'] ?? 'Unknown',
          date: DateTime.now(),
          location: 'Bulacan',
          title: content,
          distance: 0.0,
          elevation: 0.0,
          imageUrls: [imageUrl],
          likes: 0,
        ),
      );
      _postController.clear();
    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
