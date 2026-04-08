import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/admin_post_widget.dart';
import 'package:nsbm_connect_admin/theme.dart';

class CommunityHubPage extends StatefulWidget {
  const CommunityHubPage({super.key});

  @override
  State<CommunityHubPage> createState() => _CommunityHubPageState();
}

class _CommunityHubPageState extends State<CommunityHubPage> {
  String selectedCategory = "All Posts";
  final TextEditingController _catController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        
        Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey.shade200))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Post Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _catController,
                      decoration: const InputDecoration(hintText: "New Category", isDense: true),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.primary),
                    onPressed: _addNewCategory,
                  )
                ],
              ),
              const SizedBox(height: 20),
              
              
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('post_categories').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    var categories = snapshot.data!.docs;
                    
                    return ListView.builder(
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            title: const Text("All Posts"),
                            selected: selectedCategory == "All Posts",
                            onTap: () => setState(() => selectedCategory = "All Posts"),
                          );
                        }
                        var cat = categories[index - 1];
                        return ListTile(
                          title: Text(cat['name']),
                          selected: selectedCategory == cat['name'],
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              bool? confirm = await showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text("Delete Category?"),
                                  content: Text("Are you sure you want to delete the '${cat['name']}' category?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text("Cancel"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                _deleteCategory(cat.id);
                              }
                            },
                          ),
                          onTap: () => setState(() => selectedCategory = cat['name']),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // COLUMN 2: Post Moderation Feed
        Expanded(
          child: Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: StreamBuilder<QuerySnapshot>(
              stream: _getPostStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No posts found in this category."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return AdminPostWidget(
                      postId: doc.id,
                      postData: doc.data() as Map<String, dynamic>,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Stream<QuerySnapshot> _getPostStream() {
    var query = FirebaseFirestore.instance.collection('posts').orderBy('timestamp', descending: true);
    if (selectedCategory != "All Posts") {
      query = query.where('category', isEqualTo: selectedCategory);
    }
    return query.snapshots();
  }

  void _addNewCategory() async {
    if (_catController.text.isNotEmpty) {
      await FirebaseFirestore.instance.collection('post_categories').add({
        'name': _catController.text.trim(),
      });
      _catController.clear();
    }
  }

  void _deleteCategory(String id) async {
    await FirebaseFirestore.instance.collection('post_categories').doc(id).delete();
  }
}
