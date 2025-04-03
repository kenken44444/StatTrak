import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stattrak/GroupPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Simple data model for a group
class GroupItem {
  final String id;
  final String groupName;
  final String groupImageUrl;  // e.g. a logo
  final bool isMember;         // if the user is already a member

  GroupItem({
    required this.id,
    required this.groupName,
    required this.groupImageUrl,
    required this.isMember,
  });
}

class GroupSidebar extends StatefulWidget {
  const GroupSidebar({Key? key}) : super(key: key);

  @override
  State<GroupSidebar> createState() => _GroupSidebarState();
}

class _GroupSidebarState extends State<GroupSidebar> {
  late Future<List<GroupItem>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    // On init, trigger a fetch from Supabase (placeholder function for now)
    _groupsFuture = _fetchGroups();

  }

  void _showCreateGroupDialog() {
    final ImagePicker picker = ImagePicker();
    final nameController = TextEditingController();
    final descController = TextEditingController();

    XFile? pickedImage;
    String? uploadedImageUrl;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Create Group"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Group Name"),
                    ),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(labelText: "Description"),
                    ),
                    const SizedBox(height: 16),

                    // Show uploaded image preview
                    if (uploadedImageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          uploadedImageUrl!,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    ElevatedButton.icon(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final desc = descController.text.trim();

                        if (name.isEmpty || desc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter name and description first.')),
                          );
                          return;
                        }

                        pickedImage = await picker.pickImage(source: ImageSource.gallery);
                        if (pickedImage != null) {
                          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedImage!.name}';
                          final fileBytes = await pickedImage!.readAsBytes();

                          // 🧼 Clean up group name for folder usage
                          final folderName = name.toLowerCase().replaceAll(RegExp(r'\s+'), '-');
                          final path = '$folderName/$fileName'; // this becomes the subfolder path

                          try {
                            await Supabase.instance.client.storage
                                .from('group-cover')
                                .uploadBinary(
                              path,
                              fileBytes,
                              fileOptions: const FileOptions(upsert: true),
                            );

                            final publicUrl = Supabase.instance.client.storage
                                .from('group-cover')
                                .getPublicUrl(path);

                            setState(() {
                              uploadedImageUrl = publicUrl;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Image uploaded!')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Upload error: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text("Upload Group Image"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final desc = descController.text.trim();
                    final userId = Supabase.instance.client.auth.currentUser?.id;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Group name is required.")),
                      );
                      return;
                    }

                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("User not logged in.")),
                      );
                      return;
                    }

                    try {
                      final groupInsert = await Supabase.instance.client
                          .from('groups')
                          .insert({
                        'name': name,
                        'description': desc,
                        'group_image': uploadedImageUrl ?? '',
                      })
                          .select()
                          .single();

                      final groupId = groupInsert['id'] as String;

                      await Supabase.instance.client
                          .from('group_members')
                          .insert({
                        'group_id': groupId,
                        'user_id': userId,
                        'role': 'Leader',
                      });

                      Navigator.pop(context);
                      setState(() {
                        _groupsFuture = _fetchGroups();
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Group created successfully!')),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // TODO: Replace this mock function with a real Supabase query
  Future<List<GroupItem>> _fetchGroups() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    final response = await Supabase.instance.client
        .from('groups')
        .select('id, name, group_image, group_members(user_id)')
        .withConverter<List<Map<String, dynamic>>>((data) => List<Map<String, dynamic>>.from(data));

    return response.map((group) {
      final members = group['group_members'] as List<dynamic>? ?? [];
      final isMember = members.any((m) => m['user_id'] == userId);

      return GroupItem(
        id: group['id'],
        groupName: group['name'],
        groupImageUrl: group['group_image'] ?? '',
        isMember: isMember,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, // or any width you prefer for the sidebar
      color: const Color(0xFF1565C0), // Blue-ish background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======= TOP BAR: "Community" + Search Icon =======
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  "Community",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    // TODO: search logic
                  },
                  icon: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),

          // ======= CREATE GROUP BUTTON (centered) =======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.group_add),
                label: const Text("Create Group"),
                onPressed: _showCreateGroupDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,         // White fill
                  foregroundColor: const Color(0xFF1565C0), // Blue text/icon
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // pill shape
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ======= GROUPS LIST =======
          Expanded(
            child: FutureBuilder<List<GroupItem>>(
              future: _groupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No groups found',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final groups = snapshot.data!;
                return ListView.builder(
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _buildGroupTile(group);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTile(GroupItem group) {
    return GestureDetector(
      onTap: () async {
        final userId = Supabase.instance.client.auth.currentUser?.id;

        if (userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in.')),
          );
          return;
        }

        // Check if user is a member
        final response = await Supabase.instance.client
            .from('group_members')
            .select()
            .eq('group_id', group.id)
            .eq('user_id', userId)
            .maybeSingle();

        final isMember = response != null;

        if (isMember) {
          // ✅ Proceed to group page
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GroupPage(
                groupId: group.id,
                groupName: group.groupName,
                groupImageUrl: group.groupImageUrl,
              ),
            ),
          );

          if (result == true) {
            setState(() {
              _groupsFuture = _fetchGroups();
            });
          }
        } else {
          // ❌ Not a member: prompt to join
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Join Group"),
              content: const Text("You are not a member of this group. Join now?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Join"),
                ),
              ],
            ),
          );

          if (confirm == true) {
            try {
              await Supabase.instance.client
                  .from('group_members')
                  .insert({
                'group_id': group.id,
                'user_id': userId,
                'role': 'Member',
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('You have joined the group!')),
              );

              // Navigate after joining
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupPage(
                    groupId: group.id,
                    groupName: group.groupName,
                    groupImageUrl: group.groupImageUrl,
                  ),
                ),
              );

              if (result == true) {
                setState(() {
                  _groupsFuture = _fetchGroups();
                });
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to join group: $e')),
              );
            }
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[300],
              backgroundImage: NetworkImage(group.groupImageUrl),
              radius: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
