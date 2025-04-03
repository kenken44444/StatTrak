import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  final String? avatarUrl;
  final String? username;
  final String? fullName;
  final String? bio;
  final String? youtubeLink1;
  final String? youtubeLink2;
  final String? youtubeLink3;
  final List<String> featuredPhotos;
  final double? latitude;
  final double? longitude;
  final String? phoneNumber;

  const EditProfilePage({
    Key? key,
    this.avatarUrl,
    this.username,
    this.fullName,
    this.bio,
    this.youtubeLink1,
    this.youtubeLink2,
    this.youtubeLink3,
    this.featuredPhotos = const [],
    this.latitude,
    this.longitude,
    this.phoneNumber,
  }) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _bioController = TextEditingController();

  // YouTube links
  final _youtubeLink1Controller = TextEditingController();
  final _youtubeLink2Controller = TextEditingController();
  final _youtubeLink3Controller = TextEditingController();

  List<String> _featuredPhotos = [];
  final int _maxFeaturedPhotos = 4;

  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _usernameController.text = widget.username ?? '';
    _fullNameController.text = widget.fullName ?? '';
    _avatarUrlController.text = widget.avatarUrl ?? '';
    _bioController.text = widget.bio ?? '';
    _youtubeLink1Controller.text = widget.youtubeLink1 ?? '';
    _youtubeLink2Controller.text = widget.youtubeLink2 ?? '';
    _youtubeLink3Controller.text = widget.youtubeLink3 ?? '';
    _featuredPhotos = List.from(widget.featuredPhotos);
    _latitude = widget.latitude;
    _longitude = widget.longitude;
    _phoneController.text = widget.phoneNumber ?? '';

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
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      await supabase.storage
          .from('avatar-url')
          .uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(upsert: false));

      final publicUrl = supabase.storage.from('avatar-url').getPublicUrl(fileName);

      setState(() {
        _avatarUrlController.text = publicUrl;
      });
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading avatar: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadFeaturedPhoto() async {
    if (_featuredPhotos.length >= _maxFeaturedPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 4 featured photos allowed')),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final fileBytes = await pickedFile.readAsBytes();

      // Determine folder: username or fallback to user ID
      final folder = _usernameController.text.isNotEmpty
          ? _usernameController.text
          : user.id;

      // Full path with folder
      final fileName = '$folder/featured_${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      // Upload to Supabase Storage
      await supabase.storage
          .from('featured-photos')
          .uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(upsert: false));

      final publicUrl = supabase.storage.from('featured-photos').getPublicUrl(fileName);

      setState(() {
        _featuredPhotos.add(publicUrl);
      });
    } catch (e) {
      debugPrint('Error uploading featured photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading photo: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'username': _usernameController.text,
        'full_name': _fullNameController.text,
        'avatar_url': _avatarUrlController.text,
        'bio': _bioController.text,
        'lat': _latitude,
        'long': _longitude,
        'youtube_link1': _youtubeLink1Controller.text,
        'youtube_link2': _youtubeLink2Controller.text,
        'youtube_link3': _youtubeLink3Controller.text,
        'featured_photos': _featuredPhotos,
        'phone': _phoneController.text,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('profiles').update(updates).eq('id', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      // Return to profile page with the updated data
      if (!mounted) return;
      Navigator.pop(context, {
        'avatar_url': _avatarUrlController.text,
        'username': _usernameController.text,
        'full_name': _fullNameController.text,
        'bio': _bioController.text,
        'youtube_link1': _youtubeLink1Controller.text,
        'youtube_link2': _youtubeLink2Controller.text,
        'youtube_link3': _youtubeLink3Controller.text,
        'featured_photos': _featuredPhotos,
      });
    } catch (e) {
      debugPrint('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFeaturedPhotosEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured Photos (up to 4)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredPhotos.length < _maxFeaturedPhotos
                ? _featuredPhotos.length + 1
                : _featuredPhotos.length,
            itemBuilder: (context, index) {
              if (index == _featuredPhotos.length && _featuredPhotos.length < _maxFeaturedPhotos) {
                // Add new photo tile
                return InkWell(
                  onTap: _pickAndUploadFeaturedPhoto,
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_photo_alternate, size: 40),
                    ),
                  ),
                );
              } else {
                // Existing photo tile
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_featuredPhotos[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _featuredPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _updateProfile,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Section
            Center(
              child: Column(
                children: [
                  _avatarUrlController.text.isNotEmpty
                      ? CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(_avatarUrlController.text),
                  )
                      : const CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Change Profile Picture'),
                    onPressed: _pickAndUploadAvatar,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Basic Information
            const Text(
              'Basic Information',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                hintText: 'e.g. 09XXXXXXXXX',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 24),

            // Featured Photos
            _buildFeaturedPhotosEditor(),

            const SizedBox(height: 24),

            // YouTube Links
            const Text(
              'YouTube Links',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _youtubeLink1Controller,
              decoration: const InputDecoration(
                labelText: 'YouTube Link 1',
                hintText: 'https://www.youtube.com/watch?v=...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _youtubeLink2Controller,
              decoration: const InputDecoration(
                labelText: 'YouTube Link 2',
                hintText: 'https://www.youtube.com/watch?v=...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _youtubeLink3Controller,
              decoration: const InputDecoration(
                labelText: 'YouTube Link 3',
                hintText: 'https://www.youtube.com/watch?v=...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}