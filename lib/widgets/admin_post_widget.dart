import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nsbm_connect_admin/theme.dart';

class AdminPostWidget extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const AdminPostWidget({super.key, required this.postId, required this.postData});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        margin: const EdgeInsets.only(bottom: 20),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuthorHeader(postData['author_id']),
              
              if (postData['image_url'] != null && postData['image_url'].isNotEmpty)
                ClipRRect(
                  child: CachedNetworkImage(
                    imageUrl: postData['image_url'],
                    width: double.infinity,
                    // Removed fixed height and BoxFit.cover to keep original aspect ratio
                    fit: BoxFit.contain, 
                    placeholder: (context, url) => Container(
                      height: 200, 
                      color: Colors.grey[100],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(postData['title'] ?? "No Title", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                          onPressed: () => _confirmDeletePost(context),
                          tooltip: "Delete Entire Post",
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(postData['description'] ?? "", 
                      style: const TextStyle(color: Colors.black87, fontSize: 13)),
                    const Divider(height: 24),
                    
                    Row(
                      children: [
                        _statItem(Icons.thumb_up_off_alt, (postData['likes'] as List?)?.length ?? 0, Colors.blue),
                        _statItem(Icons.thumb_down_off_alt, (postData['dislikes'] as List?)?.length ?? 0, Colors.red),
                        
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('comments')
                              .where('post_id', isEqualTo: postId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return GestureDetector(
                              onTap: () => _showComments(context),
                              child: _statItem(Icons.comment_outlined, count, Colors.orange),
                            );
                          },
                        ),
                        
                        const Spacer(),
                        Text(
                          postData['timestamp'] != null 
                            ? DateFormat('MMM dd, yyyy').format(postData['timestamp'].toDate()) 
                            : "",
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader(String? authorId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(authorId ?? "").get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const ListTile(title: Text("Loading..."));
        var author = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        
        // FULL NAME: initials first_name last_name surname
        String fullName = "${author['initials'] ?? ''} ${author['first_name'] ?? ''} ${author['last_name'] ?? ''} ${author['surname'] ?? ''}";
        // ACADEMIC DETAILS: batch | faculty | degree
        String academicInfo = "${author['batch'] ?? ''} | ${author['faculty'] ?? ''} | ${author['degree'] ?? ''}";

        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundImage: (author['profile_pic'] != null && author['profile_pic'].isNotEmpty) 
                ? NetworkImage(author['profile_pic']) 
                : null,
            child: (author['profile_pic'] == null || author['profile_pic'].isEmpty) 
                ? const Icon(Icons.person) 
                : null,
          ),
          title: Text(fullName.trim(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(academicInfo, style: const TextStyle(fontSize: 11)),
        );
      },
    );
  }

  void _confirmDeletePost(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Post?"),
        content: const Text("This will permanently remove the post and all associated comments."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
              var commentDocs = await FirebaseFirestore.instance
                  .collection('comments')
                  .where('post_id', isEqualTo: postId)
                  .get();
              for (var doc in commentDocs.docs) { await doc.reference.delete(); }
              // FIXED: Ensure context is still active before popping
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminCommentSection(postId: postId),
    );
  }
}

class AdminCommentSection extends StatelessWidget {
  final String postId;
  const AdminCommentSection({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Comments", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('comments')
                  .where('post_id', isEqualTo: postId)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No comments found."));

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var comment = doc.data() as Map<String, dynamic>;
                    return _buildCommentTile(context, doc.id, comment);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(BuildContext context, String commentId, Map<String, dynamic> comment) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(comment['user_id'] ?? "").get(),
      builder: (context, userSnap) {
        var user = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        return ListTile(
          leading: CircleAvatar(
            radius: 16, 
            backgroundImage: (user['profile_pic'] != null && user['profile_pic'].isNotEmpty) 
                ? NetworkImage(user['profile_pic']) 
                : null
          ),
          title: Text("${user['first_name'] ?? 'User'}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comment['text'] ?? "", style: const TextStyle(fontSize: 13, color: Colors.black87)),
              Text(
                comment['timestamp'] != null ? DateFormat('dd MMM, hh:mm a').format(comment['timestamp'].toDate()) : "",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
            onPressed: () => _confirmDeleteComment(context, commentId),
          ),
        );
      },
    );
  }

  void _confirmDeleteComment(BuildContext parentContext, String commentId) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Comment?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('comments').doc(commentId).delete();
              // FIXED: Explicitly pop the dialog context
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
