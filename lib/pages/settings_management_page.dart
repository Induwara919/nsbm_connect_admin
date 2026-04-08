import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nsbm_connect_admin/theme.dart';

class SettingsManagementPage extends StatefulWidget {
  const SettingsManagementPage({super.key});

  @override
  State<SettingsManagementPage> createState() => _SettingsManagementPageState();
}

class _SettingsManagementPageState extends State<SettingsManagementPage> {
  final TextEditingController _itemController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("University Data Management", 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: "Batches"),
              Tab(text: "Faculties"),
              Tab(text: "Degrees"),
              Tab(text: "Subjects"),
              Tab(text: "Lecturers"),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              children: [
                _buildSimpleList("batches", "Batch Name (e.g. 22.1)"),
                _buildSimpleList("faculties", "Faculty Name"),
                _buildNestedDegreeList(), // Special logic for Degrees
                _buildSimpleList("subjects", "Subject Name"),
                _buildSimpleList("lecturers", "Lecturer Name"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildSimpleList(String collection, String hint) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _itemController,
                  decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _addItem(collection),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text("Add"),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(collection).orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return ListTile(
                    title: Text(doc['name']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(doc.reference, doc['name']),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

 
  String? _selectedFacultyForDegree;
  Widget _buildNestedDegreeList() {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('faculties').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            return DropdownButtonFormField<String>(
              value: _selectedFacultyForDegree,
              hint: const Text("Select Faculty to add Degree"),
              items: snapshot.data!.docs.map((doc) {
                return DropdownMenuItem(value: doc['name'] as String, child: Text(doc['name']));
              }).toList(),
              onChanged: (val) => setState(() => _selectedFacultyForDegree = val),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _itemController,
                decoration: const InputDecoration(hintText: "Degree Name", border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                if (_selectedFacultyForDegree == null) {
                  _showMsg("Select a faculty first!");
                  return;
                }
                _addItem("degrees", extraData: {'faculty': _selectedFacultyForDegree});
              },
              child: const Text("Add Degree"),
            ),
          ],
        ),
        const Divider(height: 30),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('degrees').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return ListTile(
                    title: Text(doc['name']),
                    subtitle: Text("Faculty: ${doc['faculty']}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(doc.reference, doc['name']),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  void _addItem(String collection, {Map<String, dynamic>? extraData}) async {
    if (_itemController.text.isEmpty) return;
    Map<String, dynamic> data = {'name': _itemController.text.trim()};
    if (extraData != null) data.addAll(extraData);

    await FirebaseFirestore.instance.collection(collection).add(data);
    _itemController.clear();
    _showMsg("Item added successfully");
  }

  void _confirmDelete(DocumentReference ref, String name) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Item?"),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              ref.delete();
              Navigator.pop(c);
              _showMsg("Deleted successfully");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
